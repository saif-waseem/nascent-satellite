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
}

/// قياسات ملصقات الباركود الجاهزة (Label Presets)
enum LabelPreset {
  jewelry3020,  // 30x20mm
  standard4030, // 40x30mm
  shipping100150, // 100x150mm
}

class PrinterSettings {
  final String? receiptPrinterId;
  final String? labelPrinterId;
  final String? reportPrinterId;
  final PaperType paperType;
  final ReceiptPreset receiptPreset;
  final LabelPreset labelPreset;

  PrinterSettings({
    this.receiptPrinterId,
    this.labelPrinterId,
    this.reportPrinterId,
    this.paperType = PaperType.thermal80mm,
    this.receiptPreset = ReceiptPreset.thermal80,
    this.labelPreset = LabelPreset.standard4030,
  });

  PrinterSettings copyWith({
    String? receiptPrinterId,
    String? labelPrinterId,
    String? reportPrinterId,
    PaperType? paperType,
    ReceiptPreset? receiptPreset,
    LabelPreset? labelPreset,
  }) {
    return PrinterSettings(
      receiptPrinterId: receiptPrinterId ?? this.receiptPrinterId,
      labelPrinterId: labelPrinterId ?? this.labelPrinterId,
      reportPrinterId: reportPrinterId ?? this.reportPrinterId,
      paperType: paperType ?? this.paperType,
      receiptPreset: receiptPreset ?? this.receiptPreset,
      labelPreset: labelPreset ?? this.labelPreset,
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

    return PrinterSettings(
      receiptPrinterId: prefs.getString(_receiptKey),
      labelPrinterId: prefs.getString(_labelKey),
      reportPrinterId: prefs.getString(_reportKey),
      paperType: paperType,
      receiptPreset: receiptPreset,
      labelPreset: labelPreset,
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
}

final printerSettingsRepositoryProvider = Provider((ref) => PrinterSettingsRepository());

final printerSettingsProvider = FutureProvider<PrinterSettings>((ref) async {
  return ref.watch(printerSettingsRepositoryProvider).getSettings();
});
