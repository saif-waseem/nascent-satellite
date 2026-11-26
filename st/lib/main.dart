import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/router/app_router.dart';
import 'core/theme/store_theme.dart';
import 'core/localization/app_settings_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'core/widgets/check_update_wrapper.dart';
import 'core/widgets/license_check_wrapper.dart';
import 'core/services/local_cache_service.dart';
import 'package:store_admin/core/widgets/desktop_actions_wrapper.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:store_admin/core/services/notification_service.dart';
import 'package:store_admin/core/services/supabase_config.dart';
import 'package:shared_models/shared_models.dart';

final localCacheServiceProvider = Provider((ref) => LocalCacheService());

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase SQL Database & Cloudflare Storage
  await SupabaseConfig.initialize();

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
  
  // Sign in anonymously to ensure Storage permissions if rules require auth
  if (isConfigured) {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
        debugPrint('Debug: Admin App signed in anonymously as ${auth.currentUser?.uid}');
      } else {
        debugPrint('Debug: Admin App already signed in as ${auth.currentUser?.uid}');
      }
    } catch (e, stack) {
      debugPrint('Debug: Admin App anonymous sign-in failed: $e');
      debugPrint('Stacktrace: $stack');
    }
  }
  
  final container = ProviderContainer(
    overrides: [
      localCacheServiceProvider.overrideWithValue(cacheService),
    ],
  );
  // Notification Service initialization moved to where tenantId is available

  runApp(UncontrolledProviderScope(
    container: container,
    child: isConfigured ? const StoreAdminApp() : const ConfigErrorApp(),
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
                const Icon(Icons.cloud_off, color: Colors.blueGrey, size: 80),
                const SizedBox(height: 24),
                const Text('Backend Not Connected', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text(
                  'Your Admin App is not connected to any Firebase project.\nPlease configure firebase_options.dart with your API keys to enable real-time synchronization.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final notificationServiceProvider = Provider((ref) => NotificationService());

class StoreAdminApp extends ConsumerStatefulWidget {
  const StoreAdminApp({super.key});

  @override
  ConsumerState<StoreAdminApp> createState() => _StoreAdminAppState();
}

class _StoreAdminAppState extends ConsumerState<StoreAdminApp> {
  
  @override
  void initState() {
    super.initState();
    // Verify notification permissions or setup listeners if needed globally
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Debug: Building StoreAdminApp root');
    final settings = ref.watch(appSettingsProvider);
    final router = ref.watch(appRouterProvider);
    final tenantAsync = ref.watch(tenantProvider);

    // Listen for tenant changes to initialize notifications
    ref.listen<AsyncValue<TenantModel?>>(tenantProvider, (prev, next) {
      next.whenData((tenant) {
        if (tenant != null && (prev?.value == null || prev?.value?.id != tenant.id)) {
           final notifService = ref.read(notificationServiceProvider);
           notifService.initialize(tenant.id);
           notifService.onNotificationClick = (orderId) {
             // Navigate to orders and filter by ID
             ref.read(appRouterProvider).go('/orders');
             // We need a way to pass the search query. 
             // We will use a shared provider for this.
             ref.read(adminOrderSearchProvider.notifier).setSearch(orderId);
           };
        }
      });
    });

    return tenantAsync.when(
      data: (tenant) {
        final seedColor = tenant != null ? ColorUtils.fromHex(tenant.primaryColor) : const Color(0xFF006C4C);
        
        return MaterialApp.router(
          title: tenant?.name ?? 'Store Admin',
          theme: StoreTheme.getLightTheme(seedColor),
          darkTheme: StoreTheme.getDarkTheme(seedColor),
          themeMode: settings.themeMode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          locale: settings.locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('ar'),
          ],
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.25),
              ),
              child: DesktopActionsWrapper(
                child: LicenseCheckWrapper(
                  child: CheckUpdateWrapper(child: child!),
                ),
              ),
            );
          },
        );
      },
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: StoreTheme.getLightTheme(const Color(0xFF006C4C)),
        home: const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading Store Profile...'),
              ],
            ),
          ),
        ),
      ),
      error: (error, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  Text('Initialization Error: $error', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => ref.refresh(tenantProvider),
                    child: const Text('إعادة المحاولة'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => ref.read(currentTenantAuthProvider.notifier).clearTenant(),
                    icon: const Icon(Icons.arrow_back, color: Colors.red),
                    label: const Text('العودة لصفحة التفعيل', style: TextStyle(color: Colors.red)),
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

