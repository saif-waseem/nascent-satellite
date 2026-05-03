import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../providers/product_providers.dart';
import '../../../../core/utils/printing_service.dart';
import '../../../../core/providers/tenant_provider.dart';
import 'package:shared_models/shared_models.dart';

class BarcodePrintingScreen extends HookConsumerWidget {
  const BarcodePrintingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredProductsProvider);
    final tenant = ref.watch(tenantProvider);
    
    // State for print quantities: Map<PrintOption.id, ({PrintOption option, int qty})>
    final selectedProducts = useState<Map<String, ({
      String id,
      ProductModel product,
      ProductVariant? variant,
      String displayName,
      int qty
    })>>({});
    final isPrinting = useState(false);
    final showName = useState(true);
    final showPrice = useState(true);
    final showBarcodeText = useState(true);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('طباعة الباركود المجمّعة', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          if (selectedProducts.value.values.any((item) => item.qty > 0))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton.icon(
                icon: isPrinting.value 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.print),
                label: Text('طباعة المختار (${selectedProducts.value.values.fold(0, (a, b) => a + b.qty)})'),
                onPressed: isPrinting.value ? null : () async {
                   isPrinting.value = true;
                   try {
                     final printer = ref.read(printingServiceProvider);
                     final shop = tenant.value;
                     if (shop == null) return;

                     for (final item in selectedProducts.value.values) {
                       if (item.qty <= 0) continue;
                       
                       await printer.printBarcodeLabel(
                         name: item.displayName,
                         barcode: item.product.barcode ?? '',
                         price: item.variant?.price ?? item.product.price,
                         currency: shop.currencyUnit,
                         count: item.qty,
                         showName: showName.value,
                         showPrice: showPrice.value,
                         showBarcodeText: showBarcodeText.value,
                       );
                     }
                     
                     if (!context.mounted) return;
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال جميع الأوامر للطابعة')));
                     selectedProducts.value = {}; // Reset
                   } catch (e) {
                     if (!context.mounted) return;
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الطباعة: $e')));
                   } finally {
                     isPrinting.value = false;
                   }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Settings Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Colors.grey.withOpacity(0.2))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('إعدادات الطباعة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),
                CheckboxListTile(
                  title: const Text('إظهار اسم المنتج'),
                  value: showName.value,
                  onChanged: (v) => showName.value = v ?? true,
                ),
                CheckboxListTile(
                  title: const Text('إظهار السعر'),
                  value: showPrice.value,
                  onChanged: (v) => showPrice.value = v ?? true,
                ),
                CheckboxListTile(
                  title: const Text('إظهار رقم الباركود'),
                  value: showBarcodeText.value,
                  onChanged: (v) => showBarcodeText.value = v ?? true,
                ),
                const Spacer(),
                if (selectedProducts.value.values.any((item) => item.qty > 0))
                  Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    color: Colors.blue.withOpacity(0.05),
                    child: Column(
                      children: [
                        Text(
                          'إجمالي الملصقات: ${selectedProducts.value.values.fold(0, (a, b) => a + b.qty)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 45,
                          child: ElevatedButton.icon(
                            icon: isPrinting.value 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.print),
                            label: const Text('بدء الطباعة'),
                            onPressed: isPrinting.value ? null : () async {
                              isPrinting.value = true;
                              try {
                                final printer = ref.read(printingServiceProvider);
                                final shop = tenant.value;
                                if (shop == null) return;

                                for (final item in selectedProducts.value.values) {
                                  if (item.qty <= 0) continue;
                                  
                                  await printer.printBarcodeLabel(
                                    name: item.displayName,
                                    barcode: item.product.barcode ?? '',
                                    price: item.variant?.price ?? item.product.price,
                                    currency: shop.currencyUnit,
                                    count: item.qty,
                                    showName: showName.value,
                                    showPrice: showPrice.value,
                                    showBarcodeText: showBarcodeText.value,
                                  );
                                }
                                
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال جميع الأوامر للطابعة')));
                                selectedProducts.value = {}; // Reset
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الطباعة: $e')));
                              } finally {
                                isPrinting.value = false;
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    onChanged: (val) => ref.read(productSearchQueryProvider.notifier).set(val),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن منتج بالاسم أو الباركود...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey.withOpacity(0.1)),
                      ),
                    ),
                  ),
                ),
                
                Expanded(
            child: productsAsync.when(
              data: (products) {
                // Flatten products into print options
                final printOptions = <({String id, ProductModel product, ProductVariant? variant, String displayName})>[];
                for (final p in products) {
                  if (p.variants.isNotEmpty) {
                    for (final v in p.variants) {
                      // Only display valid variants (not default empty strings)
                      String varName = '';
                      final hasColor = v.color.trim().isNotEmpty && v.color != 'Default';
                      final hasSize = v.size.trim().isNotEmpty && v.size != 'Default';
                      if (hasColor || hasSize) {
                        varName += ' (';
                        if (hasColor) varName += v.color;
                        if (hasColor && hasSize) varName += ' - ';
                        if (hasSize) varName += v.size;
                        varName += ')';
                      }
                      
                      printOptions.add((
                        id: '${p.id}_${v.color}_${v.size}',
                        product: p,
                        variant: v,
                        displayName: '${p.name}$varName'
                      ));
                    }
                  } else {
                    printOptions.add((
                      id: p.id,
                      product: p,
                      variant: null,
                      displayName: p.name
                    ));
                  }
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: printOptions.length,
                  itemBuilder: (context, index) {
                    final option = printOptions[index];
                    final product = option.product;
                    final currentQty = selectedProducts.value[option.id]?.qty ?? 0;
                    final price = option.variant?.price ?? product.price;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      color: currentQty > 0 ? Colors.blue.withOpacity(0.05) : Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.inventory_2, color: Colors.grey),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(option.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('الباركود: ${product.barcode ?? "بدون"}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                  Text('السعر: $price ${tenant.value?.currencyUnit ?? ""}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 18),
                                    onPressed: currentQty > 0 
                                      ? () {
                                          final newMap = Map.of(selectedProducts.value);
                                          if (currentQty == 1) {
                                            newMap.remove(option.id);
                                          } else {
                                            newMap[option.id] = (
                                              id: option.id,
                                              product: option.product,
                                              variant: option.variant,
                                              displayName: option.displayName,
                                              qty: currentQty - 1
                                            );
                                          }
                                          selectedProducts.value = newMap;
                                        }
                                      : null,
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text('$currentQty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 18),
                                    onPressed: () {
                                      final newMap = Map.of(selectedProducts.value);
                                      newMap[option.id] = (
                                        id: option.id,
                                        product: option.product,
                                        variant: option.variant,
                                        displayName: option.displayName,
                                        qty: currentQty + 1
                                      );
                                      selectedProducts.value = newMap;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    ),
    ],
    ),
    );
  }
}
