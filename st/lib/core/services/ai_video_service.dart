import 'dart:convert';
import 'package:shared_models/shared_models.dart';

class AiVideoService {
  /// Generates a Remotion Motion Video Specification based on the motion-starter-kit framework
  Map<String, dynamic> generateVideoSpec({
    required ProductModel product,
    required String currency,
    required String style, // 'promo', 'minimal', 'neon', 'elegant'
  }) {
    final title = product.name;
    final priceStr = '${product.price.toStringAsFixed(0)} $currency';
    final image = product.images.isNotEmpty ? product.images.first : '';
    final description = product.description.isNotEmpty
        ? (product.description.length > 60
            ? '${product.description.substring(0, 57)}...'
            : product.description)
        : 'أفضل جودة وأنسب سعر';

    return {
      'fps': 30,
      'durationInFrames': 150, // 5 seconds promo video
      'width': 1080,
      'height': 1920, // Vertical 9:16 format (ideal for Reels, Stories, TikTok)
      'style': style,
      'compositionName': 'ProductPromoMotion',
      'props': {
        'productTitle': title,
        'productPrice': priceStr,
        'productImage': image,
        'description': description,
        'badgeText': product.isOffer ? 'عرض خاص 🔥' : 'جديد ✨',
        'theme': _getStyleTheme(style),
      },
      'remotionCodeSnippet': _generateRemotionTsx(title, priceStr, image, style),
    };
  }

  Map<String, String> _getStyleTheme(String style) {
    switch (style) {
      case 'neon':
        return {
          'bgGradientStart': '#0F172A',
          'bgGradientEnd': '#38BDF8',
          'textColor': '#FFFFFF',
          'accentColor': '#38BDF8',
          'priceColor': '#38BDF8',
        };
      case 'elegant':
        return {
          'bgGradientStart': '#18181B',
          'bgGradientEnd': '#71717A',
          'textColor': '#FFFFFF',
          'accentColor': '#E4E4E7',
          'priceColor': '#F43F5E',
        };
      case 'minimal':
        return {
          'bgGradientStart': '#F8FAFC',
          'bgGradientEnd': '#E2E8F0',
          'textColor': '#0F172A',
          'accentColor': '#2563EB',
          'priceColor': '#16A34A',
        };
      case 'promo':
      default:
        return {
          'bgGradientStart': '#1E1B4B',
          'bgGradientEnd': '#4F46E5',
          'textColor': '#FFFFFF',
          'accentColor': '#FBBF24',
          'priceColor': '#34D399',
        };
    }
  }

  String _generateRemotionTsx(String title, String price, String img, String style) {
    return '''
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig, Img } from "remotion";

export const ProductPromo = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const scale = spring({ frame, fps, from: 0.8, to: 1, config: { damping: 12 } });
  const opacity = interpolate(frame, [0, 20], [0, 1]);

  return (
    <AbsoluteFill style={{ 
      background: "linear-gradient(135deg, #1E1B4B 0%, #4F46E5 100%)",
      display: "flex", alignItems: "center", justifyContent: "center", direction: "rtl"
    }}>
      <div style={{ transform: `scale(\${scale})`, opacity, textAlign: "center" }}>
        <Img src="${img}" style={{ width: 450, height: 450, borderRadius: 24, objectFit: "cover" }} />
        <h1 style={{ color: "#FFF", fontSize: 48, marginTop: 32 }}>${title}</h1>
        <div style={{ color: "#34D399", fontSize: 56, fontWeight: "bold" }}>${price}</div>
      </div>
    </AbsoluteFill>
  );
};
''';
  }
}
