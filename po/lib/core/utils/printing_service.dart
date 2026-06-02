import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:windows_printer/windows_printer.dart';
import '../../features/common/data/printer_settings_repository.dart';
import '../../features/reports/data/report_repository.dart';
import 'package:intl/intl.dart';
import 'bluetooth_printing_service.dart';
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class PrintingService {
  final PrinterSettingsRepository _repo;
  static pw.Font? _cachedArabicFont;

  PrintingService(this._repo);

  Future<pw.Font> _loadArabicFont({bool forceUpdate = false}) async {
    if (_cachedArabicFont != null && !forceUpdate) return _cachedArabicFont!;

    // 1. Try loading from local assets (Offline-first)
    try {
      final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
      _cachedArabicFont = pw.Font.ttf(fontData);
      return _cachedArabicFont!;
    } catch (e) {
      debugPrint('Loading Cairo from assets failed: $e. Falling back to Google Fonts.');
    }

    // 2. Fallback to Google Fonts (Online)
    try {
      _cachedArabicFont = await PdfGoogleFonts.cairoRegular();
      return _cachedArabicFont!;
    } catch (e) {
      debugPrint('Google Fonts Cairo failed: $e');
    }

    try {
      _cachedArabicFont = await PdfGoogleFonts.amiriRegular();
      return _cachedArabicFont!;
    } catch (e) {
      debugPrint('Google Fonts Amiri failed: $e');
    }

    _cachedArabicFont = pw.Font.helvetica();
    return _cachedArabicFont!;
  }

  pw.ThemeData _createTheme(pw.Font font) {
    return pw.ThemeData.withFont(
      base: font,
      bold: font,
      italic: font,
      boldItalic: font,
    );
  }

  Future<void> printSalesInvoice({
    required SalesInvoiceModel invoice,
    required TenantModel shopInfo,
    bool useDirectPrint = false,
    double? customerBalance,
  }) async {
    final settings = await _repo.getSettings();
    final arabicFont = await _loadArabicFont();
    
    PdfPageFormat pageFormat;
    bool isA4 = false;
    
    if (settings.receiptPreset == ReceiptPreset.custom) {
      final w = settings.customWidth > 0 ? settings.customWidth : 80.0;
      final h = settings.customHeight > 0 ? settings.customHeight : 500.0; 
      final m = settings.customMargin;
      
      pageFormat = PdfPageFormat(
        w * PdfPageFormat.mm,
        h * PdfPageFormat.mm,
        marginAll: m * PdfPageFormat.mm,
      );
      isA4 = w > 150;
    } else {
      switch (settings.receiptPreset) {
        case ReceiptPreset.a4:
          pageFormat = PdfPageFormat.a4;
          isA4 = true;
          break;
        case ReceiptPreset.thermal58:
          pageFormat = PdfPageFormat.roll57;
          break;
        case ReceiptPreset.thermal80:
        default:
          pageFormat = PdfPageFormat.roll80;
          break;
      }
    }

    pw.ImageProvider? logoImage;
    if (shopInfo.logoUrl != null && shopInfo.logoUrl!.isNotEmpty) {
      try {
        logoImage = await networkImage(shopInfo.logoUrl!);
      } catch (_) {}
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: _createTheme(arabicFont),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Column(
                    children: [
                      if (logoImage != null) ...[
                        pw.Container(height: isA4 ? 80 : 60, child: pw.Image(logoImage)),
                        pw.SizedBox(height: 8),
                      ],
                      pw.Text(shopInfo.name, style: pw.TextStyle(fontSize: isA4 ? 22 : 18, fontWeight: pw.FontWeight.bold)),
                      if (shopInfo.description.isNotEmpty) pw.Text(shopInfo.description, style: pw.TextStyle(fontSize: isA4 ? 12 : 10)),
                      pw.Text('هاتف: ${shopInfo.whatsappNumber}', style: pw.TextStyle(fontSize: isA4 ? 12 : 10)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Divider(),
                pw.Center(
                  child: pw.Column(
                    children: [
                      if (invoice.isReturned) ...[
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.red, width: 2)),
                          child: pw.Text('إرجاع / RETURN', style: pw.TextStyle(fontSize: 18, color: PdfColors.red, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.SizedBox(height: 10),
                      ],
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        children: [
                          pw.Column(
                            children: [
                              pw.SizedBox(height: isA4 ? 40 : 20),
                              pw.Text('RECEIPT', style: pw.TextStyle(fontSize: isA4 ? 16 : 14, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                          pw.SizedBox(width: 20),
                          pw.Column(
                            children: [
                              pw.BarcodeWidget(
                                barcode: pw.Barcode.code128(),
                                data: invoice.receiptNumber,
                                width: isA4 ? 120 : 100,
                                height: isA4 ? 30 : 25,
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(invoice.receiptNumber, style: pw.TextStyle(fontSize: isA4 ? 10 : 8, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.Divider(thickness: 1),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('التاريخ والوقت: ${invoice.date.toString().substring(0, 16)}', style: pw.TextStyle(fontSize: isA4 ? 11 : 9)),
                    if (invoice.customerName != null) pw.Text('الزبون: ${invoice.customerName}', style: pw.TextStyle(fontSize: isA4 ? 11 : 9)),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Table(
                  border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(3),
                    1: pw.FlexColumnWidth(1),
                    2: pw.FlexColumnWidth(2),
                    3: pw.FlexColumnWidth(2),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(border: pw.TableBorder(bottom: pw.BorderSide(width: 1))),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text('المادة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 12 : 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text('ق', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 12 : 10)))),
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text('السعر', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 12 : 10)))),
                        pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text('المجموع', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 12 : 10)))),
                      ],
                    ),
                    ...invoice.items.map((item) {
                      String itemName = item.productName.trim().isEmpty ? 'غير مصنف' : item.productName;
                      final hasColor = item.variantColor != null && item.variantColor!.isNotEmpty;
                      final hasSize = item.variantSize != null && item.variantSize!.isNotEmpty;
                      if (hasColor || hasSize) {
                        itemName += '\n(';
                        if (hasColor) itemName += item.variantColor!;
                        if (hasColor && hasSize) itemName += ' - ';
                        if (hasSize) itemName += item.variantSize!;
                        itemName += ')';
                      }
                      if (item.discount > 0) {
                        itemName += '\n(خصم: ${_formatPrice(item.discount)})';
                      }
                      return pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Text(itemName, style: pw.TextStyle(fontSize: isA4 ? 11 : 9))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Center(child: pw.Text(item.quantity.toString(), style: pw.TextStyle(fontSize: isA4 ? 11 : 9)))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text(_formatPrice(item.unitPrice), style: pw.TextStyle(fontSize: isA4 ? 11 : 9)))),
                          pw.Padding(padding: const pw.EdgeInsets.all(2), child: pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text(_formatPrice(item.totalPrice), style: pw.TextStyle(fontSize: isA4 ? 11 : 9)))),
                        ],
                      );
                    }),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('المجموع:', style: pw.TextStyle(fontSize: isA4 ? 12 : 10)),
                    pw.Text('${_formatPrice(invoice.totalAmount + invoice.discountAmount)} ${shopInfo.currencyUnit}', style: pw.TextStyle(fontSize: isA4 ? 12 : 10)),
                  ],
                ),
                if (invoice.discountAmount > 0)
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('الخصم:', style: pw.TextStyle(fontSize: isA4 ? 12 : 11, color: PdfColors.red)),
                        pw.Text('-${_formatPrice(invoice.discountAmount)} ${shopInfo.currencyUnit}', style: pw.TextStyle(fontSize: isA4 ? 12 : 11, color: PdfColors.red)),
                      ],
                    ),
                  ),
                pw.Divider(thickness: 1, color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('المجموع الكلي:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 15 : 12)),
                    pw.Text('${_formatPrice(invoice.totalAmount)} ${shopInfo.currencyUnit}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 15 : 12)),
                  ],
                ),
                if (customerBalance != null) ...[
                  pw.SizedBox(height: 10),
                  pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('الديون السابقة:', style: pw.TextStyle(fontSize: isA4 ? 11 : 9)),
                      pw.Text('${_formatPrice(customerBalance - (invoice.totalAmount - invoice.paidAmount))} ${shopInfo.currencyUnit}', style: pw.TextStyle(fontSize: isA4 ? 11 : 9)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('المتبقي من هذه الفاتورة:', style: pw.TextStyle(fontSize: isA4 ? 11 : 9)),
                      pw.Text('${_formatPrice(invoice.totalAmount - invoice.paidAmount)} ${shopInfo.currencyUnit}', style: pw.TextStyle(fontSize: isA4 ? 11 : 9)),
                    ],
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('إجمالي الديون (Balance):', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 13 : 11)),
                      pw.Text('${_formatPrice(customerBalance)} ${shopInfo.currencyUnit}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 13 : 11)),
                    ],
                  ),
                ],
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Center(child: pw.Text('شكراً لزيارتكم', style: pw.TextStyle(fontSize: isA4 ? 14 : 12, fontWeight: pw.FontWeight.bold))),
              ],
            ),
          );
        },
      ),
    );

    final bytes = await _saveWithRecovery(pdf);
    await _printPdf(bytes, settings.receiptPrinterId, format: pageFormat, useDirectPrint: useDirectPrint || (settings.receiptPrinterId != null), isLabel: false);
  }

  Future<void> printBarcodeLabel({
    required String name,
    required String barcode,
    required double price,
    required String currency,
    String? category,
    int count = 1,
    bool showName = true,
    bool showPrice = true,
    bool showBarcodeText = true,
  }) async {
    final settings = await _repo.getSettings();
    final arabicFont = await _loadArabicFont();
    final pdf = pw.Document();

    PdfPageFormat pageFormat;
    double barcodeWidth;
    double barcodeHeight;
    double fontSize;

    if (settings.labelPreset == LabelPreset.custom) {
      pageFormat = PdfPageFormat(
        settings.customWidth * PdfPageFormat.mm,
        settings.customHeight > 0 ? settings.customHeight * PdfPageFormat.mm : 30 * PdfPageFormat.mm,
        marginAll: 0,
      );
      barcodeWidth = (settings.customWidth - (settings.customMargin * 2)) * PdfPageFormat.mm;
      barcodeHeight = (settings.customHeight > 0 ? settings.customHeight * 0.35 : 10) * PdfPageFormat.mm;
      fontSize = settings.customWidth < 40 ? 8 : 10;
    } else {
      switch (settings.labelPreset) {
        case LabelPreset.jewelry3020:
          pageFormat = const PdfPageFormat(30 * PdfPageFormat.mm, 19 * PdfPageFormat.mm, marginAll: 0);
          barcodeWidth = 24 * PdfPageFormat.mm;
          barcodeHeight = 5 * PdfPageFormat.mm;
          fontSize = 7.5;
          break;
        case LabelPreset.shipping100150:
          pageFormat = const PdfPageFormat(100 * PdfPageFormat.mm, 149 * PdfPageFormat.mm, marginAll: 0);
          barcodeWidth = 80 * PdfPageFormat.mm;
          barcodeHeight = 25 * PdfPageFormat.mm;
          fontSize = 16;
          break;
        case LabelPreset.standard4030:
        default:
          pageFormat = const PdfPageFormat(40 * PdfPageFormat.mm, 29 * PdfPageFormat.mm, marginAll: 0);
          barcodeWidth = 34 * PdfPageFormat.mm;
          barcodeHeight = 7 * PdfPageFormat.mm;
          fontSize = 9;
          break;
      }
    }
    
    for (int i = 0; i < count; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          theme: _createTheme(arabicFont),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Center(
                child: pw.Container(
                  width: pageFormat.availableWidth,
                  height: pageFormat.availableHeight,
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      if (showName) ...[
                        pw.Text(
                          name.trim().isEmpty ? 'غير مصنف' : name, 
                          style: pw.TextStyle(
                            fontSize: name.length > 25 ? fontSize * 0.8 : fontSize, 
                            fontWeight: pw.FontWeight.bold
                          ), 
                          textAlign: pw.TextAlign.center, 
                          maxLines: 2,
                        ),
                        pw.SizedBox(height: 1.5),
                      ],
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.code128(),
                        data: barcode,
                        drawText: false, 

                      ),
                      if (showBarcodeText) ...[
                        pw.SizedBox(height: 1),
                        pw.Text(
                          barcode, 
                          style: pw.TextStyle(fontSize: fontSize * 0.7, fontWeight: pw.FontWeight.bold)
                        ),
                      ],
                      if (showPrice) ...[
                        pw.SizedBox(height: 0.5),
                        pw.Text(
                          '${_formatPrice(price)} $currency', 
                          style: pw.TextStyle(fontSize: fontSize * 0.9, fontWeight: pw.FontWeight.bold)
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    final Uint8List pdfBytes = await _saveWithRecovery(pdf);
    await _printPdf(pdfBytes, settings.labelPrinterId, format: pageFormat, useDirectPrint: settings.labelPrinterId != null, isLabel: true);
  }

  Future<void> printAllBarcodeLabels({
    required List<({String name, String barcode, double price, int count})> items,
    required String currency,
    bool showName = true,
    bool showPrice = true,
    bool showBarcodeText = true,
  }) async {
    final settings = await _repo.getSettings();
    final arabicFont = await _loadArabicFont();
    final pdf = pw.Document();

    PdfPageFormat pageFormat;
    double barcodeWidth;
    double barcodeHeight;
    double fontSize;

    if (settings.labelPreset == LabelPreset.custom) {
      pageFormat = PdfPageFormat(
        settings.customWidth * PdfPageFormat.mm,
        settings.customHeight > 0 ? settings.customHeight * PdfPageFormat.mm : 30 * PdfPageFormat.mm,
        marginAll: 0,
      );
      barcodeWidth = (settings.customWidth - (settings.customMargin * 2)) * PdfPageFormat.mm;
      barcodeHeight = (settings.customHeight > 0 ? settings.customHeight * 0.35 : 10) * PdfPageFormat.mm;
      fontSize = settings.customWidth < 40 ? 8 : 10;
    } else {
      switch (settings.labelPreset) {
        case LabelPreset.jewelry3020:
          pageFormat = const PdfPageFormat(30 * PdfPageFormat.mm, 19 * PdfPageFormat.mm, marginAll: 0);
          barcodeWidth = 24 * PdfPageFormat.mm;
          barcodeHeight = 5 * PdfPageFormat.mm;
          fontSize = 7.5;
          break;
        case LabelPreset.shipping100150:
          pageFormat = const PdfPageFormat(100 * PdfPageFormat.mm, 149 * PdfPageFormat.mm, marginAll: 0);
          barcodeWidth = 80 * PdfPageFormat.mm;
          barcodeHeight = 25 * PdfPageFormat.mm;
          fontSize = 16;
          break;
        case LabelPreset.standard4030:
        default:
          pageFormat = const PdfPageFormat(40 * PdfPageFormat.mm, 29 * PdfPageFormat.mm, marginAll: 0);
          barcodeWidth = 34 * PdfPageFormat.mm;
          barcodeHeight = 7 * PdfPageFormat.mm;
          fontSize = 9;
          break;
      }
    }
    
    for (final item in items) {
      for (int i = 0; i < item.count; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            theme: _createTheme(arabicFont),
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Center(
                  child: pw.Container(
                    width: pageFormat.availableWidth,
                    height: pageFormat.availableHeight,
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (showName) ...[
                          pw.Text(
                            item.name.trim().isEmpty ? 'غير مصنف' : item.name, 
                            style: pw.TextStyle(
                              fontSize: item.name.length > 25 ? fontSize * 0.8 : fontSize, 
                              fontWeight: pw.FontWeight.bold
                            ), 
                            textAlign: pw.TextAlign.center, 
                            maxLines: 2,
                          ),
                          pw.SizedBox(height: 1.5),
                        ],
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data: item.barcode,
                          drawText: false, 
                        ),
                        if (showBarcodeText) ...[
                          pw.SizedBox(height: 1),
                          pw.Text(
                            item.barcode, 
                            style: pw.TextStyle(fontSize: fontSize * 0.7, fontWeight: pw.FontWeight.bold)
                          ),
                        ],
                        if (showPrice) ...[
                          pw.SizedBox(height: 0.5),
                          pw.Text(
                            '${_formatPrice(item.price)} $currency', 
                            style: pw.TextStyle(fontSize: fontSize * 0.9, fontWeight: pw.FontWeight.bold)
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    final Uint8List pdfBytes = await _saveWithRecovery(pdf);
    await _printPdf(pdfBytes, settings.labelPrinterId, format: pageFormat, useDirectPrint: settings.labelPrinterId != null, isLabel: true);
  }

  Future<void> printPurchaseInvoice(PurchaseInvoiceModel invoice) async {
    final settings = await _repo.getSettings();
    final arabicFont = await _loadArabicFont();
    
    PdfPageFormat pageFormat;
    bool isA4 = false;
    
    if (settings.receiptPreset == ReceiptPreset.custom) {
      pageFormat = PdfPageFormat(
        settings.customWidth * PdfPageFormat.mm,
        settings.customHeight > 0 ? settings.customHeight * PdfPageFormat.mm : 500 * PdfPageFormat.mm,
        marginAll: settings.customMargin * PdfPageFormat.mm,
      );
      isA4 = settings.customWidth > 150;
    } else {
      switch (settings.receiptPreset) {
        case ReceiptPreset.a4:
          pageFormat = PdfPageFormat.a4;
          isA4 = true;
          break;
        case ReceiptPreset.thermal58:
          pageFormat = PdfPageFormat.roll57;
          break;
        case ReceiptPreset.thermal80:
        default:
          pageFormat = PdfPageFormat.roll80;
          break;
      }
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: _createTheme(arabicFont),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(child: pw.Text('فاتورة شراء / PURCHASE INVOICE', style: pw.TextStyle(fontSize: isA4 ? 20 : 16, fontWeight: pw.FontWeight.bold))),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('المورد: ${invoice.supplierName ?? invoice.supplierId}', style: pw.TextStyle(fontSize: isA4 ? 12 : 10)),
                        pw.Text('التاريخ: ${invoice.date.toString().substring(0, 16)}', style: pw.TextStyle(fontSize: isA4 ? 11 : 9)),
                        pw.Text('رقم الفاتورة: ${invoice.id.substring(0, 8)}', style: pw.TextStyle(fontSize: isA4 ? 10 : 8)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(),
                pw.Table(
                  border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
                  children: [
                    pw.TableRow(children: [
                      pw.Text('المادة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 11 : 9)),
                      pw.Text('الكمية', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 11 : 9)),
                      pw.Text('السعر', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 11 : 9)),
                      pw.Text('الإجمالي', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 11 : 9)),
                    ]),
                    ...invoice.items.map((item) => pw.TableRow(children: [
                          pw.Text(item.productName, style: pw.TextStyle(fontSize: isA4 ? 10 : 8)),
                          pw.Text(item.quantity.toString(), style: pw.TextStyle(fontSize: isA4 ? 10 : 8)),
                          pw.Text(_formatPrice(item.unitCost), style: pw.TextStyle(fontSize: isA4 ? 10 : 8)),
                          pw.Text(_formatPrice(item.totalCost), style: pw.TextStyle(fontSize: isA4 ? 10 : 8)),
                        ])),
                  ],
                ),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('الإجمالي النهائي:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 14 : 12)),
                    pw.Text('${_formatPrice(invoice.totalAmount)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: isA4 ? 14 : 12)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    final Uint8List pdfBytes = await _saveWithRecovery(pdf);
    await _printPdf(pdfBytes, settings.receiptPrinterId, format: pageFormat, useDirectPrint: settings.receiptPrinterId != null, isLabel: false);
  }

  Future<void> _printPdf(Uint8List pdfBytes, String? printerName, {PdfPageFormat? format, bool useDirectPrint = false, bool isLabel = false}) async {
    final settings = await _repo.getSettings();
    final effectiveFormat = format ?? PdfPageFormat.roll80;

    if (isLabel && !kIsWeb && defaultTargetPlatform == TargetPlatform.windows && printerName != null && printerName.isNotEmpty) {
      try {
        final profile = await CapabilityProfile.load(name: 'default');
        final paperSize = (effectiveFormat.width / PdfPageFormat.mm < 60) ? PaperSize.mm58 : PaperSize.mm80;
        final generator = Generator(paperSize, profile);
        List<int> escPosBytes = [];

        await for (final page in Printing.raster(pdfBytes, dpi: 203)) {
          final pngBytes = await page.toPng();
          final img.Image? decodedImage = img.decodeImage(pngBytes);
          if (decodedImage != null) {
            final grayImage = img.grayscale(decodedImage);
            final imageBytes = generator.imageRaster(
              grayImage,
              imageFn: PosImageFn.graphics,
            );
            escPosBytes.addAll(imageBytes);
            escPosBytes.addAll(generator.feed(1));
          }
        }

        if (escPosBytes.isNotEmpty) {
          await WindowsPrinter.printRawData(
            printerName: printerName,
            data: Uint8List.fromList(escPosBytes),
            useRawDatatype: true,
          );
          debugPrint('ESC/POS sent successfully: ${escPosBytes.length} bytes');
          return;
        }
      } catch (e) {
        throw Exception('ESC/POS failed: $e');
      }
    }

    if (useDirectPrint && printerName != null && printerName.isNotEmpty) {
      try {
        final printers = await Printing.listPrinters();
        // Try exact match first, then partial name match
        Printer? printer;
        try {
          printer = printers.firstWhere((p) => p.name == printerName || p.url == printerName);
        } catch (_) {
          try {
            printer = printers.firstWhere((p) => p.name.toLowerCase().contains(printerName.toLowerCase()));
          } catch (_) {
            printer = Printer(url: printerName, name: printerName);
          }
        }

        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (PdfPageFormat f) async => pdfBytes,
          format: effectiveFormat,
        );
        return;
      } catch (e) {
        debugPrint('Direct print failed: $e. Falling back to layoutPdf.');
      }
    } 

    final useBluetooth = isLabel ? settings.useBluetoothForLabels : settings.useBluetooth;
    final bluetoothMac = isLabel ? settings.bluetoothLabelPrinterMac : settings.bluetoothPrinterMac;

    if (useBluetooth && bluetoothMac != null) {
       try {
         final connected = await bluetoothPrinterProvider.connect(bluetoothMac);
         if (connected) {
           // We need raster image for bluetooth thermal printing since they usually don't support PDF directly
           // Remove pages: [0] to print all pages in the PDF
           await for (var page in Printing.raster(pdfBytes, dpi: 200)) {
              final imageBytes = await page.toPng();
              await bluetoothPrinterProvider.printCustomImage(imageBytes);
           }
           await bluetoothPrinterProvider.disconnect();
           return;
         }
       } catch(e) {
          debugPrint('Bluetooth print error: $e.');
       }
    }

    await Printing.layoutPdf(
      format: effectiveFormat,
      onLayout: (PdfPageFormat f) async => pdfBytes,
      name: 'وصل',
    );
  }

  Future<Uint8List> _saveWithRecovery(pw.Document pdf) async {
    try {
      return await pdf.save();
    } catch (e) {
      if (e.toString().contains('UTF-8')) {
        _cachedArabicFont = null;
      }
      final emptyPdf = pw.Document();
      final errorMsg = e.toString().replaceAll(RegExp(r'[^\x00-\x7F]+'), '');
      emptyPdf.addPage(pw.Page(build: (context) => pw.Text('Error generating PDF: $errorMsg')));
      return await emptyPdf.save();
    }
  }

  Future<void> openCashDrawer() async {
    final settings = await _repo.getSettings();
    if (settings.receiptPrinterId == null || settings.receiptPrinterId!.isEmpty) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      try {
        final bytes = [27, 112, 48, 25, 250];
        await WindowsPrinter.printRawData(
          printerName: settings.receiptPrinterId!,
          data: Uint8List.fromList(bytes),
          useRawDatatype: true,
        );
      } catch (e) {
        debugPrint('Failed to open cash drawer: $e');
      }
    } else if (settings.useBluetooth && settings.bluetoothPrinterMac != null) {
       // Typically sending ESC POS command [27, 112, 0, 25, 250] to bluetooth printer opens drawer if connected to it
       try {
         final connected = await bluetoothPrinterProvider.connect(settings.bluetoothPrinterMac!);
         if (connected) {
           await bluetoothPrinterProvider.printCustomImage(Uint8List.fromList([27, 112, 0, 25, 250]));
           await bluetoothPrinterProvider.disconnect();
         }
       } catch (_) {}
    }
  }

  String _formatPrice(double price) {
    if (price % 1 == 0) {
      return price.toInt().toString();
    }
    return price.toStringAsFixed(2);
  }

  Future<void> printTestPage({required bool isReceipt}) async {
    final settings = await _repo.getSettings();
    final arabicFont = await _loadArabicFont();
    final pdf = pw.Document();

    final format = isReceipt 
      ? (settings.receiptPreset == ReceiptPreset.custom 
          ? PdfPageFormat(settings.customWidth * PdfPageFormat.mm, (settings.customHeight > 0 ? settings.customHeight : 100) * PdfPageFormat.mm, marginAll: settings.customMargin * PdfPageFormat.mm)
          : PdfPageFormat.roll80)
      : (settings.labelPreset == LabelPreset.custom
          ? PdfPageFormat(settings.customWidth * PdfPageFormat.mm, (settings.customHeight > 0 ? settings.customHeight : 40) * PdfPageFormat.mm, marginAll: settings.customMargin * PdfPageFormat.mm)
          : const PdfPageFormat(40 * PdfPageFormat.mm, 30 * PdfPageFormat.mm));

    pdf.addPage(
      pw.Page(
        pageFormat: format,
        theme: _createTheme(arabicFont),
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('صفحة اختبار الطباعة', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Text('العرض: ${format.width / PdfPageFormat.mm} mm'),
                pw.Text('الارتفاع: ${format.height / PdfPageFormat.mm} mm'),
                pw.Text('الحاشية: ${settings.customMargin} mm'),
                pw.SizedBox(height: 10),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: 'TEST123456',
                  width: format.availableWidth * 0.8,
                  height: 30,
                  textStyle: pw.TextStyle(font: arabicFont, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final bytes = await _saveWithRecovery(pdf);
    final printerId = isReceipt ? settings.receiptPrinterId : settings.labelPrinterId;
    await _printPdf(bytes, printerId, format: format, useDirectPrint: printerId != null && printerId.isNotEmpty, isLabel: !isReceipt);
  }

  Future<void> printShiftReport({
    required ShiftSessionModel shift,
    required double actualCash,
    required double expectedCash,
  }) async {
    final settings = await _repo.getSettings();
    final arabicFont = await _loadArabicFont();
    final pdf = pw.Document();
    final diff = actualCash - expectedCash;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('تقرير إغلاق الشفت', style: pw.TextStyle(font: arabicFont, fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.Divider(),
              pw.Text('الموظف: ${shift.staffName}', style: pw.TextStyle(font: arabicFont, fontSize: 12)),
              pw.Text('بداية الشفت: ${shift.startTime.toString().substring(0, 16)}', style: pw.TextStyle(font: arabicFont, fontSize: 12)),
              pw.Text('إغلاق الشفت: ${DateTime.now().toString().substring(0, 16)}', style: pw.TextStyle(font: arabicFont, fontSize: 12)),
              pw.SizedBox(height: 10),
              _row(arabicFont, 'الرصيد الافتتاحي:', '${shift.openingBalance.toStringAsFixed(0)}'),
              _row(arabicFont, 'المتوقع في الصندوق:', '${expectedCash.toStringAsFixed(0)}'),
              _row(arabicFont, 'الفعلي في الصندوق:', '${actualCash.toStringAsFixed(0)}'),
              pw.Divider(),
              _row(arabicFont, 'الفارق:', '${diff.toStringAsFixed(0)}', isBold: true),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('--- نهاية التقرير ---', style: pw.TextStyle(font: arabicFont, fontSize: 10))),
            ],
          ),
        ),
      ),
    );

    final bytes = await _saveWithRecovery(pdf);
    await _printPdf(bytes, settings.receiptPrinterId, format: PdfPageFormat.roll80, useDirectPrint: true);
  }

  Future<void> printFinancialReport({
    required BusinessReport report,
    required DateTime start,
    required DateTime end,
    String? staffName,
  }) async {
    final settings = await _repo.getSettings();
    final arabicFont = await _loadArabicFont();
    final pdf = pw.Document();
    final fmt = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (context) => pw.Directionality(
          textDirection: pw.TextDirection.rtl,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(child: pw.Text('تقرير مالي ملخص', style: pw.TextStyle(font: arabicFont, fontSize: 16, fontWeight: pw.FontWeight.bold))),
              pw.Center(child: pw.Text('${fmt.format(start)} - ${fmt.format(end)}', style: pw.TextStyle(font: arabicFont, fontSize: 10))),
              if (staffName != null) pw.Center(child: pw.Text('الموظف: $staffName', style: pw.TextStyle(font: arabicFont, fontSize: 10))),
              pw.Divider(),
              _row(arabicFont, 'إجمالي المبيعات:', '${report.totalSales.toStringAsFixed(0)}'),
              _row(arabicFont, 'عدد الفواتير:', '${report.salesCount}'),
              _row(arabicFont, 'مبيعات الأونلاين:', '${report.onlineSales.toStringAsFixed(0)}'),
              pw.Divider(),
              _row(arabicFont, 'إجمالي المشتريات:', '${report.totalPurchases.toStringAsFixed(0)}'),
              _row(arabicFont, 'إجمالي المصاريف:', '${report.totalExpenses.toStringAsFixed(0)}'),
              pw.Divider(),
              _row(arabicFont, 'صافي الربح:', '${report.netProfit.toStringAsFixed(0)}', isBold: true),
              pw.SizedBox(height: 10),
              pw.Text('المبيعات حسب التصنيف:', style: pw.TextStyle(font: arabicFont, fontSize: 10, fontWeight: pw.FontWeight.bold)),
              ...report.salesByCategory.entries.take(5).map((e) => _row(arabicFont, '- ${e.key}:', '${e.value.toStringAsFixed(0)}')),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('--- نهاية التقرير ---', style: pw.TextStyle(font: arabicFont, fontSize: 8))),
            ],
          ),
        ),
      ),
    );

    final bytes = await _saveWithRecovery(pdf);
    await _printPdf(bytes, settings.receiptPrinterId, format: PdfPageFormat.roll80, useDirectPrint: true);
  }

  pw.Widget _row(pw.Font font, String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11, fontWeight: isBold ? pw.FontWeight.bold : null)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 11, fontWeight: isBold ? pw.FontWeight.bold : null)),
        ],
      ),
    );
  }
}

final printingServiceProvider = Provider((ref) => PrintingService(ref.watch(printerSettingsRepositoryProvider)));
