import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/system.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/hydro_app_bar.dart';
import '../widgets/moisture_history_chart.dart';

class SystemStatusScreen extends StatefulWidget {
  const SystemStatusScreen({super.key});

  @override
  State<SystemStatusScreen> createState() => _SystemStatusScreenState();
}

class _SystemStatusScreenState extends State<SystemStatusScreen> {
  int? _historyLimit = 10;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final system = _systemFromArgs(context, state);

    DatabaseReference? deviceRef;
    try {
      deviceRef = FirebaseDatabase.instance.ref('devices/${system.id}');
    } catch (_) {
      deviceRef = null;
    }

    return Scaffold(
      appBar: const HydroAppBar(
        title: 'System Status',
        avatar: CircleAvatar(
          radius: 18,
          backgroundImage: AssetImage('images/52767_23905'),
          backgroundColor: Colors.transparent,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: [
              const SizedBox(height: 26),
              Text(
                system.name,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ID: ${system.id}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 18),
                  children: [
                    _MoistureNow(deviceRef: deviceRef),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const Text(
                          'History',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        DropdownButton<int?>(
                          value: _historyLimit,
                          items: const [
                            DropdownMenuItem<int?>(
                              value: 10,
                              child: Text('10'),
                            ),
                            DropdownMenuItem<int?>(
                              value: 50,
                              child: Text('50'),
                            ),
                            DropdownMenuItem<int?>(
                              value: 100,
                              child: Text('100'),
                            ),
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All'),
                            ),
                          ],
                          onChanged: (v) {
                            setState(() => _historyLimit = v);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MoistureHistoryChart(
                      systemId: system.id,
                      limit: _historyLimit,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: [
                    const Spacer(),
                    CircleIconButton(
                      icon: Icons.arrow_back,
                      onPressed: () {
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          Routes.systems,
                          (_) => false,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static HydroSystem _systemFromArgs(BuildContext context, AppState state) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is HydroSystem) return args;
    return state.systems.isEmpty
        ? HydroSystem(id: '', name: 'System')
        : state.systems.first;
  }

  static String _formatDateTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _MoistureNow extends StatelessWidget {
  const _MoistureNow({required this.deviceRef});

  final DatabaseReference? deviceRef;

  @override
  Widget build(BuildContext context) {
    if (deviceRef == null) {
      return Text(
        'Firebase not configured.',
        style: TextStyle(color: Colors.grey.shade700),
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: deviceRef!.onValue,
      builder: (context, snapshot) {
        final raw = snapshot.data?.snapshot.value;
        final map = raw is Map ? raw : const <Object?, Object?>{};

        final rawMoisture = map['moisture'];
        final moisture = switch (rawMoisture) {
          num v => v.toDouble(),
          String v => double.tryParse(v),
          _ => null,
        };

        final rawUpdatedAt = map['updatedAt'];
        final updatedAtMs = switch (rawUpdatedAt) {
          num v => v.toInt(),
          String v => int.tryParse(v),
          _ => null,
        };
        final updatedAt = updatedAtMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(updatedAtMs);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Moisture',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              moisture == null ? '—' : moisture.toStringAsFixed(0),
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              updatedAt == null
                  ? 'Last update: —'
                  : 'Last update: ${_SystemStatusScreenState._formatDateTime(updatedAt)}',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}
