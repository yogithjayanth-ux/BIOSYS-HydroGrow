import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'hydrosense_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Allows the UI to boot even if Firebase hasn't been configured yet.
    // Login/ticket actions will show an error until `flutterfire configure` is run.
  }
  runApp(const HydroSenseApp());
}
