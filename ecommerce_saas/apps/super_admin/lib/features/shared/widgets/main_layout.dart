import 'package:flutter/material.dart';
import 'package:super_admin/features/shared/widgets/super_admin_sidebar.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  final String currentRoute;

  const MainLayout({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 1000;

    return Scaffold(
      drawer: isDesktop ? null : Drawer(
        child: SuperAdminSidebar(currentRoute: currentRoute),
      ),
      body: Row(
        children: [
          if (isDesktop)
            SuperAdminSidebar(
              currentRoute: currentRoute,
              isPermanent: true,
            ),
          Expanded(
            child: child,
          ),
        ],
      ),
    );
  }
}
