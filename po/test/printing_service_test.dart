import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:barcode/barcode.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Test Arabic font and Barcode PDF generation', () async {
    // 1. Try to load the font from assets
    final fontData = await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    expect(fontData, isNotNull);
    print('Font data size: ${fontData.lengthInBytes}');

    final arabicFont = pw.Font.ttf(fontData);
    expect(arabicFont, isNotNull);

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFont,
        ),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              children: [
                pw.Text('تجربة طباعة باللغة العربية'),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.code128(),
                  data: 'INV-12345',
                  width: 100,
                  height: 30,
                ),
              ],
            ),
          );
        },
      ),
    );

    // Save the PDF
    final bytes = await pdf.save();
    print('PDF bytes size: ${bytes.length}');
    expect(bytes, isNotEmpty);
  });
}
