import 'package:flutter/material.dart';
import 'package:shared_ui/product_promo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';
import 'package:store_admin/core/services/ai_video_service.dart';

void main() {
  testWidgets('local promo displays product data and pauses playback', (tester) async {
    expect(ProductPromo.styleOf(ProductPromo.reference('forest')), 'forest');
    expect(ProductPromo.styleOf('https://example.com/movie.mp4'), isNull);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ProductPromo(
      style: 'forest', title: 'منتج تجريبي', price: '5000', images: [],
    ))));
    expect(find.text('منتج تجريبي'), findsOneWidget);
    expect(find.text('5000'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  group('AI Promo Video & Media Features Verification', () {
    final aiVideoService = AiVideoService();

    test('generateVideoSpec creates accurate Remotion spec for Iraqi Dinar product', () {
      final product = ProductModel(
        id: 'test_prod_1',
        tenantId: 'store_baghdad',
        name: 'ساعة يد كلاسيكية فاخرة',
        price: 75000.0,
        category: 'ساعات',
        description: 'ساعة ممتازة مقاومة للماء مع ضمان سنة كاملة',
        rating: 5.0,
        isOffer: true,
        inStock: true,
        images: const ['https://example.com/watch.jpg'],
        sizes: const [],
        colors: const [],
        stockQuantity: 15,
        salesCount: 42,
        variants: const [],
        videoUrl: 'https://example.com/video.mp4',
      );

      final spec = aiVideoService.generateVideoSpec(
        product: product,
        currency: 'د.ع',
        style: 'promo',
      );

      expect(spec['fps'], equals(30));
      expect(spec['width'], equals(1080));
      expect(spec['height'], equals(1920)); // 9:16 vertical
      expect(spec['props']['productTitle'], equals('ساعة يد كلاسيكية فاخرة'));
      expect(spec['props']['productPrice'], equals('75000 د.ع'));
      expect(spec['props']['badgeText'], contains('عرض خاص'));
      expect(spec['props']['productImage'], equals('https://example.com/watch.jpg'));
      expect(spec['remotionCodeSnippet'], contains('remotion'));
    });

    test('ProductModel properly preserves videoUrl during serialization and copying', () {
      final product = ProductModel(
        id: 'prod_123',
        tenantId: 'store_1',
        name: 'عطر رجالي مميز',
        price: 45000.0,
        category: 'عطور',
        description: 'عطر فواح وثابت',
        images: const ['https://example.com/perfume.jpg'],
        videoUrl: 'https://axcdhxubqzbzjpbhyvvf.supabase.co/storage/v1/object/public/product-media/store_1/videos/perfume_reel.mp4',
      );

      final json = product.toJson();
      expect(json['videoUrl'], equals('https://axcdhxubqzbzjpbhyvvf.supabase.co/storage/v1/object/public/product-media/store_1/videos/perfume_reel.mp4'));

      final restored = ProductModel.fromJson(json);
      expect(restored.videoUrl, equals(product.videoUrl));

      final updated = restored.copyWith(videoUrl: 'https://new-cdn.com/new_video.mp4');
      expect(updated.videoUrl, equals('https://new-cdn.com/new_video.mp4'));
    });
  });
}
