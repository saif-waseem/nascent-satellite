import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

class VariantPickerDialog extends StatefulWidget {
  final ProductModel product;
  const VariantPickerDialog({super.key, required this.product});

  @override
  State<VariantPickerDialog> createState() => _VariantPickerDialogState();
}

class _VariantPickerDialogState extends State<VariantPickerDialog> {
  String? selectedColor;
  String? selectedSize;

  @override
  void initState() {
    super.initState();
    if (widget.product.variants.isNotEmpty) {
      final available = widget.product.variants.where((v) => v.stock > 0).toList();
      if (available.isNotEmpty) {
        selectedColor = available.first.color;
        selectedSize = available.first.size;
      } else {
        selectedColor = widget.product.variants.first.color;
        selectedSize = widget.product.variants.first.size;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract unique colors and sizes from variants
    final availableColors = widget.product.variants
        .map((v) => v.color)
        .toSet()
        .toList();
    final availableSizes = widget.product.variants
        .map((v) => v.size)
        .toSet()
        .toList();

    return AlertDialog(
      title: Text('اختيار المتغير: ${widget.product.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (availableColors.isNotEmpty) ...[
              const Text('اللون / Color', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: availableColors.map((color) {
                  final isSelected = selectedColor == color;
                  return ChoiceChip(
                    label: Text(color),
                    selected: isSelected,
                    onSelected: (val) { if (val) setState(() => selectedColor = color); },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            if (availableSizes.isNotEmpty) ...[
              const Text('المقاس / Size', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: availableSizes.map((size) {
                  final isSelected = selectedSize == size;
                  return ChoiceChip(
                    label: Text(size),
                    selected: isSelected,
                    onSelected: (val) { if (val) setState(() => selectedSize = size); },
                  );
                }).toList(),
              ),
            ],
            
            const SizedBox(height: 24),
            // Show details for the currently selected combination
            Builder(
              builder: (context) {
                final match = widget.product.variants.where((v) => v.color == selectedColor && v.size == selectedSize).firstOrNull;
                if (match == null) {
                  return const Text('الخيار غير متوفر', style: TextStyle(color: Colors.red));
                }
                final displayPrice = match.price ?? widget.product.price;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('السعر:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${displayPrice.toStringAsFixed(0)} IQD', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('المخزون المتوفر:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          Text('${match.stock}', style: TextStyle(fontSize: 13, color: match.stock > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                );
              }
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        Builder(
          builder: (context) {
            final variant = widget.product.variants.where((v) => v.color == selectedColor && v.size == selectedSize).firstOrNull;
            final canAdd = variant != null && variant.stock > 0;
            return ElevatedButton(
              onPressed: canAdd ? () => Navigator.pop(context, variant) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canAdd ? Colors.blue : Colors.grey,
              ),
              child: Text(canAdd ? 'إضافة للسلة' : 'نفذت الكمية أو الخيار غير موجود'),
            );
          },
        ),
      ],
    );
  }
}
