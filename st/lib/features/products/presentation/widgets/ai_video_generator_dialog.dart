import 'package:flutter/material.dart';
import 'package:shared_ui/product_promo.dart';
import 'package:shared_models/shared_models.dart';

/// Interactive Dynamic Motion Video Generator & Reel Player
/// Builds real dynamic motion reels with transitions, animations, and sound vibes
class AiVideoGeneratorDialog extends StatefulWidget {
  final ProductModel product;
  final String currency;
  final Function(String generatedUrl) onVideoAssigned;

  const AiVideoGeneratorDialog({
    super.key,
    required this.product,
    required this.currency,
    required this.onVideoAssigned,
  });

  @override
  State<AiVideoGeneratorDialog> createState() => _AiVideoGeneratorDialogState();
}

class _AiVideoGeneratorDialogState extends State<AiVideoGeneratorDialog> {
  String style = 'indigo';
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('إعلان من صور المنتج'),
    content: SingleChildScrollView(
      child: SizedBox(
        width: 280,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 9 / 16,
              child: ProductPromo(
                style: style,
                title: widget.product.name,
                price:
                    '${widget.product.price.toStringAsFixed(0)} ${widget.currency}',
                images: widget.product.images,
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (final entry in ProductPromo.styles.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: style == entry.key,
                    onSelected: (_) => setState(() => style = entry.key),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(
        onPressed: () {
          widget.onVideoAssigned(ProductPromo.reference(style));
          Navigator.pop(context);
        },
        child: const Text('اعتماد الإعلان'),
      ),
    ],
  );
}
