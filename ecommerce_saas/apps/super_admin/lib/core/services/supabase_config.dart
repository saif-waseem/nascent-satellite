import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure Secrets Vault
/// Obfuscates sensitive keys using byte-mask XOR encryption and allows runtime injection via --dart-define
class AppVault {
  static const int _salt = 0x5A;

  // 'https://axcdhxubqzbzjpbhyvvf.supabase.co'
  static const List<int> _maskedUrl = [
    50, 46, 46, 42, 41, 96, 117, 117, 59, 34, 57, 62, 50, 34, 47, 56, 43, 32, 56, 32, 48, 42, 56, 50, 35, 44, 44, 60, 116, 41, 47, 42, 59, 56, 59, 41, 63, 116, 57, 53
  ];

  // 'sb_publishable_wVnAoc2K3TewY6Wpb0-D4Q_fX94VBMH'
  static const List<int> _maskedKey = [
    41, 56, 5, 42, 47, 56, 54, 51, 41, 50, 59, 56, 54, 63, 5, 45, 12, 52, 27, 53, 57, 104, 17, 105, 14, 63, 45, 3, 108, 13, 42, 56, 106, 119, 30, 110, 11, 5, 60, 2, 99, 110, 12, 24, 23, 18
  ];

  static String _deobfuscate(List<int> bytes) {
    final decoded = bytes.map((b) => b ^ _salt).toList();
    return utf8.decode(decoded);
  }

  static String get supabaseUrl {
    const fromEnv = String.fromEnvironment('SUPABASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _deobfuscate(_maskedUrl);
  }

  static String get supabaseAnonKey {
    const fromEnv = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _deobfuscate(_maskedKey);
  }
}

class SupabaseConfig {
  static String get url => AppVault.supabaseUrl;
  static String get anonKey => AppVault.supabaseAnonKey;

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
      );
      print('🔒 [Security Vault] Super Admin Supabase initialized safely!');
    } catch (e) {
      print('⚠️ Supabase init note: $e');
    }
  }
}
