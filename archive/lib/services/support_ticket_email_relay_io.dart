import 'dart:convert';

import 'package:http/http.dart' as http;

const String _relayUrl = String.fromEnvironment('SUPPORT_RELAY_URL');

Future<bool> sendSupportTicketEmailViaRelayImpl({
  required String ticketId,
  required String contactEmail,
  required String message,
  required String? userEmail,
  required String? uid,
}) async {
  if (_relayUrl.trim().isEmpty) return false;

  final uri = Uri.tryParse(_relayUrl);
  if (uri == null) return false;

  final payload = <String, dynamic>{
    'ticketId': ticketId,
    'contactEmail': contactEmail,
    'message': message,
    'userEmail': userEmail,
    'uid': uid,
  };

  try {
    final resp = await http
        .post(
          uri,
          headers: const {
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 12));

    final body = resp.body.trim();
    if (body.isEmpty) return resp.statusCode >= 200 && resp.statusCode < 300;

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final ok = decoded['ok'];
      if (ok is bool) return ok;
    }
    return resp.statusCode >= 200 && resp.statusCode < 300;
  } catch (_) {
    return false;
  }
}

