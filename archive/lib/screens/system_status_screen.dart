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
  static const double dryThreshold = 30;
  static const double rawDryValue = 4095;
  static const double rawWetValue = 4000;

  static double? _rawMoistureToPercent(Object? rawMoisture) {
    final rawValue = switch (rawMoisture) {
      num v => v.toDouble(),
      String v => double.tryParse(v),
      _ => null,
    };
    if (rawValue == null) return null;

    final clamped = rawValue.clamp(rawWetValue, rawDryValue);
    return ((rawDryValue - clamped) / (rawDryValue - rawWetValue)) * 100;
  }

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
                    _MoistureStatusNow(
                      deviceRef: deviceRef,
                      dryThreshold: dryThreshold,
                    ),
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
                    const SizedBox(height: 18),
                    _MoistureLevelNow(
                      deviceRef: deviceRef,
                      dryThreshold: dryThreshold,
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

class _MoistureStatusNow extends StatelessWidget {
  const _MoistureStatusNow({
    required this.deviceRef,
    required this.dryThreshold,
  });

  final DatabaseReference? deviceRef;
  final double dryThreshold;

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
        final moisture = _SystemStatusScreenState._rawMoistureToPercent(rawMoisture);

        final rawUpdatedAt = map['updatedAt'];
        final updatedAtMs = switch (rawUpdatedAt) {
          num v => v.toInt(),
          String v => int.tryParse(v),
          _ => null,
        };
        final updatedAt = updatedAtMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(updatedAtMs);

        final status = moisture == null
            ? '—'
            : moisture < dryThreshold
                ? 'dry'
                : 'wet';

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Moisture',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              status,
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              moisture == null
                  ? 'Raw: —'
                  : 'Raw: ${rawMoisture ?? '—'}  |  ${moisture.toStringAsFixed(0)}%',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              'High raw values are dry; low raw values are wet.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'Dry <',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 10),
                Text(
                  '${dryThreshold.toStringAsFixed(0)}%',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                ),
              ],
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

class _MoistureLevelNow extends StatelessWidget {
  const _MoistureLevelNow({
    required this.deviceRef,
    required this.dryThreshold,
  });

  final DatabaseReference? deviceRef;
  final double dryThreshold;

  @override
  Widget build(BuildContext context) {
    if (deviceRef == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DatabaseEvent>(
      stream: deviceRef!.onValue,
      builder: (context, snapshot) {
        final raw = snapshot.data?.snapshot.value;
        final map = raw is Map ? raw : const <Object?, Object?>{};

        final rawMoisture = map['moisture'];
        final moisture = _SystemStatusScreenState._rawMoistureToPercent(rawMoisture);

        final isDry = moisture != null && moisture < dryThreshold;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Moisture Level',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Text(
              moisture == null ? '—' : '${moisture.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800),
            ),
            if (isDry) ...[
              const SizedBox(height: 6),
              Text(
                'pumping...',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }
}
