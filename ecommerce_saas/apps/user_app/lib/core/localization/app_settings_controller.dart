import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettingsState>(() {
  return AppSettingsNotifier();
});

class AppSettingsState {
  final Locale locale;
  final ThemeMode themeMode;
  final String currencyCode;

  AppSettingsState({
    required this.locale, 
    required this.themeMode,
    required this.currencyCode,
  });

  AppSettingsState copyWith({Locale? locale, ThemeMode? themeMode, String? currencyCode}) {
    return AppSettingsState(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettingsState> {
  @override
  AppSettingsState build() {
    _loadSettings();
    return AppSettingsState(
      locale: const Locale('ar'), 
      themeMode: ThemeMode.light,
      currencyCode: 'IQD',
    );
  }

  static const _kLocaleKey = 'app_locale';
  static const _kThemeKey = 'app_theme';
  static const _kCurrencyKey = 'app_currency';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_kLocaleKey) ?? 'ar';
    final isDark = prefs.getBool(_kThemeKey) ?? false;
    final currency = prefs.getString(_kCurrencyKey) ?? 'IQD';

    state = AppSettingsState(
      locale: Locale(localeCode),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      currencyCode: currency,
    );
  }

  Future<void> setLocale(String languageCode) async {
    state = state.copyWith(locale: Locale(languageCode));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLocaleKey, languageCode);
  }

  Future<void> toggleTheme() async {
    final newMode = state.themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    state = state.copyWith(themeMode: newMode);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kThemeKey, newMode == ThemeMode.dark);
  }

  Future<void> setCurrency(String currencyCode) async {
    state = state.copyWith(currencyCode: currencyCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCurrencyKey, currencyCode);
  }
}
