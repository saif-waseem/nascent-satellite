import 'package:flutter/material.dart';

class ProductPromo extends StatefulWidget {
  static const styles = {'indigo': 'نيلي', 'forest': 'زمردي', 'amber': 'ذهبي'};
  static String reference(String style) => 'product-promo:v1/$style';
  static String? styleOf(String? value) {
    for (final style in styles.keys) {
      if (reference(style) == value) return style;
    }
    return null;
  }

  final String style, title, price;
  final List<String> images;
  const ProductPromo({
    super.key,
    required this.style,
    required this.title,
    required this.price,
    required this.images,
  });

  @override
  State<ProductPromo> createState() => _ProductPromoState();
}

class _ProductPromoState extends State<ProductPromo>
    with SingleTickerProviderStateMixin {
  late final motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );
  int index = 0;
  bool playing = true;
  @override
  void initState() {
    super.initState();
    motion.addStatusListener((status) {
      if (status == AnimationStatus.completed && playing) {
        setState(() => index++);
        motion.forward(from: 0);
      }
    });
    motion.forward();
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = switch (widget.style) {
      'forest' => const Color(0xff104f46),
      'amber' => const Color(0xff704914),
      _ => const Color(0xff342f70),
    };
    const fallback = Icon(
      Icons.shopping_bag_outlined,
      size: 64,
      color: Colors.white70,
    );
    final url = widget.images.isEmpty
        ? ''
        : widget.images[index % widget.images.length];
    return ColoredBox(
      color: color,
      child: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRect(
                  child: AnimatedBuilder(
                    animation: motion,
                    child: url.isEmpty
                        ? fallback
                        : Image.network(
                            url,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => fallback,
                          ),
                    builder: (_, child) => Transform.scale(
                      scale: 1 + motion.value * .045,
                      child: child,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton.filled(
                    tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل',
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    onPressed: () => setState(() {
                      playing = !playing;
                      if (playing) {
                        motion.forward();
                      } else {
                        motion.stop();
                      }
                    }),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.price,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
