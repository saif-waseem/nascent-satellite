import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_models/shared_models.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/settings_provider.dart';

class CarContractPrintPreview extends ConsumerWidget {
  final CarContractModel contract;
  const CarContractPrintPreview({super.key, required this.contract});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final date = contract.createdAt;
    final dateStr = '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final serial = contract.id.length > 6 ? contract.id.substring(contract.id.length - 6) : contract.id;
    
    String formatNumber(double num) {
      return num.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    }

    const tblBorder = TableBorder.symmetric(
      inside: BorderSide(color: Colors.black, width: 0.5),
      outside: BorderSide(color: Colors.black, width: 1),
    );

    Widget tblHeader(String text) => Container(
          color: const Color(0xFFeeeeee),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        );

    Widget tblCell(String text, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color, fontFamily: 'Cairo')),
        );

    Widget secTitle(String title) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontFamily: 'Cairo')),
        );

    Future<void> _printDocument() async {
      final font = await PdfGoogleFonts.cairoRegular();
      final fontBold = await PdfGoogleFonts.cairoBold();

      pw.ImageProvider? logoImage;
      if (settings.logoImagePath != null && File(settings.logoImagePath!).existsSync()) {
        logoImage = pw.MemoryImage(File(settings.logoImagePath!).readAsBytesSync());
      }

      pw.Widget pdfTblHeader(String text) => pw.Container(
            color: PdfColors.grey300,
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(text, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: fontBold, fontSize: 10)),
          );

      pw.Widget pdfTblCell(String text, {bool bold = false, PdfColor? color}) => pw.Padding(
            padding: const pw.EdgeInsets.all(4),
            child: pw.Text(text, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: bold ? fontBold : font, fontSize: 10, color: color)),
          );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async {
          final pdf = pw.Document();
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              theme: pw.ThemeData.withFont(base: font, bold: fontBold),
              textDirection: pw.TextDirection.rtl,
              margin: const pw.EdgeInsets.all(30),
              build: (pw.Context context) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(settings.officeName, style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.red800)),
                            pw.Text('لاستيراد وتسجيل السيارات', style: pw.TextStyle(font: font, fontSize: 10)),
                            pw.Text('عقود مرورية - مكاتبات', style: pw.TextStyle(font: font, fontSize: 10)),
                            if (settings.managerName.isNotEmpty)
                              pw.Text('بإدارة: ${settings.managerName}', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                          ],
                        ),
                        if (logoImage != null)
                          pw.Image(logoImage, height: 60, width: 80, fit: pw.BoxFit.contain)
                        else
                          pw.SizedBox(width: 80),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (settings.licenseNumber.isNotEmpty) pw.Text('رقم الإجازة: ${settings.licenseNumber}', style: pw.TextStyle(font: font, fontSize: 10)),
                            if (settings.officeAddress.isNotEmpty) pw.Text('العنوان: ${settings.officeAddress}', style: pw.TextStyle(font: font, fontSize: 10)),
                            if (settings.phone.isNotEmpty) pw.Text('هاتف: ${settings.phone}', style: pw.TextStyle(font: font, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Divider(color: PdfColor.fromHex('#d4af37'), thickness: 2),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('التسلسل: $serial', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                        pw.Text('تاريخ: $dateStr', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                        pw.Text('الوقت: $timeStr', style: pw.TextStyle(font: fontBold, fontSize: 10)),
                      ],
                    ),
                    pw.SizedBox(height: 12),

                    pw.Text('معلومات البائع', style: pw.TextStyle(font: fontBold, fontSize: 12, decoration: pw.TextDecoration.underline)),
                    pw.SizedBox(height: 4),
                    pw.Table(border: pw.TableBorder.all(width: 0.5), children: [
                      pw.TableRow(children: [pdfTblHeader('الاسم الثلاثي واللقب'), pdfTblHeader('السكن'), pdfTblHeader('رقم الهوية'), pdfTblHeader('رقم الهاتف'), pdfTblHeader('اسم المختار')]),
                      pw.TableRow(children: [pdfTblCell(contract.sellerName), pdfTblCell(contract.sellerAddress ?? ''), pdfTblCell(contract.sellerId ?? ''), pdfTblCell(contract.sellerPhone ?? ''), pdfTblCell(contract.sellerMukhtar ?? 'يجهل اسمه')]),
                    ]),
                    pw.SizedBox(height: 10),

                    pw.Text('معلومات المشتري', style: pw.TextStyle(font: fontBold, fontSize: 12, decoration: pw.TextDecoration.underline)),
                    pw.SizedBox(height: 4),
                    pw.Table(border: pw.TableBorder.all(width: 0.5), children: [
                      pw.TableRow(children: [pdfTblHeader('الاسم الثلاثي واللقب'), pdfTblHeader('السكن'), pdfTblHeader('رقم الهوية'), pdfTblHeader('رقم الهاتف'), pdfTblHeader('اسم المختار')]),
                      pw.TableRow(children: [pdfTblCell(contract.buyerName), pdfTblCell(contract.buyerAddress ?? ''), pdfTblCell(contract.buyerId ?? ''), pdfTblCell(contract.buyerPhone ?? ''), pdfTblCell(contract.buyerMukhtar ?? 'يجهل اسمه')]),
                    ]),
                    pw.SizedBox(height: 12),

                    pw.Center(child: pw.Text('عقد هذا الاتفاق بين الطرفين كما يلي: باع الطرف الاول للطرف الثاني السيارة المفصلة أدناه:', style: pw.TextStyle(font: fontBold, fontSize: 11))),
                    pw.SizedBox(height: 6),

                    pw.Table(border: pw.TableBorder.all(width: 0.5), children: [
                      pw.TableRow(children: [pdfTblHeader('تصنيف السيارة'), pdfTblHeader('اسم السيارة'), pdfTblHeader('رقم اللوحة'), pdfTblHeader('الموديل'), pdfTblHeader('اللون'), pdfTblHeader('رقم الشاصي')]),
                      pw.TableRow(children: [pdfTblCell(contract.carType, bold: true), pdfTblCell(contract.carModelName), pdfTblCell(contract.carPlate ?? 'غير مسجل'), pdfTblCell(contract.carYear ?? ''), pdfTblCell(contract.carColor ?? ''), pdfTblCell(contract.carChassis ?? 'بلا')]),
                    ]),
                    pw.SizedBox(height: 8),

                    pw.Center(
                      child: pw.Container(
                        width: 350,
                        child: pw.Table(border: pw.TableBorder.all(width: 0.5), children: [
                          pw.TableRow(children: [pdfTblHeader('سعر البيع الكلي'), pdfTblHeader('المبلغ الواصل (المدفوع)'), pdfTblHeader('المتبقي بذمة المشتري')]),
                          pw.TableRow(children: [pdfTblCell(formatNumber(contract.priceTotal), bold: true), pdfTblCell(formatNumber(contract.pricePaid), bold: true), pdfTblCell(formatNumber(contract.priceRemaining), bold: true, color: PdfColors.red)]),
                        ]),
                      ),
                    ),
                    pw.SizedBox(height: 12),

                    pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text('الملاحظات: ${contract.notes?.isNotEmpty == true ? contract.notes : 'لا يوجد'}', style: pw.TextStyle(font: font, fontSize: 9)),
                        pw.SizedBox(height: 4),
                        pw.Text('تنبيه وإخلاء مسؤولية: المكتب غير مسؤول عن إبراز المستمسكات المزورة للطرفين أن وجد ذلك لأن الطرفان متعارفان ومتفقان خارج المكتب والمكتب وسيط وليس كفيل. يتعهد الطرفان بصحة المعلومات أعلاه.', style: pw.TextStyle(font: font, fontSize: 9)),
                      ]),
                    ),
                    pw.SizedBox(height: 40),

                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(children: [pw.Text('توقيع وبصمة البائع', style: pw.TextStyle(font: fontBold, fontSize: 11)), pw.SizedBox(height: 40), pw.Text(contract.sellerName, style: pw.TextStyle(font: font, fontSize: 10))]),
                        pw.Column(children: [pw.Text('إدارة المكتب', style: pw.TextStyle(font: fontBold, fontSize: 11)), pw.SizedBox(height: 40), pw.Text(settings.managerName.isNotEmpty ? settings.managerName : settings.officeName, style: pw.TextStyle(font: font, fontSize: 10))]),
                        pw.Column(children: [pw.Text('توقيع وبصمة المشتري', style: pw.TextStyle(font: fontBold, fontSize: 11)), pw.SizedBox(height: 40), pw.Text(contract.buyerName, style: pw.TextStyle(font: font, fontSize: 10))]),
                      ],
                    ),
                    pw.SizedBox(height: 20),
                    pw.Divider(color: PdfColors.black, thickness: 1),
                    pw.Center(child: pw.Text('تم الإنشاء بواسطة المهندس سيف وسيم', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600))),
                  ],
                );
              },
            ),
          );
          return pdf.save();
        },
      );
    }

    final printContent = Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──────────────────────────────────────────────
            Table(
              children: [
                TableRow(children: [
                  // Office Info (right)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(settings.officeName, style: GoogleFonts.amiri(fontSize: 18, color: const Color(0xFFc62828), fontWeight: FontWeight.bold)),
                      const Text('لاستيراد وتسجيل السيارات', style: TextStyle(fontSize: 10, fontFamily: 'Cairo')),
                      const Text('عقود مرورية - مكاتبات', style: TextStyle(fontSize: 10, fontFamily: 'Cairo')),
                      if (settings.managerName.isNotEmpty)
                        Text('بإدارة: ${settings.managerName}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    ]),
                  ),
                  // Logo (center)
                  Center(
                    child: settings.logoImagePath != null && File(settings.logoImagePath!).existsSync()
                        ? Image.file(File(settings.logoImagePath!), height: 70, width: 100, fit: BoxFit.contain)
                        : const Text('🚗', style: TextStyle(fontSize: 40)),
                  ),
                  // Contact (left)
                  Align(
                    alignment: Alignment.topLeft,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (settings.licenseNumber.isNotEmpty) Text('رقم الإجازة: ${settings.licenseNumber}', style: const TextStyle(fontSize: 10, fontFamily: 'Cairo')),
                      if (settings.officeAddress.isNotEmpty) Text('العنوان: ${settings.officeAddress}', style: const TextStyle(fontSize: 10, fontFamily: 'Cairo')),
                      if (settings.phone.isNotEmpty) Text('هاتف: ${settings.phone}', style: const TextStyle(fontSize: 10, fontFamily: 'Cairo')),
                    ]),
                  ),
                ]),
              ],
            ),
            const Divider(color: AppColors.gold, thickness: 2),
            // Serial / Date / Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('التسلسل: $serial', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                Text('تاريخ: $dateStr', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                Text('الوقت: $timeStr', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ],
            ),
            const SizedBox(height: 8),
            // ── SELLER TABLE ────────────────────────────────────────
            secTitle('معلومات البائع'),
            Table(border: tblBorder, columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1.5), 3: FlexColumnWidth(1.5), 4: FlexColumnWidth(1.5)}, children: [
              TableRow(children: [tblHeader('الاسم الثلاثي واللقب'), tblHeader('السكن'), tblHeader('رقم الهوية'), tblHeader('رقم الهاتف'), tblHeader('اسم المختار')]),
              TableRow(children: [tblCell(contract.sellerName), tblCell(contract.sellerAddress ?? ''), tblCell(contract.sellerId ?? ''), tblCell(contract.sellerPhone ?? ''), tblCell(contract.sellerMukhtar ?? 'يجهل اسمه')]),
            ]),
            // Seller Photo
            if (contract.sellerPhotoUrl != null && File(contract.sellerPhotoUrl!).existsSync())
              Padding(padding: const EdgeInsets.only(top: 4), child: Image.file(File(contract.sellerPhotoUrl!), width: 60, height: 60, fit: BoxFit.cover)),
            const SizedBox(height: 8),
            // ── BUYER TABLE ─────────────────────────────────────────
            secTitle('معلومات المشتري'),
            Table(border: tblBorder, columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1.5), 3: FlexColumnWidth(1.5), 4: FlexColumnWidth(1.5)}, children: [
              TableRow(children: [tblHeader('الاسم الثلاثي واللقب'), tblHeader('السكن'), tblHeader('رقم الهوية'), tblHeader('رقم الهاتف'), tblHeader('اسم المختار')]),
              TableRow(children: [tblCell(contract.buyerName), tblCell(contract.buyerAddress ?? ''), tblCell(contract.buyerId ?? ''), tblCell(contract.buyerPhone ?? ''), tblCell(contract.buyerMukhtar ?? 'يجهل اسمه')]),
            ]),
            // Buyer Photo
            if (contract.buyerPhotoUrl != null && File(contract.buyerPhotoUrl!).existsSync())
              Padding(padding: const EdgeInsets.only(top: 4), child: Image.file(File(contract.buyerPhotoUrl!), width: 60, height: 60, fit: BoxFit.cover)),
            const SizedBox(height: 10),
            // Contract Text
            Center(
              child: Text(
                'عقد هذا الاتفاق بين الطرفين كما يلي: باع الطرف الاول للطرف الثاني السيارة المفصلة أدناه:',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
            ),
            const SizedBox(height: 6),
            // ── CAR TABLE ───────────────────────────────────────────
            Table(border: tblBorder, children: [
              TableRow(children: [tblHeader('تصنيف السيارة'), tblHeader('اسم السيارة'), tblHeader('رقم اللوحة'), tblHeader('الموديل'), tblHeader('اللون'), tblHeader('رقم الشاصي')]),
              TableRow(children: [
                tblCell(contract.carType, bold: true),
                tblCell(contract.carModelName),
                tblCell(contract.carPlate ?? 'غير مسجل'),
                tblCell(contract.carYear ?? ''),
                tblCell(contract.carColor ?? ''),
                tblCell(contract.carChassis ?? 'بلا'),
              ]),
            ]),
            const SizedBox(height: 6),
            // ── PRICE TABLE ─────────────────────────────────────────
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.65,
                child: Table(border: tblBorder, children: [
                  TableRow(children: [tblHeader('سعر البيع الكلي'), tblHeader('المبلغ الواصل (المدفوع)'), tblHeader('المتبقي بذمة المشتري')]),
                  TableRow(children: [
                    tblCell(formatNumber(contract.priceTotal), bold: true),
                    tblCell(formatNumber(contract.pricePaid), bold: true),
                    tblCell(formatNumber(contract.priceRemaining), bold: true, color: Colors.red),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            // Notes + Disclaimer
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(4)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الملاحظات: ${contract.notes?.isNotEmpty == true ? contract.notes : 'لا يوجد'}', style: const TextStyle(fontSize: 9, fontFamily: 'Cairo')),
                const SizedBox(height: 4),
                const Text(
                  'تنبيه وإخلاء مسؤولية: المكتب غير مسؤول عن إبراز المستمسكات المزورة للطرفين أن وجد ذلك لأن الطرفان متعارفان ومتفقان خارج المكتب والمكتب وسيط وليس كفيل. يتعهد الطرفان بصحة المعلومات أعلاه.',
                  style: TextStyle(fontSize: 9, fontFamily: 'Cairo'),
                ),
              ]),
            ),
            const SizedBox(height: 28),
            // ── SIGNATURES ──────────────────────────────────────────
            Row(
              children: [
                Expanded(child: Column(children: [
                  const Divider(color: Colors.black, thickness: 1),
                  const SizedBox(height: 4),
                  const Text('توقيع وبصمة البائع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                  Text(contract.sellerName, style: const TextStyle(fontSize: 10, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                ])),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [
                  const Divider(color: Colors.black, thickness: 1),
                  const SizedBox(height: 4),
                  const Text('إدارة المكتب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                  Text(settings.managerName.isNotEmpty ? settings.managerName : settings.officeName, style: const TextStyle(fontSize: 10, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                ])),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [
                  const Divider(color: Colors.black, thickness: 1),
                  const SizedBox(height: 4),
                  const Text('توقيع وبصمة المشتري', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                  Text(contract.buyerName, style: const TextStyle(fontSize: 10, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                ])),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.black),
            const Center(child: Text('تم الإنشاء بواسطة المهندس سيف وسيم', style: TextStyle(fontSize: 9, fontFamily: 'Cairo', color: Colors.black54))),
          ],
        ),
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFf0f0f0),
        appBar: AppBar(
          title: Text('معاينة العقد - ${contract.carModelName}', style: GoogleFonts.amiri()),
          backgroundColor: AppColors.lapis,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'طباعة',
              onPressed: _printDocument,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(elevation: 4, child: printContent),
        ),
      ),
    );
  }
}

