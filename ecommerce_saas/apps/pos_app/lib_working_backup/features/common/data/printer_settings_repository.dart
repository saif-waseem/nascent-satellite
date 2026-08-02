import 'package:shared_preferences/shared_preferences.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// نوع ورقة الطابعة
enum PaperType {
  thermal80mm, // طابعة حرارية 80mm
  a4,          // طابعة عادية A4
}

/// قياسات ورق الوصلات الجاهزة (Receipt Presets)
enum ReceiptPreset {
  thermal58,   // 58mm
  thermal80,   // 80mm
  a4,          // A4
  custom,      // مخصص
}

/// قياسات ملصقات الباركود الجاهزة (Label Presets)
enum LabelPreset {
  jewelry3020,  // 30x20mm
  standard4030, // 40x30mm
  shipping100150, // 100x150mm
  custom,       // مخصص
}

enum LabelPrinterProtocol {
  auto,
  tspl,
  zpl,
  pdf,
}

class PrinterSettings {
  final String? receiptPrinterId;
  final String? labelPrinterId;
  final String? reportPrinterId;
  final PaperType paperType;
  final ReceiptPreset receiptPreset;
  final LabelPreset labelPreset;
  final LabelPrinterProtocol labelProtocol;
  
  // Custom Dimensions (in mm)
  final double customWidth;
  final double customHeight;
  final double customMargin;

  // Bluetooth Settings (Receipts)
  final bool useBluetooth;
  final String? bluetoothPrinterMac;

  // Bluetooth Settings (Labels)
  final bool useBluetoothForLabels;
  final String? bluetoothLabelPrinterMac;

  PrinterSettings({
    this.receiptPrinterId,
    this.labelPrinterId,
    this.reportPrinterId,
    this.paperType = PaperType.thermal80mm,
    this.receiptPreset = ReceiptPreset.thermal80,
    this.labelPreset = LabelPreset.standard4030,
    this.labelProtocol = LabelPrinterProtocol.auto,
    this.customWidth = 80,
    this.customHeight = 0, // 0 means continuous/auto
    this.customMargin = 2,
    this.useBluetooth = false,
    this.bluetoothPrinterMac,
    this.useBluetoothForLabels = false,
    this.bluetoothLabelPrinterMac,
  });

  PrinterSettings copyWith({
    String? receiptPrinterId,
    String? labelPrinterId,
    String? reportPrinterId,
    PaperType? paperType,
    ReceiptPreset? receiptPreset,
    LabelPreset? labelPreset,
    LabelPrinterProtocol? labelProtocol,
    double? customWidth,
    double? customHeight,
    double? customMargin,
    bool? useBluetooth,
    String? bluetoothPrinterMac,
    bool? useBluetoothForLabels,
    String? bluetoothLabelPrinterMac,
  }) {
    return PrinterSettings(
      receiptPrinterId: receiptPrinterId ?? this.receiptPrinterId,
      labelPrinterId: labelPrinterId ?? this.labelPrinterId,
      reportPrinterId: reportPrinterId ?? this.reportPrinterId,
      paperType: paperType ?? this.paperType,
      receiptPreset: receiptPreset ?? this.receiptPreset,
      labelPreset: labelPreset ?? this.labelPreset,
      labelProtocol: labelProtocol ?? this.labelProtocol,
      customWidth: customWidth ?? this.customWidth,
      customHeight: customHeight ?? this.customHeight,
      customMargin: customMargin ?? this.customMargin,
      useBluetooth: useBluetooth ?? this.useBluetooth,
      bluetoothPrinterMac: bluetoothPrinterMac ?? this.bluetoothPrinterMac,
      useBluetoothForLabels: useBluetoothForLabels ?? this.useBluetoothForLabels,
      bluetoothLabelPrinterMac: bluetoothLabelPrinterMac ?? this.bluetoothLabelPrinterMac,
    );
  }
}

class PrinterSettingsRepository {
  static const String _receiptKey = 'receipt_printer_id';
  static const String _labelKey = 'label_printer_id';
  static const String _reportKey = 'report_printer_id';
  static const String _paperTypeKey = 'paper_type';
  static const String _receiptPresetKey = 'receipt_preset';
  static const String _labelPresetKey = 'label_preset';
  static const String _labelProtocolKey = 'label_protocol';
  static const String _customWidthKey = 'custom_width';
  static const String _customHeightKey = 'custom_height';
  static const String _customMarginKey = 'custom_margin';
  static const String _useBluetoothKey = 'use_bluetooth';
  static const String _bluetoothMacKey = 'bluetooth_mac';
  static const String _useBluetoothLabelsKey = 'use_bluetooth_labels';
  static const String _bluetoothLabelsMacKey = 'bluetooth_labels_mac';

