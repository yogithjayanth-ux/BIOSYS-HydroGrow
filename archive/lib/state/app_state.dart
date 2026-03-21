import 'package:flutter/widgets.dart';

import '../models/system.dart';

class AppState extends ChangeNotifier {
  final List<HydroSystem> _systems = [
    HydroSystem(name: 'SystemThyme', batchId: '20260221Batch'),
    HydroSystem(name: 'SystemScallion', batchId: '20260221Batch'),
    HydroSystem(name: 'SystemTomatos', batchId: 'asdf'),
    HydroSystem(name: 'SystemWeed', batchId: 'batch#5'),
    HydroSystem(name: 'SystemLettuce', batchId: 'batch#8'),
  ];

  DateTime _lastUpdated = DateTime(2026, 2, 21);

  List<HydroSystem> get systems => List.unmodifiable(_systems);

  DateTime get lastUpdated => _lastUpdated;

  void toggleFavorite(HydroSystem system) {
    system.isFavorite = !system.isFavorite;
    notifyListeners();
  }

  void addSystem({required String id, required String name}) {
    _systems.insert(0, HydroSystem(name: name.trim(), batchId: id.trim()));
    notifyListeners();
  }

  void refreshStatus() {
    _lastUpdated = DateTime.now();
    notifyListeners();
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
