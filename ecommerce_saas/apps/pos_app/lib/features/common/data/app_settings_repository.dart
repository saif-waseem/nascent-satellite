import 'package:shared_preferences/shared_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AppSettings {
  final String barcodeTemplate;
  final String receiptHeader;
  final String receiptFooter;
  final bool isCloudSyncEnabled;
  final double pointsPerCurrencyUnit;  // e.g. 1000 IQD = 1 point
  final double pointsValue;            // e.g. 1 point = 100 IQD discount
  final bool loyaltyEnabled;
  final String? printerName;
  final String? printerType; // 'windows', 'network', 'bluetooth'
  final bool autoPrintReceipt;
  final bool openCashDrawer;

  AppSettings({
    this.barcodeTemplate = 'Standard',
    this.receiptHeader = '',
    this.receiptFooter = '',
    this.isCloudSyncEnabled = true,
    this.pointsPerCurrencyUnit = 1000,
    this.pointsValue = 100,
    this.loyaltyEnabled = true,
    this.printerName,
    this.printerType,
    this.autoPrintReceipt = false,
    this.openCashDrawer = false,
  });

  AppSettings copyWith({
    String? barcodeTemplate,
    String? receiptHeader,
    String? receiptFooter,
    bool? isCloudSyncEnabled,
    double? pointsPerCurrencyUnit,
    double? pointsValue,
    bool? loyaltyEnabled,
    String? printerName,
    String? printerType,
    bool? autoPrintReceipt,
    bool? openCashDrawer,
  }) {
    return AppSettings(
      barcodeTemplate: barcodeTemplate ?? this.barcodeTemplate,
      receiptHeader: receiptHeader ?? this.receiptHeader,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      isCloudSyncEnabled: isCloudSyncEnabled ?? this.isCloudSyncEnabled,
      pointsPerCurrencyUnit: pointsPerCurrencyUnit ?? this.pointsPerCurrencyUnit,
      pointsValue: pointsValue ?? this.pointsValue,
      loyaltyEnabled: loyaltyEnabled ?? this.loyaltyEnabled,
      printerName: printerName ?? this.printerName,
      printerType: printerType ?? this.printerType,
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
      openCashDrawer: openCashDrawer ?? this.openCashDrawer,
    );
  }
}

class AppSettingsRepository {
  static const String _barcodeKey = 'barcode_template';
  static const String _receiptHeaderKey = 'receipt_header';
  static const String _receiptFooterKey = 'receipt_footer';
  static const String _syncKey = 'is_cloud_sync_enabled';
  static const String _pointsPerUnitKey = 'points_per_currency_unit';
  static const String _pointsValueKey = 'points_value';
  static const String _loyaltyEnabledKey = 'loyalty_enabled';
  static const String _printerNameKey = 'printer_name';
  static const String _printerTypeKey = 'printer_type';
  static const String _autoPrintReceiptKey = 'auto_print_receipt';
  static const String _openCashDrawerKey = 'open_cash_drawer';

  Future<AppSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      barcodeTemplate: prefs.getString(_barcodeKey) ?? 'Standard',
      receiptHeader: prefs.getString(_receiptHeaderKey) ?? '',
      receiptFooter: prefs.getString(_receiptFooterKey) ?? '',
      isCloudSyncEnabled: prefs.getBool(_syncKey) ?? true,
      pointsPerCurrencyUnit: prefs.getDouble(_pointsPerUnitKey) ?? 1000,
      pointsValue: prefs.getDouble(_pointsValueKey) ?? 100,
      loyaltyEnabled: prefs.getBool(_loyaltyEnabledKey) ?? true,
      printerName: prefs.getString(_printerNameKey),
      printerType: prefs.getString(_printerTypeKey),
      autoPrintReceipt: prefs.getBool(_autoPrintReceiptKey) ?? false,
      openCashDrawer: prefs.getBool(_openCashDrawerKey) ?? false,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_barcodeKey, settings.barcodeTemplate);
    await prefs.setString(_receiptHeaderKey, settings.receiptHeader);
    await prefs.setString(_receiptFooterKey, settings.receiptFooter);
    await prefs.setBool(_syncKey, settings.isCloudSyncEnabled);
    await prefs.setDouble(_pointsPerUnitKey, settings.pointsPerCurrencyUnit);
    await prefs.setDouble(_pointsValueKey, settings.pointsValue);
    await prefs.setBool(_loyaltyEnabledKey, settings.loyaltyEnabled);

    if (settings.printerName != null) await prefs.setString(_printerNameKey, settings.printerName!);
    if (settings.printerType != null) await prefs.setString(_printerTypeKey, settings.printerType!);
    await prefs.setBool(_autoPrintReceiptKey, settings.autoPrintReceipt);
    await prefs.setBool(_openCashDrawerKey, settings.openCashDrawer);
  }
}

final appSettingsRepositoryProvider = Provider((ref) => AppSettingsRepository());

final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  return ref.watch(appSettingsRepositoryProvider).getSettings();
});
