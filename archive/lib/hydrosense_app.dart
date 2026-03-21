import 'package:flutter/material.dart';

import 'routes.dart';
import 'screens/add_system_screen.dart';
import 'screens/login_screen.dart';
import 'screens/system_status_screen.dart';
import 'screens/systems_screen.dart';
import 'screens/ticket_screen.dart';
import 'state/app_state.dart';

class HydroSenseApp extends StatefulWidget {
  const HydroSenseApp({super.key});

  @override
  State<HydroSenseApp> createState() => _HydroSenseAppState();
}

class _HydroSenseAppState extends State<HydroSenseApp> {
  final AppState _state = AppState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: _state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'HydroSense',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5A8E3F)),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
        ),
        initialRoute: Routes.login,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case Routes.login:
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const LoginScreen(),
              );
            case Routes.systems:
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const SystemsScreen(),
              );
            case Routes.systemStatus:
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const SystemStatusScreen(),
              );
            case Routes.addSystem:
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const AddSystemScreen(),
              );
            case Routes.ticket:
              return MaterialPageRoute<void>(
                settings: settings,
                builder: (_) => const TicketScreen(),
              );
            default:
              return MaterialPageRoute<void>(
                builder: (_) => const LoginScreen(),
              );
          }
        },
      ),
    );
  }
}
