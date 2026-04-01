import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupportTicketService {
  SupportTicketService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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

    final ticketRef = _firestore.collection('supportTickets').doc();
    await ticketRef.set({
      'createdAt': FieldValue.serverTimestamp(),
      'uid': user?.uid,
      'userEmail': user?.email,
      'contactEmail': trimmedEmail,
      'message': trimmedMessage,
      'status': 'new',
    });

    return ticketRef.id;
  }
}
