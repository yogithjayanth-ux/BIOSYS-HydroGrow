import 'support_ticket_email_relay_stub.dart'
    if (dart.library.html) 'support_ticket_email_relay_web.dart'
    if (dart.library.io) 'support_ticket_email_relay_io.dart';

/// Sends the support ticket to an external relay (e.g. Google Apps Script).
///
/// Returns `true` if the request was sent (web) or acknowledged (io).
Future<bool> sendSupportTicketEmailViaRelay({
  required String ticketId,
  required String contactEmail,
  required String message,
  required String? userEmail,
  required String? uid,
}) {
  return sendSupportTicketEmailViaRelayImpl(
    ticketId: ticketId,
    contactEmail: contactEmail,
    message: message,
    userEmail: userEmail,
    uid: uid,
  );
}

