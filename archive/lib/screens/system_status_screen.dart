import 'package:flutter/material.dart';

import '../models/system.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/hydro_app_bar.dart';

class SystemStatusScreen extends StatelessWidget {
  const SystemStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final system = _systemFromArgs(context, state);

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
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
                  const SizedBox(height: 18),
                  const _StatusRow(label: 'PH'),
                  const SizedBox(height: 18),
                  const _StatusRow(label: 'Soil Moisture'),
                  const SizedBox(height: 18),
                  const _StatusRow(label: 'Particle Size'),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Refresh',
                          onPressed: state.refreshStatus,
                          icon: const Icon(Icons.refresh),
                        ),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last Updated:',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              _formatDate(state.lastUpdated),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
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
      },
    );
  }

  static HydroSystem _systemFromArgs(BuildContext context, AppState state) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is HydroSystem) return args;
    return state.systems.isEmpty
        ? HydroSystem(name: 'System', batchId: '')
        : state.systems.first;
  }

  static String _formatDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)}';
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 180,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Divider(
            thickness: 2,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
