import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'tspl_generator.dart';
import 'package:image/image.dart' as img;


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
    await printAllBarcodeLabels(
      items: [(name: name, barcode: barcode, price: price, count: count)],
      currency: currency,
      showName: showName,
      showPrice: showPrice,
      showBarcodeText: showBarcodeText,
    );
  }

  Future<void> printAllBarcodeLabels({
    required List<({String name, String barcode, double price, int count})> items,
    required String currency,
    bool showName = true,
    bool showPrice = true,
    bool showBarcodeText = true,
  }) async {
    final settings = await _repo.getSettings();
    final printerName = settings.labelPrinterId;
    
    if (settings.labelProtocol == LabelPrinterProtocol.tspl) {
      await _printRawTspl(items, printerName, currency, showName, showPrice, showBarcodeText, settings);
    } else {
      await _printWithPackage(items, printerName, currency, showName, showPrice, showBarcodeText, settings);
    }
  }

  Future<void> _printRawTspl(
    List<({String name, String barcode, double price, int count})> items,
    String? printerName,
    String currency,
    bool showName,
    bool showPrice,
    bool showBarcodeText,
    PrinterSettings settings,
  ) async {
    final pageW = settings.customWidth > 0 ? settings.customWidth.toDouble() : 40.0;
    final pageH = settings.customHeight > 0 ? settings.customHeight.toDouble() : 30.0;

    final batch = <int>[];
    
    // تم إزالة أوامر SIZE و GAP و DIRECTION. 
    // إرسالها برمجياً قد يلغي معايرة الطابعة الداخلية ويتسبب في تخطي ملصقات.
    // يجب الاعتماد على معايرة حساس الطابعة الفيزيائي.

    for (final item in items) {
      for (int i = 0; i < item.count; i++) {
        batch.addAll(await buildOneLabel(
          name: showName ? item.name : '',
          price: showPrice ? _formatPrice(item.price) : '',
          barcode: item.barcode,
          currency: currency,
          widthMm: pageW,
          heightMm: pageH,
        ));
      }
    }

    if (batch.isEmpty) return;
    
    final useBluetooth = settings.useBluetoothForLabels;
    final bluetoothMac = settings.bluetoothLabelPrinterMac;

    if (useBluetooth && bluetoothMac != null) {
       try {
         final connected = await bluetoothPrinterProvider.connect(bluetoothMac);
         if (connected) {
           await bluetoothPrinterProvider.printCustomImage(Uint8List.fromList(batch));
           await bluetoothPrinterProvider.disconnect();
         }
       } catch (e) {
          debugPrint('Bluetooth raw print error: $e');
       }
       return;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows && printerName != null && printerName.isNotEmpty) {
      try {
        await WindowsPrinter.printRawData(
          printerName: printerName,
          data: Uint8List.fromList(batch),
          useRawDatatype: true,
        );
      } catch (e) {
        debugPrint('Raw TSPL printing failed: $e');
      }
    }
  }

  Future<void> _printWithPackage(
    List<({String name, String barcode, double price, int count})> items,
    String? printerName,
    String currency,
    bool showName,
    bool showPrice,
    bool showBarcodeText,
    PrinterSettings settings,
  ) async {
    final arabicFont = await _loadArabicFont();
    final pdf = pw.Document();

    final pageW = settings.customWidth > 0 ? settings.customWidth.toDouble() : 40.0;
    final pageH = settings.customHeight > 0 ? settings.customHeight.toDouble() : 30.0;

    // مقاس الصفحة الفعلي (يجب أن يتطابق مع الويندوز)
    final customPageFormat = PdfPageFormat(
      pageW * PdfPageFormat.mm, 
      pageH * PdfPageFormat.mm, 
      marginAll: 0,
    );
    
    for (final item in items) {
      for (int i = 0; i < item.count; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: customPageFormat,
            theme: _createTheme(arabicFont),
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Center(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.all(1),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (showName && item.name.isNotEmpty)
                          pw.Text(
                            item.name.trim().isEmpty ? 'غير مصنف' : item.name.trim(),
                            style: pw.TextStyle(font: arabicFont, fontSize: 8),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                          )
                        else
                          pw.SizedBox(height: 1),

                        pw.Container(
                          height: 28,
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.code128(),
                            data: item.barcode,
                            drawText: showBarcodeText,
                            textStyle: pw.TextStyle(font: arabicFont, fontSize: 7, fontWeight: pw.FontWeight.bold),
                          ),
                        ),

                        if (showPrice)
                          pw.Text(
                            '${_formatPrice(item.price)} $currency',
                            style: pw.TextStyle(font: arabicFont, fontSize: 9, fontWeight: pw.FontWeight.bold),
                          )
                        else
                          pw.SizedBox(height: 1),
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

    if (pdf.document.pdfPageList.pages.isNotEmpty) {
      final Uint8List pdfBytes = await _saveWithRecovery(pdf);
      
      await _printPdf(
        pdfBytes, 
        printerName, 
        format: customPageFormat, 
        useDirectPrint: printerName != null && printerName.isNotEmpty, 
        isLabel: true,
        usePrinterSettings: false, // إجبار الويندوز على مقاس الكود لمنع الفراغات
        dynamicLayout: false,
      );
    }
  }

  Future<void> printBlankLabelTest({required double heightMm}) async {
    final settings = await _repo.getSettings();
    final printerName = settings.labelPrinterId;
    
    if (settings.labelProtocol == LabelPrinterProtocol.tspl) {
      final items = [
        for (int i = 0; i < 3; i++)
          (name: 'Test ${i + 1}', barcode: '12345678', price: 0.0, count: 1)
      ];
      await _printRawTspl(items, printerName, '', true, false, false, settings);
      return;
    }

    // العرض يبقى ثابتاً بناءً على إعداداتك الفعالية أو القيمة الافتراضية 40
    final double rawW = settings.customWidth > 0 ? settings.customWidth : 40.0;

    // تحويل المقاسات إلى نقاط الطباعة الخاصة بـ PdfPageFormat
    final double exactWidth = rawW * PdfPageFormat.mm;
    final double exactHeight = heightMm * PdfPageFormat.mm;
    
    final customPageFormat = PdfPageFormat(exactWidth, exactHeight, marginAll: 0);

    final doc = pw.Document();
    
    // نفس الكود السابق الخاص بك تماماً لبناء الصفحات (على سبيل المثال الـ 3 صفحات)
    for (int i = 0; i < 3; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: customPageFormat,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Text("Test ${i + 1}", style: pw.TextStyle(fontSize: 10)),
            );
          },
        ),
      );
    }

    // أمر الطباعة الفعلي
    if (doc.document.pdfPageList.pages.isNotEmpty && printerName != null && printerName.isNotEmpty) {
      Printer? printer;
      try {
        final printers = await Printing.listPrinters();
        printer = printers.firstWhere(
            (p) => p.name == printerName || p.url == printerName);
      } catch (_) {
        printer = Printer(url: printerName, name: printerName);
      }
      
      final bytes = await doc.save();
      await Printing.directPrintPdf(
        printer: printer, 
        format: customPageFormat, 
        usePrinterSettings: false, // لضمان تمرير الارتفاع المخصص من الكود للويندوز
        dynamicLayout: false, 
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } else {
      final bytes = await doc.save();
      await Printing.layoutPdf(onLayout: (_) async => bytes, format: customPageFormat);
    }
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

  Future<void> _printPdf(Uint8List pdfBytes, String? printerName, {PdfPageFormat? format, bool useDirectPrint = false, bool isLabel = false, bool usePrinterSettings = false, bool dynamicLayout = true}) async {
    final settings = await _repo.getSettings();
    final effectiveFormat = format ?? PdfPageFormat.roll80;

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
          usePrinterSettings: usePrinterSettings,
          dynamicLayout: dynamicLayout,
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
      debugPrint('Failed to save PDF: $e');
      // Create empty fallback
      final empty = pw.Document();
      empty.addPage(pw.Page(build: (context) => pw.Center(child: pw.Text('Error generating PDF'))));
      return await empty.save();
    }
  }

  List<int> _buildEscPosImageBytes(img.Image image) {
    final gray = img.grayscale(image);
    final width = gray.width;
    final height = gray.height;
    final bytesPerLine = (width + 7) ~/ 8;
    final bytes = <int>[];
    
    // GS v 0 - Raster bit image command
    bytes.addAll([
      0x1D, 0x76, 0x30, 0x00,
      bytesPerLine & 0xFF,
      (bytesPerLine >> 8) & 0xFF,
      height & 0xFF,
      (height >> 8) & 0xFF,
    ]);
    
    for (int y = 0; y < height; y++) {
      for (int xb = 0; xb < bytesPerLine; xb++) {
        int byteVal = 0;
        for (int bit = 0; bit < 8; bit++) {
          final x = xb * 8 + bit;
          if (x < width) {
            final pixel = gray.getPixel(x, y);
            if (pixel.luminanceNormalized < 0.5) {
              byteVal |= (0x80 >> bit);
            }
          }
        }
        bytes.add(byteVal);
      }
    }
    return bytes;
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
