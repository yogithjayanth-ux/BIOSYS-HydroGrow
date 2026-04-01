import 'dart:async';

import 'package:web/web.dart' as web;

const String _relayUrl = String.fromEnvironment('SUPPORT_RELAY_URL');

Future<bool> sendSupportTicketEmailViaRelayImpl({
  required String ticketId,
  required String contactEmail,
  required String message,
  required String? userEmail,
  required String? uid,
}) async {
  if (_relayUrl.trim().isEmpty) return false;

  // Apps Script Web Apps don't reliably support CORS, so on web we submit a
  // hidden <form> POST. This sends the request, but we can't read the response.
  try {
    const iframeName = 'support_ticket_relay_iframe';
    final iframe = web.HTMLIFrameElement()
      ..name = iframeName
      ..style.display = 'none';
    web.document.body?.append(iframe);

    final form = web.HTMLFormElement()
      ..method = 'POST'
      ..action = _relayUrl
      ..target = iframeName
      ..style.display = 'none';

    void addField(String name, String value) {
      final input = web.HTMLInputElement()
        ..type = 'hidden'
        ..name = name
        ..value = value;
      form.append(input);
    }

    addField('ticketId', ticketId);
    addField('contactEmail', contactEmail);
    addField('message', message);
    addField('userEmail', userEmail ?? '');
    addField('uid', uid ?? '');

    web.document.body?.append(form);
    form.submit();

    Timer(const Duration(seconds: 5), () {
      form.remove();
      iframe.remove();
    });

    return true;
  } catch (_) {
    return false;
  }
}
