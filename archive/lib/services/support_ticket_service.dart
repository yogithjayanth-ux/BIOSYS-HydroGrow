import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

class SupportTicketRouting {
  const SupportTicketRouting({
    required this.to,
    required this.subjectPrefix,
  });

  final List<String> to;
  final String subjectPrefix;

  static const remoteConfigKey = 'support_ticket_routing_json';

  static const defaultJson = '{"to":["support@example.com"],"subjectPrefix":"[HydroSense Ticket]"}';

  static SupportTicketRouting fallback() => const SupportTicketRouting(
        to: ['support@example.com'],
        subjectPrefix: '[HydroSense Ticket]',
      );

  static SupportTicketRouting parse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return fallback();

      final to = _parseEmailList(decoded['to']);
      final subjectPrefix = decoded['subjectPrefix']?.toString().trim();
      return SupportTicketRouting(
        to: to.isEmpty ? fallback().to : to,
        subjectPrefix: (subjectPrefix == null || subjectPrefix.isEmpty)
            ? fallback().subjectPrefix
            : subjectPrefix,
      );
    } catch (_) {
      return fallback();
    }
  }

  static List<String> _parseEmailList(Object? v) {
    if (v is String) {
      final trimmed = v.trim();
      return trimmed.isEmpty ? const [] : [trimmed];
    }
    if (v is Iterable) {
      return v
          .whereType<Object?>()
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }
}

class SupportTicketService {
  SupportTicketService({
    FirebaseFirestore? firestore,
    FirebaseRemoteConfig? remoteConfig,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseRemoteConfig _remoteConfig;
  final FirebaseAuth _auth;

  Future<SupportTicketRouting> _loadRouting() async {
    try {
      await _remoteConfig.setDefaults(
        {SupportTicketRouting.remoteConfigKey: SupportTicketRouting.defaultJson},
      );
      await _remoteConfig.fetchAndActivate();
      final raw = _remoteConfig.getString(SupportTicketRouting.remoteConfigKey);
      if (raw.trim().isEmpty) return SupportTicketRouting.fallback();
      return SupportTicketRouting.parse(raw);
    } catch (_) {
      return SupportTicketRouting.fallback();
    }
  }

  Future<String> submit({
    required String contactEmail,
    required String message,
  }) async {
    final trimmedEmail = contactEmail.trim();
    final trimmedMessage = message.trim();
    if (trimmedEmail.isEmpty) {
      throw ArgumentError.value(contactEmail, 'contactEmail', 'Required');
    }
    if (trimmedMessage.isEmpty) {
      throw ArgumentError.value(message, 'message', 'Required');
    }

    final user = _auth.currentUser;
    final routing = await _loadRouting();

    final ticketRef = _firestore.collection('supportTickets').doc();
    await ticketRef.set({
      'createdAt': FieldValue.serverTimestamp(),
      'uid': user?.uid,
      'userEmail': user?.email,
      'contactEmail': trimmedEmail,
      'message': trimmedMessage,
      'status': 'new',
    });

    // If the Firebase "Trigger Email" extension is installed, writing a
    // document to `mail/` will send an email via the configured SMTP provider.
    await _firestore.collection('mail').add({
      'to': routing.to,
      'replyTo': trimmedEmail,
      'message': {
        'subject': '${routing.subjectPrefix} ${ticketRef.id}',
        'text': 'Ticket: ${ticketRef.id}\n\nFrom: $trimmedEmail\n\n$trimmedMessage',
      },
    });

    return ticketRef.id;
  }
}

