import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../routes.dart';
import '../services/support_ticket_service.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/hydro_app_bar.dart';
import '../widgets/labeled_text_field.dart';

class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key});

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _feedback = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final userEmail = FirebaseAuth.instance.currentUser?.email;
        if (userEmail != null && _email.text.trim().isEmpty) {
          _email.text = userEmail;
        }
      } catch (_) {
        // Firebase may not be configured yet (e.g. widget tests).
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final message = _feedback.text.trim();
    if (email.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email + a message.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final ticketId = await SupportTicketService().submit(
        contactEmail: email,
        message: message,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submitted. Ticket: $ticketId')),
      );
      _feedback.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HydroAppBar(
        title: 'Write a ticket',
        avatar: CircleAvatar(
          radius: 18,
          backgroundImage: AssetImage('images/52767_23905'),
          backgroundColor: Colors.transparent,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 36),
                  LabeledTextField(
                    label: 'Your email address',
                    controller: _email,
                    hintText: 'name@example.com',
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_submitting,
                  ),
                  const SizedBox(height: 22),
                  LabeledTextField(
                    label: 'Feedbacks',
                    controller: _feedback,
                    hintText: 'Write your feed-backs here.',
                    maxLines: 4,
                    enabled: !_submitting,
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: 120,
                    height: 38,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: _submitting
                          ? null
                          : () {
                              _submit();
                            },
                      child: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit'),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: CircleIconButton(
                      icon: Icons.arrow_back,
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          Routes.systems,
                          (_) => false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
