import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SuperAdminDrawer extends StatelessWidget {
  const SuperAdminDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          const UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.blueGrey),
            accountName: Text('Super Admin'),
            accountEmail: Text('System Operations'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.security, color: Colors.blueGrey, size: 40),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.business),
            title: const Text('Tenants Management'),
            onTap: () {
              Navigator.pop(context);
              context.go('/');
            },
          ),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('App Updates'),
            onTap: () {
              Navigator.pop(context);
              context.go('/updates');
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Global Settings'),
            onTap: () {
              Navigator.pop(context);
              context.go('/settings');
            },
          ),
          const Divider(),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              // TODO: Implement actual super admin logout if needed
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
