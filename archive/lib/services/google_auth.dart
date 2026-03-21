import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuth {
  GoogleAuth._();

  static Future<void>? _init;

  static Future<void> _ensureInitialized() {
    return _init ??= GoogleSignIn.instance.initialize();
  }

  static Future<GoogleSignInAccount> authenticate({
    List<String> scopeHint = const <String>[],
  }) async {
    await _ensureInitialized();
    return GoogleSignIn.instance.authenticate(scopeHint: scopeHint);
  }

  static Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }
}

