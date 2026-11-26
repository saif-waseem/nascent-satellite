import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:user_app/core/router/app_router.dart';
import 'package:user_app/core/theme/app_theme.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:user_app/core/localization/kurdish_material_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:user_app/firebase_options.dart';
import 'package:user_app/features/shared/providers.dart';
import 'package:user_app/core/widgets/check_update_wrapper.dart';
import 'package:user_app/core/services/local_cache_service.dart';
import 'package:user_app/core/services/notification_service.dart';
import 'package:shared_ui/shared_ui.dart';

final localCacheServiceProvider = Provider((ref) => LocalCacheService());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Local Cache (Hive)
  final cacheService = LocalCacheService();
  await cacheService.init();

  // Environment Audit
  final options = DefaultFirebaseOptions.currentPlatform;
  final isConfigured = !options.apiKey.contains('REPLACE_WITH_');
  if (!isConfigured) {
    debugPrint('WARNING: Firebase is NOT configured. Synchronization will fail.');
  }

  await Firebase.initializeApp(options: options);

  // --- NEW: Sign in anonymously to pass Firestore 'isAuthenticated' rules ---
  if (isConfigured) {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously().timeout(const Duration(seconds:8));
        debugPrint('Debug: User App signed in anonymously as ${auth.currentUser?.uid}');
      } else {
        debugPrint('Debug: User App already signed in as ${auth.currentUser?.uid}');
      }
    } catch (e, stack) {
      debugPrint('Debug: User App anonymous sign-in failed: $e');
      debugPrint('Stacktrace: $stack');
    }
  }

  // Initialize Notifications
  final container = ProviderContainer(overrides: [
    localCacheServiceProvider.overrideWithValue(cacheService),
  ]);
  container.read(notificationServiceProvider).init();

  runApp(UncontrolledProviderScope(
    container: container,
    child: isConfigured ? const UserApp() : const ConfigErrorApp(),
  ));
}

class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 80),
                const SizedBox(height: 24),
                const Text('Firebase Config Missing', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text(
                  'Apps are not connected to Firebase. Synchronization will not work.\nPlease add your real Firebase API Keys to firebase_options.dart.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Continue in Mock Mode (Guest Only)'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UserApp extends ConsumerWidget {
  const UserApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final tenantAsync = ref.watch(tenantProvider);
    
    // Force initialization of auth state to check for existing login
    ref.watch(userPhoneProvider);

    final tenant=tenantAsync.value;
        final seedColor = tenant != null ? ColorUtils.fromHex(tenant.primaryColor) : Colors.blue;
        
        return MaterialApp.router(
          title: tenant?.name ?? 'E-Commerce App',
          theme: AppTheme.getLightTheme(seedColor),
          darkTheme: AppTheme.getDarkTheme(seedColor),
          themeMode: settings.themeMode,
          locale: settings.locale,
          localizationsDelegates: const [
            KurdishMaterialLocalizationsDelegate(),
            KurdishCupertinoLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
            Locale('ku'),
          ],
          routerConfig: ref.watch(appRouterProvider),
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.25),
              ),
              child: CheckUpdateWrapper(child: child!),
            );
          },
          debugShowCheckedModeBanner: false,
        );
  }
}
