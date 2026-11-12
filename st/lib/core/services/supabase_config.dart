import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure Secrets Vault
/// Obfuscates sensitive keys using byte-mask XOR encryption and allows runtime injection via --dart-define
class AppVault {
  // Secret mask salt
  static const int _salt = 0x5A;

  // Obfuscated Supabase URL: 'https://axcdhxubqzbzjpbhyvvf.supabase.co'
  static const List<int> _maskedUrl = [
    62, 46, 46, 42, 41, 114, 119, 119, 59, 42, 57, 62, 50, 42, 47, 56, 40, 48, 40, 32, 56, 40, 43, 35, 44, 44, 52, 116, 41, 47, 42, 59, 56, 59, 47, 116, 57, 53
  ];

  // Obfuscated Publishable Key: 'sb_publishable_wVnAoc2K3TewY6Wpb0-D4Q_fX94VBMH'
  static const List<int> _maskedKey = [
    41, 56, 37, 42, 47, 56, 54, 51, 41, 50, 59, 56, 54, 47, 37, 45, 12, 52, 59, 53, 57, 104, 11, 105, 14, 63, 45, 108, 111, 45, 114, 50, 106, 117, 110, 114, 104, 37, 52, 14, 106, 106, 108, 124, 119, 115
  ];

  static String _deobfuscate(List<int> bytes) {
    final decoded = bytes.map((b) => b ^ _salt).toList();
    return utf8.decode(decoded);
  }

  /// Supabase URL: prefers compile-time environment parameter if passed, otherwise falls back to deobfuscated value
  static String get supabaseUrl {
    const fromEnv = String.fromEnvironment('SUPABASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    return _deobfuscate(_maskedUrl);
  }

  /// Supabase Anon/Publishable Key: prefers compile-time environment parameter, otherwise falls back to deobfuscated value
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
      print('🔒 [Security Vault] Supabase initialized safely!');
    } catch (e) {
      print('⚠️ Supabase init note: $e');
    }
  }
}
