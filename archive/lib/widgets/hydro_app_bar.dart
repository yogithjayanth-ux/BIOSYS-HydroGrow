import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../routes.dart';
import '../services/google_auth.dart';

enum HydroMenuItem { systems, status, addSystem, ticket, logout }

class HydroAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HydroAppBar({
    super.key,
    required this.title,
    required this.avatar,
  });

  final String title;
  final Widget avatar;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: PopupMenuButton<HydroMenuItem>(
        icon: const Icon(Icons.menu),
        tooltip: 'Menu',
        color: const Color(0xFFF2EEF9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Colors.black12),
        ),
        itemBuilder: (context) => const [
          PopupMenuItem(value: HydroMenuItem.systems, child: Text('System')),
          PopupMenuItem(
            value: HydroMenuItem.status,
            child: Text('System Status'),
          ),
          PopupMenuItem(
            value: HydroMenuItem.addSystem,
            child: Text('Add System'),
          ),
          PopupMenuItem(
            value: HydroMenuItem.ticket,
            child: Text('Write a ticket'),
          ),
          PopupMenuDivider(),
          PopupMenuItem(value: HydroMenuItem.logout, child: Text('Log out')),
        ],
        onSelected: (value) {
          switch (value) {
            case HydroMenuItem.systems:
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(Routes.systems, (_) => false);
              return;
            case HydroMenuItem.status:
              Navigator.of(context).pushNamedAndRemoveUntil(
                Routes.systemStatus,
                (_) => false,
              );
              return;
            case HydroMenuItem.addSystem:
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(Routes.addSystem, (_) => false);
              return;
            case HydroMenuItem.ticket:
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(Routes.ticket, (_) => false);
              return;
            case HydroMenuItem.logout:
              () async {
                try {
                  await FirebaseAuth.instance.signOut();
                } catch (_) {}
                try {
                  await GoogleAuth.signOut();
                } catch (_) {}
              }();
              Navigator.of(context)
                  .pushNamedAndRemoveUntil(Routes.login, (_) => false);
              return;
          }
        },
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Center(child: avatar),
        ),
      ],
    );
  }
}
