import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'features/common/presentation/screens/dashboard_screen.dart';
import 'features/common/presentation/screens/activation_screen.dart';
import 'core/widgets/license_check_wrapper.dart';
import 'core/providers/tenant_provider.dart';
import 'core/widgets/online_orders_listener.dart';
import 'firebase_options.dart';

void main() async {
  debugPrint('POS Application starting...');
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    debugPrint('Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Anonymous Sign-in for Security Rules
    debugPrint('Signing in anonymously...');
    await FirebaseAuth.instance.signInAnonymously();

    debugPrint('Configuring Firestore settings...');
    // Enable Offline Persistence unconditionally to fix offline mode on Windows
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase/Firestore initialization warning: $e');
  }

  debugPrint('Loading SharedPreferences...');
  final prefs = await SharedPreferences.getInstance();
  
  debugPrint('Preparation complete. Running app.');
  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
    child: const MyApp(),
  ));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);

    return MaterialApp(
      title: 'POS System',
      debugShowCheckedModeBanner: false,
      // دعم اللغة العربية
      locale: const Locale('ar', 'IQ'),
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
      ),
      home: tenantId.isEmpty 
          ? const ActivationScreen()
          : const LicenseCheckWrapper(child: OnlineOrdersListenerWrapper(child: DashboardScreen())),
    );
  }
}
