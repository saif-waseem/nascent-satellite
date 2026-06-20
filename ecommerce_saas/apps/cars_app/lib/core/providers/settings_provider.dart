import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/tenant_provider.dart';

class OfficeSettings {
  final String officeName;
  final String managerName;
  final String officeAddress;
  final String phone;
  final String licenseNumber;
  final String? logoImagePath;
  final bool showStats;

  const OfficeSettings({
    this.officeName = 'مكتب السيارات',
    this.managerName = '',
    this.officeAddress = '',
    this.phone = '',
    this.licenseNumber = '',
    this.logoImagePath,
    this.showStats = true,
  });

  OfficeSettings copyWith({
    String? officeName,
    String? managerName,
    String? officeAddress,
    String? phone,
    String? licenseNumber,
    String? logoImagePath,
    bool? showStats,
    bool clearLogo = false,
  }) {
    return OfficeSettings(
      officeName: officeName ?? this.officeName,
      managerName: managerName ?? this.managerName,
      officeAddress: officeAddress ?? this.officeAddress,
      phone: phone ?? this.phone,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      logoImagePath: clearLogo ? null : (logoImagePath ?? this.logoImagePath),
      showStats: showStats ?? this.showStats,
    );
  }

  Map<String, dynamic> toJson() => {
        'officeName': officeName,
        'managerName': managerName,
        'officeAddress': officeAddress,
        'phone': phone,
        'licenseNumber': licenseNumber,
        'logoImagePath': logoImagePath,
        'showStats': showStats,
      };

  factory OfficeSettings.fromJson(Map<String, dynamic> json) => OfficeSettings(
        officeName: json['officeName'] as String? ?? 'مكتب السيارات',
        managerName: json['managerName'] as String? ?? '',
        officeAddress: json['officeAddress'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        licenseNumber: json['licenseNumber'] as String? ?? '',
        logoImagePath: json['logoImagePath'] as String?,
        showStats: json['showStats'] as bool? ?? true,
      );
}

class SettingsNotifier extends Notifier<OfficeSettings> {
  static const _key = 'office_settings';

  @override
  OfficeSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        return OfficeSettings.fromJson(json.decode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return const OfficeSettings();
  }

  Future<void> save(OfficeSettings settings) async {
    state = settings;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, json.encode(settings.toJson()));
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, OfficeSettings>(SettingsNotifier.new);
