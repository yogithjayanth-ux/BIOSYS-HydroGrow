import 'package:flutter/material.dart';

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
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.black12),
                    ),
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
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(vertical: 8),
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
                                  onToggleFavorite: () =>
                                      state.toggleFavorite(system),
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
    required this.onToggleFavorite,
  });

  final HydroSystem system;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 0),
      leading: IconButton(
        tooltip: 'Favorite',
        onPressed: onToggleFavorite,
        icon: Icon(
          system.isFavorite ? Icons.star : Icons.star_border,
          color: system.isFavorite ? Colors.amber.shade700 : Colors.black54,
        ),
      ),
      title: Text(
        system.name,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        system.batchId,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      trailing: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.keyboard_arrow_up, size: 18),
          SizedBox(width: 2),
          Text('A', style: TextStyle(fontSize: 12)),
        ],
      ),
      onTap: onTap,
    );
  }
}

