import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:typed_data';
import 'dart:convert';

/// يحوّل widget إلى صورة نقطية (RGBA) بأبعاد محددة بالبكسل.
Future<ui.Image> widgetToImage(
  Widget widget, {
  required double widthPx,
  required double heightPx,
}) async {
  final repaintBoundary = RenderRepaintBoundary();
  final platformDispatcher = WidgetsBinding.instance.platformDispatcher;

  final renderView = RenderView(
    view: platformDispatcher.views.first,
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(Size(widthPx, heightPx)),
      devicePixelRatio: 1.0,
    ),
    child: RenderPositionedBox(
      alignment: Alignment.center,
      child: repaintBoundary,
    ),
  );

  final pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();

  final buildOwner = BuildOwner(focusManager: FocusManager());
  final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
    container: repaintBoundary,
    child: Directionality(
      textDirection: TextDirection.rtl, // مهم للعربية
      child: SizedBox(
        width: widthPx,
        height: heightPx,
        child: widget,
      ),
    ),
  ).attachToRenderTree(buildOwner);

  buildOwner
    ..buildScope(rootElement)
    ..finalizeTree();

  pipelineOwner
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();

  return repaintBoundary.toImage(pixelRatio: 1.0);
}

/// يبني أمر BITMAP من صورة. يعيد قائمة بايتات جاهزة للإرسال الخام.
Future<List<int>> imageToTsplBitmap(
  ui.Image image, {
  int x = 0,
  int y = 0,
  int threshold = 128, // عتبة التحويل لأبيض/أسود
}) async {
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final pixels = byteData!.buffer.asUint8List();

  final width = image.width;
  final height = image.height;
  final widthBytes = (width + 7) ~/ 8; // تقريب لأعلى لأقرب مضاعف 8

  // 0xFF = كل البتات بيضاء (لا طباعة) كقيمة ابتدائية
  final bitmap = Uint8List(widthBytes * height)
    ..fillRange(0, widthBytes * height, 0xFF);

  for (int row = 0; row < height; row++) {
    for (int col = 0; col < width; col++) {
      final pixelIndex = (row * width + col) * 4;
      final r = pixels[pixelIndex];
      final g = pixels[pixelIndex + 1];
      final b = pixels[pixelIndex + 2];
      final a = pixels[pixelIndex + 3];

      // معالجة الشفافية كأبيض، ثم حساب درجة الرمادي
      final gray = a == 0 ? 255 : (r * 0.299 + g * 0.587 + b * 0.114);

      if (gray < threshold) {
        // نقطة سوداء => نصفّر البت المقابل
        final byteIndex = row * widthBytes + (col ~/ 8);
        final bitPosition = 7 - (col % 8);
        bitmap[byteIndex] &= ~(1 << bitPosition);
      }
    }
  }

  // ترويسة الأمر النصية + بيانات ثنائية + سطر جديد
  final header = 'BITMAP $x,$y,$widthBytes,$height,0,';
  final bytes = <int>[];
  bytes.addAll(latin1.encode(header));
  bytes.addAll(bitmap);
  bytes.addAll([0x0D, 0x0A]); // CR LF
  return bytes;
}

/// ودجت تصميم الملصق العربي
Widget buildArabicLabel(String name, String price, String currency) {
  return Container(
    color: Colors.white,
    padding: const EdgeInsets.all(4),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          name.trim().isEmpty ? 'غير مصنف' : name.trim(),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 24, // خط كبير وواضح
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo', // يجب التأكد من توفره
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$price $currency',
          style: const TextStyle(
            color: Colors.black, 
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    ),
  );
}

/// يبني ملصق واحد كامل: CLS + BITMAP + باركود + PRINT.
Future<List<int>> buildOneLabel({
  required String name,
  required String price,
  required String barcode,
  required String currency,
  required double widthMm,
  required double heightMm,
}) async {
  // كثافة الطابعة الافتراضية 8 نقاط لكل مليمتر (203 dpi)
  final widthPx = widthMm * 8.0;
  final heightPx = heightMm * 8.0;
  
  // نترك مساحة في الأسفل للباركود مثلاً 100 بكسل
  final image = await widgetToImage(
    buildArabicLabel(name, price, currency),
    widthPx: widthPx,
    heightPx: heightPx - 100, // تم التقليص لتجنب الطفح للورقة التالية
  );
  
  final bitmapCmd = await imageToTsplBitmap(image, x: 0, y: 10);

  final bytes = <int>[];
  
  bytes.addAll(latin1.encode('CLS\r\n')); // تنظيف الذاكرة للملصق الجديد فقط
  bytes.addAll(bitmapCmd); // النص العربي كصورة
  
  // إضافة الباركود (code 128)
  final barcodeY = (heightPx - 90).toInt(); // تم رفع Y وتقليص الارتفاع
  bytes.addAll(latin1.encode(
    'BARCODE 40,$barcodeY,"128",45,1,0,2,2,"$barcode"\r\n'
    'PRINT 1,1\r\n', // نسخة واحدة
  ));
  
  return bytes;
}
