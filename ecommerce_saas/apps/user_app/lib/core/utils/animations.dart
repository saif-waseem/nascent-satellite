import 'package:flutter/material.dart';

class AddToCartAnimation {
  static void run(BuildContext context, {GlobalKey? imageKey, GlobalKey? cartKey, RenderBox? startBox, required String imageUrl}) {
    final overlayState = Overlay.of(context);
    final renderBoxImage = startBox ?? (imageKey?.currentContext?.findRenderObject() as RenderBox?);
    final renderBoxCart = cartKey?.currentContext?.findRenderObject() as RenderBox?;

    if (renderBoxImage == null || renderBoxCart == null) return;

    final imagePosition = renderBoxImage.localToGlobal(Offset.zero);
    final cartPosition = renderBoxCart.localToGlobal(Offset.zero);

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return _FlyingImage(
          startPosition: imagePosition,
          endPosition: cartPosition,
          startSize: renderBoxImage.size,
          endSize: const Size(20, 20),
          imageUrl: imageUrl,
          onComplete: () {
            overlayEntry.remove();
          },
        );
      },
    );

    overlayState.insert(overlayEntry);
  }
}

class _FlyingImage extends StatefulWidget {
  final Offset startPosition;
  final Offset endPosition;
  final Size startSize;
  final Size endSize;
  final String imageUrl;
  final VoidCallback onComplete;

  const _FlyingImage({
    required this.startPosition,
    required this.endPosition,
    required this.startSize,
    required this.endSize,
    required this.imageUrl,
    required this.onComplete,
  });

  @override
  State<_FlyingImage> createState() => _FlyingImageState();
}

class _FlyingImageState extends State<_FlyingImage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final currentPos = Offset.lerp(widget.startPosition, widget.endPosition, _animation.value)!;
        final currentSize = Size.lerp(widget.startSize, widget.endSize, _animation.value)!;
        final opacity = 1.0 - _animation.value; // Fade out as it gets closer

        return Positioned(
          left: currentPos.dx,
          top: currentPos.dy,
          width: currentSize.width,
          height: currentSize.height,
          child: Opacity(
            opacity: 0.5 + (0.5 * opacity),
            child: Material(
              elevation: 4,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _buildImageOrIcon(widget.imageUrl),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageOrIcon(String data) {
    if (data.startsWith('http') || data.startsWith('https') || data.contains('/')) {
      return Image.network(data, fit: BoxFit.cover);
    }
    final iconCode = int.tryParse(data.isEmpty ? '58900' : data) ?? 58900;
    return Icon(IconData(iconCode, fontFamily: 'MaterialIcons'), size: 24, color: Colors.grey);
  }
}
