import 'package:flutter/material.dart';

import '../routes.dart';
import '../state/app_state.dart';
import '../widgets/circle_icon_button.dart';
import '../widgets/hydro_app_bar.dart';
import '../widgets/labeled_text_field.dart';

class AddSystemScreen extends StatefulWidget {
  const AddSystemScreen({super.key});

  @override
  State<AddSystemScreen> createState() => _AddSystemScreenState();
}

class _AddSystemScreenState extends State<AddSystemScreen> {
  final TextEditingController _systemId = TextEditingController();
  final TextEditingController _systemName = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _systemId.dispose();
    _systemName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: const HydroAppBar(
        title: 'Add System',
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
                    label: 'System ID',
                    controller: _systemId,
                    hintText: 'XXXX-XXXX',
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 22),
                  LabeledTextField(
                    label: 'System Name',
                    controller: _systemName,
                    hintText: 'Tomatoes',
                    enabled: !_busy,
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: 140,
                    height: 40,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      onPressed: _busy
                          ? null
                          : () async {
                              final id = _systemId.text.trim();
                              final name = _systemName.text.trim();
                              if (id.isEmpty || name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter both fields'),
                                  ),
                                );
                                return;
                              }
                              setState(() => _busy = true);
                              try {
                                await state.addSystem(id: id, name: name);
                                if (!context.mounted) return;
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  Routes.systems,
                                  (_) => false,
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString())),
                                );
                              } finally {
                                if (context.mounted) {
                                  setState(() => _busy = false);
                                }
                              }
                            },
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Add System'),
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
