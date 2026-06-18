import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/local_db_service.dart';
import 'core/providers/tenant_provider.dart';
import 'features/auth/presentation/screens/activation_screen.dart';
import 'features/cars/presentation/screens/cars_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDbService.init();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const CarsApp(),
  ));
}

class CarsApp extends HookConsumerWidget {
  const CarsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'برنامج عقود سيارات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo',
        useMaterial3: true,
      ),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends HookConsumerWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(tenantProvider);

    return tenantAsync.when(
      data: (tenant) {
        if (tenant == null || !tenant.isCarsEnabled) {
          return const ActivationScreen();
        }
        return const CarsDashboardScreen();
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => const ActivationScreen(),
    );
  }
}
