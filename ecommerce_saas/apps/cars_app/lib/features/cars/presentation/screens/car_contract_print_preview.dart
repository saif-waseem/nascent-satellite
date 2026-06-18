import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_models/shared_models.dart';
import 'package:intl/intl.dart';

class CarContractPrintPreview extends StatelessWidget {
  final CarContractModel contract;

  const CarContractPrintPreview({super.key, required this.contract});

  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttf),
        build: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(24),
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 2, color: PdfColors.black)),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('عقد بيع وشراء مركبة', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('التاريخ: ${DateFormat('yyyy/MM/dd').format(contract.createdAt)}'),
                pw.SizedBox(height: 24),
                
                // Seller & Buyer info
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('الطرف الأول (البائع)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                            pw.Divider(),
                            pw.Text('الاسم: ${contract.sellerName}'),
                            if (contract.sellerId?.isNotEmpty == true) pw.Text('الهوية: ${contract.sellerId}'),
                            if (contract.sellerAddress?.isNotEmpty == true) pw.Text('السكن: ${contract.sellerAddress}'),
                            if (contract.sellerPhone?.isNotEmpty == true) pw.Text('الهاتف: ${contract.sellerPhone}'),
                            if (contract.sellerMukhtar?.isNotEmpty == true) pw.Text('المختار: ${contract.sellerMukhtar}'),
                          ],
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 16),
                    pw.Expanded(
                      child: pw.Container(
                        padding: const pw.EdgeInsets.all(8),
                        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('الطرف الثاني (المشتري)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            pw.Divider(),
                            pw.Text('الاسم: ${contract.buyerName}'),
                            if (contract.buyerId?.isNotEmpty == true) pw.Text('الهوية: ${contract.buyerId}'),
                            if (contract.buyerAddress?.isNotEmpty == true) pw.Text('السكن: ${contract.buyerAddress}'),
                            if (contract.buyerPhone?.isNotEmpty == true) pw.Text('الهاتف: ${contract.buyerPhone}'),
                            if (contract.buyerMukhtar?.isNotEmpty == true) pw.Text('المختار: ${contract.buyerMukhtar}'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 24),

                // Car info
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('تفاصيل المركبة', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('النوع: ${contract.carType}'),
                          pw.Text('الموديل: ${contract.carModelName}'),
                          pw.Text('السنة: ${contract.carYear ?? "-"}'),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('رقم اللوحة: ${contract.carPlate ?? "-"}'),
                          pw.Text('اللون: ${contract.carColor ?? "-"}'),
                          pw.Text('رقم الشاصي: ${contract.carChassis ?? "-"}'),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),

                // Financials
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('التفاصيل المالية', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Divider(),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('مبلغ البيع الكلي: ${contract.priceTotal} د.ع'),
                          pw.Text('المبلغ المقبوض: ${contract.pricePaid} د.ع'),
                          pw.Text('المبلغ المتبقي: ${contract.priceRemaining} د.ع', style: pw.TextStyle(color: PdfColors.red900, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                if (contract.notes?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 16),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ملاحظات إضافية', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Divider(),
                        pw.Text(contract.notes!),
                      ]
                    )
                  )
                ],

                pw.Spacer(),
                
                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text('توقيع البائع', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 40),
                        pw.Text('......................'),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text('توقيع المشتري', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 40),
                        pw.Text('......................'),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طباعة العقد')),
      body: PdfPreview(
        build: _generatePdf,
        initialPageFormat: PdfPageFormat.a4,
        allowSharing: true,
        allowPrinting: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: 'contract_${contract.id}.pdf',
      ),
    );
  }
}
