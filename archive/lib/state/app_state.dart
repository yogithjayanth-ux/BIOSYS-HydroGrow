import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';

import '../models/system.dart';

class AppState extends ChangeNotifier {
  AppState({
    FirebaseAuth? auth,
    FirebaseDatabase? database,
  })  : _auth = auth,
        _database = database {
    _tryStartFirebase();
  }

  final FirebaseAuth? _auth;
  final FirebaseDatabase? _database;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DatabaseEvent>? _systemsSub;

  String? _uid;
  List<HydroSystem> _systems = const [];

  List<HydroSystem> get systems => List.unmodifiable(_systems);

  void _tryStartFirebase() {
    try {
      if (Firebase.apps.isEmpty) return;
      final auth = _auth ?? FirebaseAuth.instance;
      _authSub = auth.authStateChanges().listen(
            _handleUserChanged,
            onError: (_) {},
          );
      _handleUserChanged(auth.currentUser);
    } catch (_) {
      // Firebase may not be configured yet (e.g. widget tests).
    }
  }

  void _handleUserChanged(User? user) {
    final nextUid = user?.uid;
    if (nextUid == _uid) return;

    _uid = nextUid;
    _systemsSub?.cancel();
    _systemsSub = null;
    _systems = const [];
    notifyListeners();

    if (nextUid == null) return;
    _subscribeToSystems(nextUid);
  }

  void _subscribeToSystems(String uid) {
    try {
      final db = _database ?? FirebaseDatabase.instance;
      _systemsSub = db.ref('users/$uid/systems').onValue.listen(
        (event) {
          final next = <HydroSystem>[];
          final value = event.snapshot.value;
          if (value is Map) {
            for (final entry in value.entries) {
              final id = entry.key?.toString().trim() ?? '';
              if (id.isEmpty) continue;

              final raw = entry.value;
              final name = (raw is Map ? raw['name'] : null)?.toString().trim();
              next.add(
                HydroSystem(
                  id: id,
                  name: (name == null || name.isEmpty) ? id : name,
                ),
              );
            }
          }

          next.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
          _systems = next;
          notifyListeners();
        },
        onError: (_) {},
      );
    } catch (_) {
      // Firebase may not be configured yet.
    }
  }

  Future<void> addSystem({required String id, required String name}) async {
    final trimmedId = id.trim();
    final trimmedName = name.trim();
    if (trimmedId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Required');
    }
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Required');
    }

    final auth = _auth ?? FirebaseAuth.instance;
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('Not signed in.');
    }

    final db = _database ?? FirebaseDatabase.instance;

    final ownerRef = db.ref('systemOwners/$trimmedId');
    final claim = await ownerRef.runTransaction((value) {
      final existing = value?.toString();
      if (existing == null || existing.isEmpty) return Transaction.success(uid);
      if (existing == uid) return Transaction.success(uid);
      return Transaction.abort();
    });

    if (!claim.committed) {
      throw StateError('This system is already claimed by another user.');
    }

    await db.ref('users/$uid/systems/$trimmedId').set({'name': trimmedName});
  }

  @override
  void dispose() {
    _systemsSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required super.notifier,
    required super.child,
  });

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'No AppStateScope found in context');
    return scope!.notifier!;
  }
}