  Future<PrinterSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final paperTypeStr = prefs.getString(_paperTypeKey);
    final paperType = paperTypeStr == 'a4' ? PaperType.a4 : PaperType.thermal80mm;
    
    final receiptPresetStr = prefs.getString(_receiptPresetKey);
    final receiptPreset = ReceiptPreset.values.firstWhere(
      (e) => e.name == receiptPresetStr, 
      orElse: () => ReceiptPreset.thermal80
    );

    final labelPresetStr = prefs.getString(_labelPresetKey);
    final labelPreset = LabelPreset.values.firstWhere(
      (e) => e.name == labelPresetStr, 
      orElse: () => LabelPreset.standard4030
    );

    final labelProtocolStr = prefs.getString(_labelProtocolKey);
    final labelProtocol = LabelPrinterProtocol.values.firstWhere(
      (e) => e.name == labelProtocolStr,
      orElse: () => LabelPrinterProtocol.auto
    );

    return PrinterSettings(
      receiptPrinterId: prefs.getString(_receiptKey),
      labelPrinterId: prefs.getString(_labelKey),
      reportPrinterId: prefs.getString(_reportKey),
      paperType: paperType,
      receiptPreset: receiptPreset,
      labelPreset: labelPreset,
      labelProtocol: labelProtocol,
      customWidth: prefs.getDouble(_customWidthKey) ?? 40,
      customHeight: prefs.getDouble(_customHeightKey) ?? 30,
      customMargin: prefs.getDouble(_customMarginKey) ?? 2,
      useBluetooth: prefs.getBool(_useBluetoothKey) ?? false,
      bluetoothPrinterMac: prefs.getString(_bluetoothMacKey),
      useBluetoothForLabels: prefs.getBool(_useBluetoothLabelsKey) ?? false,
      bluetoothLabelPrinterMac: prefs.getString(_bluetoothLabelsMacKey),
    );
  }

  Future<void> saveReceiptPrinter(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_receiptKey);
    } else {
      await prefs.setString(_receiptKey, id);
    }
  }

  Future<void> saveLabelPrinter(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_labelKey);
    } else {
      await prefs.setString(_labelKey, id);
    }
  }

  Future<void> saveReportPrinter(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_reportKey);
    } else {
      await prefs.setString(_reportKey, id);
    }
  }

  Future<void> savePaperType(PaperType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_paperTypeKey, type == PaperType.a4 ? 'a4' : 'thermal80mm');
  }

  Future<void> saveReceiptPreset(ReceiptPreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_receiptPresetKey, preset.name);
  }

  Future<void> saveLabelPreset(LabelPreset preset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_labelPresetKey, preset.name);
  }

  Future<void> saveLabelProtocol(LabelPrinterProtocol protocol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_labelProtocolKey, protocol.name);
  }

  Future<void> saveCustomDimensions({double? width, double? height, double? margin}) async {
    final prefs = await SharedPreferences.getInstance();
    if (width != null) await prefs.setDouble(_customWidthKey, width);
    if (height != null) await prefs.setDouble(_customHeightKey, height);
    if (margin != null) await prefs.setDouble(_customMarginKey, margin);
  }

  Future<void> saveBluetoothSettings(bool enable, String? macAddress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useBluetoothKey, enable);
    if (macAddress == null) {
      await prefs.remove(_bluetoothMacKey);
    } else {
      await prefs.setString(_bluetoothMacKey, macAddress);
    }
  }

  Future<void> saveBluetoothLabelSettings(bool enable, String? macAddress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useBluetoothLabelsKey, enable);
    if (macAddress == null) {
      await prefs.remove(_bluetoothLabelsMacKey);
    } else {
      await prefs.setString(_bluetoothLabelsMacKey, macAddress);
    }
  }
}

final printerSettingsRepositoryProvider = Provider((ref) => PrinterSettingsRepository());

final printerSettingsProvider = FutureProvider<PrinterSettings>((ref) async {
  return ref.watch(printerSettingsRepositoryProvider).getSettings();
});
