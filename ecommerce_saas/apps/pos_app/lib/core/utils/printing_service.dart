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

class PrintingService {
  final PrinterSettingsRepository _repo;
  static pw.Font? _cachedArabicFont;

  PrintingService(this._repo);

  Future<pw.Font> _loadArabicFont({bool forceUpdate = false}) async {
    if (_cachedArabicFont != null && !forceUpdate) return _cachedArabicFont!;

    try {
      _cachedArabicFont = await PdfGoogleFonts.amiriRegular();
      return _cachedArabicFont!;
    } catch (e) {
      debugPrint('Google Fonts Amiri failed: $e');
    }

    try {
      _cachedArabicFont = await PdfGoogleFonts.cairoRegular();
      return _cachedArabicFont!;
    } catch (e) {
      debugPrint('Google Fonts Cairo failed: $e');
    }

    try {
      final fontData = await rootBundle.load("assets/fonts/Cairo-Regular.ttf");
      _cachedArabicFont = pw.Font.ttf(fontData);
      return _cachedArabicFont!;
    } catch (e) {
      debugPrint('Asset bundle font load failed: $e');
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
    
    // Determine Page Format based on preset
    final PdfPageFormat pageFormat;
    final bool isA4;
    
    switch (settings.receiptPreset) {
      case ReceiptPreset.a4:
        pageFormat = PdfPageFormat.a4;
        isA4 = true;
        break;
      case ReceiptPreset.thermal58:
        pageFormat = PdfPageFormat.roll57;
        isA4 = false;
        break;
      case ReceiptPreset.thermal80:
      default:
        pageFormat = PdfPageFormat.roll80;
        isA4 = false;
        break;
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
                          if (item.variantColor != null || item.variantSize != null) {
                            itemName += ' (${item.variantColor ?? ''} ${item.variantSize ?? ''})';
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

    await _printPdf(pdf, settings.receiptPrinterId, format: pageFormat, useDirectPrint: useDirectPrint);
  }

  Future<void> printBarcodeLabel({
    required String name,
    required String barcode,
    required double price,
    required String currency,
    String? category,
  }) async {
    final settings = await _repo.getSettings();
    final arabicFont = await _loadArabicFont();
    final pdf = pw.Document();

    final PdfPageFormat pageFormat;
    final double barcodeWidth;
    final double barcodeHeight;
    final double fontSize;

    switch (settings.labelPreset) {
      case LabelPreset.jewelry3020:
        pageFormat = const PdfPageFormat(30 * PdfPageFormat.mm, 20 * PdfPageFormat.mm, marginAll: 1 * PdfPageFormat.mm);
        barcodeWidth = 25 * PdfPageFormat.mm;
        barcodeHeight = 6 * PdfPageFormat.mm;
        fontSize = 7;
        break;
      case LabelPreset.shipping100150:
        pageFormat = const PdfPageFormat(100 * PdfPageFormat.mm, 150 * PdfPageFormat.mm, marginAll: 5 * PdfPageFormat.mm);
        barcodeWidth = 80 * PdfPageFormat.mm;
        barcodeHeight = 30 * PdfPageFormat.mm;
        fontSize = 18;
        break;
      case LabelPreset.standard4030:
      default:
        pageFormat = const PdfPageFormat(40 * PdfPageFormat.mm, 30 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm);
        barcodeWidth = 35 * PdfPageFormat.mm;
        barcodeHeight = 10 * PdfPageFormat.mm;
        fontSize = 10;
        break;
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: _createTheme(arabicFont),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Center(
              child: pw.Column(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                   pw.Text(name.trim().isEmpty ? 'غير مصنف' : name, style: pw.TextStyle(fontSize: fontSize, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center, maxLines: 2),
                   if (category != null && category.trim().isNotEmpty) ...[
                     pw.SizedBox(height: 1),
                     pw.Text(category, style: pw.TextStyle(fontSize: fontSize * 0.7, color: PdfColors.grey700)),
                   ],
                  pw.SizedBox(height: 2),
                  pw.BarcodeWidget(
                    barcode: pw.Barcode.code128(),
                    data: barcode,
                    width: barcodeWidth,
                    height: barcodeHeight,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 2),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('${_formatPrice(price)} $currency', style: pw.TextStyle(fontSize: fontSize * 0.9, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );

    await _printPdf(pdf, settings.labelPrinterId, format: pageFormat, useDirectPrint: settings.labelPrinterId != null);
  }

  Future<void> printPurchaseInvoice(PurchaseInvoiceModel invoice) async {
    final settings = await _repo.getSettings();
    final arabicFont = await _loadArabicFont();
    
    final PdfPageFormat pageFormat;
    final bool isA4;
    
    switch (settings.receiptPreset) {
      case ReceiptPreset.a4:
        pageFormat = PdfPageFormat.a4;
        isA4 = true;
        break;
      case ReceiptPreset.thermal58:
        pageFormat = PdfPageFormat.roll57;
        isA4 = false;
        break;
      case ReceiptPreset.thermal80:
      default:
        pageFormat = PdfPageFormat.roll80;
        isA4 = false;
        break;
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

    await _printPdf(pdf, settings.receiptPrinterId, format: pageFormat, useDirectPrint: settings.receiptPrinterId != null);
  }

  Future<void> _printPdf(pw.Document pdf, String? printerName, {PdfPageFormat? format, bool useDirectPrint = false}) async {
    final effectiveFormat = format ?? PdfPageFormat.roll80;
    
    Future<Uint8List> _saveWithRecovery() async {
      try {
        return await pdf.save();
      } catch (e) {
        if (e.toString().contains('UTF-8')) {
          _cachedArabicFont = null;
        }
        rethrow;
      }
    }

    if (useDirectPrint && printerName != null && printerName.isNotEmpty) {
      try {
        await Printing.directPrintPdf(
          printer: Printer(url: printerName),
          onLayout: (PdfPageFormat f) async => await _saveWithRecovery(),
        );
        return;
      } catch (e) {
        debugPrint('Direct print failed: $e');
      }
    }

    await Printing.layoutPdf(
      format: effectiveFormat,
      onLayout: (PdfPageFormat f) async => await _saveWithRecovery(),
      name: 'وصل',
    );
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
    }
  }

  String _formatPrice(double price) {
    if (price % 1 == 0) {
      return price.toInt().toString();
    }
    return price.toStringAsFixed(2);
  }
}

final printingServiceProvider = Provider((ref) => PrintingService(ref.watch(printerSettingsRepositoryProvider)));
