import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';

class AddItemDialog extends HookWidget {
  final ProductModel product;

  const AddItemDialog({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final qtyController = useTextEditingController(text: '1');
    final cost = useState(product.purchasePrice ?? product.price);
    final costController = useTextEditingController(text: cost.value.toString());
    final discountController = useTextEditingController(text: '0');
    
    final priceDiff = product.purchasePrice != null && product.purchasePrice! > 0 
        ? ((double.tryParse(costController.text) ?? 0) - product.purchasePrice!) / product.purchasePrice! 
        : 0.0;

    final selectedColor = useState<String?>(product.variants.isNotEmpty ? product.variants.first.color : null);
    final selectedSize = useState<String?>(product.variants.isNotEmpty ? product.variants.first.size : null);

    final availableColors = product.variants.map((v) => v.color).toSet().toList();
    final availableSizes = product.variants.map((v) => v.size).toSet().toList();

    return AlertDialog(
      scrollable: true,
      title: Text('إضافة مادة: ${product.name}'),
      content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('آخر سعر شراء: ${product.purchasePrice ?? 'N/A'}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                if (priceDiff.abs() > 0.05)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: priceDiff > 0 ? Colors.red[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(priceDiff * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: priceDiff > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (availableColors.isNotEmpty) ...[
              const Text('اللون / Color', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: availableColors.map((color) {
                  final isSelected = selectedColor.value == color;
                  return ChoiceChip(
                    label: Text(color, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    selectedColor: Colors.blue,
                    onSelected: (val) { if (val) selectedColor.value = color; },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            
            if (availableSizes.isNotEmpty) ...[
              const Text('المقاس / Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: availableSizes.map((size) {
                  final isSelected = selectedSize.value == size;
                  return ChoiceChip(
                    label: Text(size, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                    selected: isSelected,
                    selectedColor: Colors.blue,
                    onSelected: (val) { if (val) selectedSize.value = size; },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الكمية / Quantity',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => (context as Element).markNeedsBuild(), // Force rebuild to update priceDiff badge
              decoration: const InputDecoration(
                labelText: 'سعر الشراء الجديد',
                suffixText: 'IQD',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (priceDiff > 0.1)
               const Padding(
                 padding: EdgeInsets.only(top: 8.0),
                 child: Text('⚠️ السعر ارتفع بنسبة كبيرة!', style: TextStyle(color: Colors.red, fontSize: 11)),
               ),
            const SizedBox(height: 12),
            TextField(
              controller: discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'الخصم المباشر',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: () {
            final qty = int.tryParse(qtyController.text) ?? 1;
            final cost = double.tryParse(costController.text) ?? 0.0;
            final disc = double.tryParse(discountController.text) ?? 0.0;

            final item = InvoiceItem(
              productId: product.id,
              productName: product.name,
              quantity: qty,
              unitCost: cost,
              discount: disc,
              variantColor: selectedColor.value,
              variantSize: selectedSize.value,
            );
            Navigator.pop(context, item);
          },
          child: const Text('إضافة للفاتورة'),
        ),
      ],
    );
  }
}
