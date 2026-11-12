import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'core/services/local_db_service.dart';
import 'core/services/supabase_config.dart';
import 'core/providers/tenant_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/screens/activation_screen.dart';
import 'features/cars/presentation/screens/cars_dashboard_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalDbService.init();

  // Initialize Supabase SQL Database (New Architecture)
  await SupabaseConfig.initialize();

  // Initialize Firebase SDK (same method as pos_app - fixes network issue)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Anonymous sign-in for Firestore security rules
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    debugPrint('Firebase init warning: $e');
  }

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
      title: 'برنامج عقود سيارات - بوابة سومر',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: const Locale('ar', 'IQ'),
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
