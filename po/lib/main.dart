import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'core/services/firebase_rest_auth_service.dart';
import 'core/services/local_db_service.dart';

import 'features/common/presentation/screens/dashboard_screen.dart';
import 'features/common/presentation/screens/activation_screen.dart';
import 'core/widgets/license_check_wrapper.dart';
import 'core/providers/tenant_provider.dart';
import 'core/widgets/online_orders_listener.dart';
import 'core/widgets/stock_alert_listener.dart';
import 'firebase_options.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      debugPrint('Initializing Local Database...');
      await LocalDbService.init();
      debugPrint('Local Database Ready.');
    } catch (e) {
      debugPrint('Local Database init error: $e');
    }

    try {
      debugPrint('Initializing Firebase Core...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 15));
      debugPrint('Firebase Core Ready.');
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }

    try {
      await windowManager.ensureInitialized();
      const WindowOptions windowOptions = WindowOptions(
        size: Size(1280, 720),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.normal,
        title: 'نظام المبيعات الذكي',
      );
      await windowManager.setPreventClose(true);
      unawaited(windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      }));
    } catch (e) {
      debugPrint('WindowManager Error: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      
      runApp(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MyApp(),
      ));
    } catch (e) {
      runApp(const ProviderScope(child: MyApp()));
    }
  }, (error, stack) {
    debugPrint('Uncaught error: $error\n$stack');
  });
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatefulHookConsumerWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      final context = _navigatorKey.currentContext;
      if (context != null) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('إغلاق التطبيق'),
            content: const Text('هل أنت متأكد من رغبتك في إغلاق نظام المبيعات؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () async {
                  await windowManager.setPreventClose(false);
                  await windowManager.destroy();
                },
                child: const Text('إغلاق نهائي'),
              ),
            ],
          ),
        );
      } else {
        await windowManager.destroy();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('Building MyApp widget...');
    final tenantId = ref.watch(tenantIdProvider);
    debugPrint('Current tenantId: "$tenantId"');

    // Perform silent anonymous sign-in if not already done
    useEffect(() {
      Future.microtask(() async {
        await ref.read(authRestServiceProvider.notifier).signInAnonymously();
      });
      return null;
    }, []);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'نظام المبيعات الذكي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'IQ'),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.25),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      supportedLocales: const [
        Locale('ar', 'IQ'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'Cairo',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontFamily: 'Cairo'),
          bodyMedium: TextStyle(fontFamily: 'Cairo'),
          displayLarge: TextStyle(fontFamily: 'Cairo'),
          displayMedium: TextStyle(fontFamily: 'Cairo'),
          displaySmall: TextStyle(fontFamily: 'Cairo'),
          headlineLarge: TextStyle(fontFamily: 'Cairo'),
          headlineMedium: TextStyle(fontFamily: 'Cairo'),
          headlineSmall: TextStyle(fontFamily: 'Cairo'),
          titleLarge: TextStyle(fontFamily: 'Cairo'),
          titleMedium: TextStyle(fontFamily: 'Cairo'),
          titleSmall: TextStyle(fontFamily: 'Cairo'),
          labelLarge: TextStyle(fontFamily: 'Cairo'),
          labelMedium: TextStyle(fontFamily: 'Cairo'),
          labelSmall: TextStyle(fontFamily: 'Cairo'),
        ),
      ),
      home: _getHome(tenantId),
    );
  }

  Widget _getHome(String tenantId) {
    if (tenantId.isEmpty) {
      return const ActivationScreen();
    }
    return LicenseCheckWrapper(
      child: OnlineOrdersListenerWrapper(
        child: StockAlertListener(
          child: const DashboardScreen(),
        ),
      ),
    );
  }
}
