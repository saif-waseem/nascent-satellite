import 'package:go_router/go_router.dart';
import 'package:super_admin/features/tenants/presentation/screens/tenants_screen.dart';
import 'package:super_admin/features/dashboard/presentation/screens/app_updates_screen.dart';
import 'package:super_admin/features/settings/presentation/screens/global_settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const TenantsScreen(),
    ),
    GoRoute(
      path: '/updates',
      builder: (context, state) => const AppUpdatesScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const GlobalSettingsScreen(),
    ),
  ],
);
