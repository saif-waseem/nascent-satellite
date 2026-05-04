import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettingsState>(() {
  return AppSettingsNotifier();
});

class AppSettingsState {
  final Locale locale;
  final ThemeMode themeMode;

  AppSettingsState({
    required this.locale, 
    required this.themeMode,
  });

  AppSettingsState copyWith({Locale? locale, ThemeMode? themeMode}) {
    return AppSettingsState(
      locale: locale ?? this.locale,
      themeMode: themeMode ?? this.themeMode,
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
    );
  }

  static const _kLocaleKey = 'admin_locale';
  static const _kThemeKey = 'admin_theme';

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_kLocaleKey) ?? 'ar';
    final isDark = prefs.getBool(_kThemeKey) ?? false;

    state = AppSettingsState(
      locale: Locale(localeCode),
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
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
}
