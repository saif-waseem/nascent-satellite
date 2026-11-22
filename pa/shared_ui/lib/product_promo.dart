import 'package:flutter/material.dart';

class ProductPromo extends StatefulWidget {
  static const styles = {'indigo': 'نيلي فاخر', 'forest': 'زمردي ملكي', 'amber': 'ذهبي بريميوم'};
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
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  );
  late final Animation<double> _scaleAnimation = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeInOutSine,
  );

  int _currentIndex = 0;
  bool _isPlaying = true;

  @override
  void initState() {
    super.initState();
    _motion.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isPlaying) {
        if (mounted) {
          setState(() {
            _currentIndex++;
          });
          _motion.forward(from: 0);
        }
      }
    });
    _motion.forward();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  (List<Color>, Color, Color) _getStylePalette() {
    return switch (widget.style) {
      'forest' => (
        [const Color(0xff062822), const Color(0xff0d4d42), const Color(0xff167a68)],
        const Color(0xff10b981),
        const Color(0xff059669),
      ),
      'amber' => (
        [const Color(0xff361a04), const Color(0xff6e3909), const Color(0xffb46b14)],
        const Color(0xfff59e0b),
        const Color(0xffd97706),
      ),
      _ => (
        [const Color(0xff13112c), const Color(0xff29235c), const Color(0xff4338ca)],
        const Color(0xff818cf8),
        const Color(0xff6366f1),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (gradientColors, accentColor, glowColor) = _getStylePalette();
    final hasImages = widget.images.isNotEmpty;
    final currentImageUrl = hasImages ? widget.images[_currentIndex % widget.images.length] : '';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background ambient glow
          Positioned(
            top: -60,
            right: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor.withOpacity(0.25),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.2),
              ),
            ),
          ),

          // Main Animated Image Area
          Padding(
            padding: const EdgeInsets.only(top: 48, bottom: 120, left: 16, right: 16),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 900),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.94, end: 1.0).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<int>(_currentIndex),
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_scaleAnimation.value * 0.08),
                        child: child,
                      );
                    },
                    child: Hero(
                      tag: 'promo_${widget.title}_$_currentIndex',
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 25,
                              spreadRadius: 2,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: currentImageUrl.isNotEmpty
                              ? Image.network(
                                  currentImageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => _buildFallbackIcon(),
                                )
                              : _buildFallbackIcon(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top Header: Badge & Controls
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Promo Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, color: accentColor, size: 16),
                      const SizedBox(width: 6),
                      const Text(
                        'إعلان ترويجي مميز',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Play / Pause Button
                IconButton.filledTonal(
                  tooltip: _isPlaying ? 'إيقاف مؤقت' : 'تشغيل',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, size: 22),
                  onPressed: () {
                    setState(() {
                      _isPlaying = !_isPlaying;
                      if (_isPlaying) {
                        _motion.forward();
                      } else {
                        _motion.stop();
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          // Bottom Glassmorphic Card (Title, Price & Dots)
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [accentColor.withOpacity(0.9), glowColor],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      widget.price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (hasImages && widget.images.length > 1) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.images.length, (i) {
                        final active = (_currentIndex % widget.images.length) == i;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 16 : 6,
                          height: 5,
                          decoration: BoxDecoration(
                            color: active ? accentColor : Colors.white38,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        );
                      }),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.shopping_bag_outlined,
        size: 64,
        color: Colors.white70,
      ),
    );
  }
}
