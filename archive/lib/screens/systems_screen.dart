import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

import '../models/system.dart';
import '../routes.dart';
import '../state/app_state.dart';
import '../widgets/hydro_app_bar.dart';

class SystemsScreen extends StatelessWidget {
  const SystemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        return Scaffold(
          appBar: HydroAppBar(
            title: 'Systems',
            avatar: Image.asset('images/58114_20562', width: 32, height: 32),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              'My Systems',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            Image.asset('images/100_669', height: 22),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 1),
                        Expanded(
                          child: state.systems.isEmpty
                              ? Center(
                                  child: Text(
                                    'No systems yet. Tap + to add one.',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  itemCount: state.systems.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 2),
                                  itemBuilder: (context, index) {
                                    final system = state.systems[index];
                                    return _SystemRow(
                                      system: system,
                                      onTap: () {
                                        Navigator.of(context).pushNamed(
                                          Routes.systemStatus,
                                          arguments: system,
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).pushNamed(Routes.addSystem);
                            },
                            child: const Icon(Icons.add),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SystemRow extends StatelessWidget {
  const _SystemRow({
    required this.system,
    required this.onTap,
  });

  final HydroSystem system;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = TextStyle(color: Colors.grey.shade600, fontSize: 12);

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      title: Text(
        system.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ID: ${system.id}',
            style: subtitleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          _MoistureText(systemId: system.id, style: subtitleStyle),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _MoistureText extends StatelessWidget {
  const _MoistureText({required this.systemId, required this.style});

  final String systemId;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    DatabaseReference ref;
    try {
      ref = FirebaseDatabase.instance.ref('devices/$systemId/moisture');
    } catch (_) {
      return Text('Moisture: —', style: style);
    }

    return StreamBuilder<DatabaseEvent>(
      stream: ref.onValue,
      builder: (context, snapshot) {
        final raw = snapshot.data?.snapshot.value;
        final moisture = switch (raw) {
          num v => v.toDouble(),
          String v => double.tryParse(v),
          _ => null,
        };

        final text = moisture == null
            ? 'Moisture: —'
            : 'Moisture: ${moisture.toStringAsFixed(0)}';
        return Text(text, style: style);
      },
    );
  }
}
