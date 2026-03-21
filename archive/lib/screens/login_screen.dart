import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

import '../routes.dart';
import '../services/google_auth.dart';
import '../widgets/labeled_text_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;

  String _firebaseAuthMessage(FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    final message = e.message ?? '';
    final messageLower = message.toLowerCase();

    if (code.contains('configuration-not-found') ||
        messageLower.contains('configuration_not_found')) {
      return "Firebase Auth isn’t enabled for this project. In Firebase Console → Authentication → Get started, then enable Google / Email-Password.";
    }
    if (code == 'operation-not-allowed') {
      return 'This sign-in method is disabled. Enable it in Firebase Console → Authentication → Sign-in method.';
    }
    if (code == 'unauthorized-domain') {
      return 'Unauthorized domain. Add this domain in Firebase Console → Authentication → Settings → Authorized domains.';
    }
    return message.isNotEmpty ? message : 'Authentication failed.';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (FirebaseAuth.instance.currentUser != null && mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            Routes.systems,
            (_) => false,
          );
        }
      } catch (_) {
        // Firebase may not be configured yet (e.g. widget tests).
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email + password.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.systems,
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'invalid-email' => 'Invalid email address.',
        'user-disabled' => 'This account is disabled.',
        'user-not-found' => 'No user found for that email.',
        'wrong-password' => 'Wrong password.',
        _ => _firebaseAuthMessage(e),
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firebase not configured. Run `flutterfire configure`.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signUp() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter email + password.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.systems,
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'email-already-in-use' => 'That email is already in use.',
        'invalid-email' => 'Invalid email address.',
        'weak-password' => 'Password is too weak.',
        _ => _firebaseAuthMessage(e),
      };
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firebase not configured. Run `flutterfire configure`.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _busy = true);
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        provider.addScope('email');
        await FirebaseAuth.instance.signInWithPopup(provider);
      } else {
        final account = await GoogleAuth.authenticate(
          scopeHint: const <String>['email'],
        );
        final idToken = account.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw const GoogleSignInException(
            code: GoogleSignInExceptionCode.providerConfigurationError,
            description: 'Missing Google ID token.',
          );
        }
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        await FirebaseAuth.instance.signInWithCredential(credential);
      }

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.systems,
        (_) => false,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.description ?? 'Google sign-in failed.')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final code = e.code.toLowerCase();
      if (code == 'popup-closed-by-user' || code == 'cancelled-popup-request') {
        return;
      }
      final message = _firebaseAuthMessage(e);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firebase not configured. Run `flutterfire configure`.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'images/133_957',
                            width: 140,
                            height: 140,
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'HydroSense',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () {
                                      _signInWithGoogle();
                                    },
                              icon: const Icon(Icons.login),
                              label: const Text('Continue with Google'),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: Divider(color: Colors.grey.shade300),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text('or'),
                              ),
                              Expanded(
                                child: Divider(color: Colors.grey.shade300),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          LabeledTextField(
                            label: 'Email',
                            controller: _email,
                            hintText: 'name@example.com',
                            keyboardType: TextInputType.emailAddress,
                            enabled: !_busy,
                          ),
                          const SizedBox(height: 18),
                          LabeledTextField(
                            label: 'Password',
                            controller: _password,
                            hintText: 'Password',
                            obscureText: true,
                            enabled: !_busy,
                          ),
                          const SizedBox(height: 22),
                          _LoginButton(
                            label: 'Log in',
                            onPressed: _busy
                                ? null
                                : () {
                                    _signIn();
                                  },
                          ),
                          const SizedBox(height: 10),
                          _LoginButton(
                            label: 'Sign Up',
                            onPressed: _busy
                                ? null
                                : () {
                                    _signUp();
                                  },
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 36,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFB9B0F3),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: Colors.black26),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
