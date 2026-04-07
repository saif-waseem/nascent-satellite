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

    return AlertDialog(
      title: Text('إضافة مادة: ${product.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('آخر سعر شراء: ${product.purchasePrice ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
                if (priceDiff.abs() > 0.05)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: priceDiff > 0 ? Colors.red[50] : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(priceDiff * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: priceDiff > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكمية / Quantity'),
            ),
            TextField(
              controller: costController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => (context as Element).markNeedsBuild(), // Force rebuild to update priceDiff badge
              decoration: const InputDecoration(
                labelText: 'سعر الشراء الجديد',
                suffixText: 'IQD',
              ),
            ),
            if (priceDiff > 0.1)
               const Padding(
                 padding: EdgeInsets.only(top: 8.0),
                 child: Text('⚠️ السعر ارتفع بنسبة كبيرة!', style: TextStyle(color: Colors.red, fontSize: 12)),
               ),
            TextField(
              controller: discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'الخصم المباشر'),
            ),
          ],
        ),
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
            );
            Navigator.pop(context, item);
          },
          child: const Text('إضافة للفاتورة'),
        ),
      ],
    );
  }
}
