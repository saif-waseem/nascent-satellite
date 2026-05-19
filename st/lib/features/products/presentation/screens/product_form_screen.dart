import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/features/shared/barcode_scanner_dialog.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:store_admin/core/services/storage_service.dart';

class ProductFormScreen extends HookConsumerWidget {
  final ProductModel? product;
  const ProductFormScreen({super.key, this.product});

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon, String? errorText, String? hintText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      errorText: errorText,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEditing = product != null;
    final tenantId = ref.watch(currentTenantIdProvider);

    final nameController = useTextEditingController(text: product?.name ?? '');
    final barcodeController = useTextEditingController(text: product?.barcode ?? '');
    final purchasePriceController = useTextEditingController(text: product?.purchasePrice?.toString() ?? '');
    final retailPriceController = useTextEditingController(text: product?.price.toString() ?? '');
    final wholesalePriceController = useTextEditingController(text: product?.wholesalePrice?.toString() ?? '');
    final stockController = useTextEditingController(text: product?.stockQuantity.toString() ?? '0');
    final minStockController = useTextEditingController(text: product?.minStockLevel?.toString() ?? '5');
    final unitController = useTextEditingController(text: product?.unit ?? 'قطعة');
    final categoryController = useTextEditingController(text: product?.category ?? 'عام');
    final descriptionController = useTextEditingController(text: product?.description ?? '');
    
    final images = useState<List<String>>(product?.images ?? []);
    final variants = useState<List<ProductVariant>>(product?.variants ?? []);
    
    final isOffer = useState(product?.isOffer ?? false);
    final isFeaturedDeal = useState(product?.isFeaturedDeal ?? false);
    final isDailyStarred = useState(product?.isDailyStarred ?? false);

    final isCheckingBarcode = useState(false);
    final existingProductWithBarcode = useState<ProductModel?>(null);
    final debounceTimer = useRef<Timer?>(null);

    void _checkBarcode(String barcode) {
      if (barcode.isEmpty || (isEditing && barcode == product?.barcode)) {
        existingProductWithBarcode.value = null;
        return;
      }

      debounceTimer.value?.cancel();
      debounceTimer.value = Timer(const Duration(milliseconds: 600), () async {
        isCheckingBarcode.value = true;
        try {
          final firestore = ref.read(adminFirestoreServiceProvider);
          final match = await firestore.getProductByBarcode(tenantId, barcode);
          if (match != null && match.id != product?.id) {
            existingProductWithBarcode.value = match;
          } else {
            existingProductWithBarcode.value = null;
          }
        } finally {
          isCheckingBarcode.value = false;
        }
      });
    }

    useEffect(() {
      barcodeController.addListener(() => _checkBarcode(barcodeController.text));
      return () => debounceTimer.value?.cancel();
    }, [barcodeController]);

    final isLoading = useState(false);

    void _handleSave() async {
      if (isLoading.value) return;
      if (nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم المنتج')));
        return;
      }

      int totalStock = int.tryParse(stockController.text) ?? 0;
      if (variants.value.isNotEmpty) {
        totalStock = variants.value.fold(0, (sum, v) {
          final vStock = v.storageLocations.fold(0, (s, loc) => s + loc.quantity);
          return sum + vStock;
        });
      }

      final newProduct = (product ?? ProductModel(
        id: '', tenantId: tenantId, name: '', category: '', description: '', price: 0.0,
      )).copyWith(
        name: nameController.text.trim(),
        description: descriptionController.text.trim(),
        barcode: barcodeController.text.trim(),
        purchasePrice: double.tryParse(purchasePriceController.text) ?? 0.0,
        price: double.tryParse(retailPriceController.text) ?? 0.0,
        wholesalePrice: double.tryParse(wholesalePriceController.text) ?? 0.0,
        stockQuantity: totalStock,
        minStockLevel: int.tryParse(minStockController.text) ?? 0,
        unit: unitController.text.trim(),
        category: categoryController.text.trim(),
        images: images.value,
        variants: variants.value.map((v) {
          final vStock = v.storageLocations.fold(0, (s, loc) => s + loc.quantity);
          return v.copyWith(stock: vStock);
        }).toList(),
        isOffer: isOffer.value,
        isFeaturedDeal: isFeaturedDeal.value,
        isDailyStarred: isDailyStarred.value,
        inStock: totalStock > 0,
      );

      try {
        isLoading.value = true;
        final firestore = ref.read(adminFirestoreServiceProvider);
        if (isEditing) {
          await firestore.updateProduct(newProduct, tenantId);
        } else {
          await firestore.addProduct(newProduct, tenantId);
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح')));
          context.pop();
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(isEditing ? 'تعديل: ${product?.name}' : 'منتج جديد'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 650;
          return Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 950),
              margin: isMobile ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(20),
                boxShadow: isMobile ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 16 : 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('المعلومات الأساسية', Icons.info_outline),
                          const SizedBox(height: 16),
                          TextField(
                            controller: nameController,
                            decoration: _inputDecoration('اسم المنتج'),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: barcodeController,
                            decoration: _inputDecoration(
                              'الباركود', 
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isCheckingBarcode.value)
                                    const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_scanner, color: Colors.blue),
                                    onPressed: () async {
                                      final code = await showDialog<String>(
                                        context: context,
                                        builder: (context) => const BarcodeScannerDialog(),
                                      );
                                      if (code != null) barcodeController.text = code;
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.refresh, color: Colors.blue),
                                    onPressed: () => barcodeController.text = DateTime.now().millisecondsSinceEpoch.toString(),
                                  ),
                                ],
                              ),
                              errorText: existingProductWithBarcode.value != null ? 'هذا الباركود مستخدم بالفعل مع منتج آخر' : null,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildSectionHeader('المخزون والأسعار', Icons.inventory_2_outlined),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: stockController,
                                  decoration: _inputDecoration('الكمية الإجمالية'),
                                  keyboardType: TextInputType.number,
                                  readOnly: variants.value.length > 1,
                                  style: variants.value.length > 1 ? const TextStyle(color: Colors.grey) : null,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: minStockController,
                                  decoration: _inputDecoration('حد التنبيه (النواقص)'),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (isMobile) ...[
                             TextField(controller: purchasePriceController, decoration: _inputDecoration('سعر الشراء'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                             const SizedBox(height: 16),
                             TextField(controller: retailPriceController, decoration: _inputDecoration('سعر البيع'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                             const SizedBox(height: 16),
                             TextField(controller: wholesalePriceController, decoration: _inputDecoration('سعر الجملة'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(child: TextField(controller: purchasePriceController, decoration: _inputDecoration('سعر الشراء'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                const SizedBox(width: 16),
                                Expanded(child: TextField(controller: retailPriceController, decoration: _inputDecoration('سعر البيع'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                                const SizedBox(width: 16),
                                Expanded(child: TextField(controller: wholesalePriceController, decoration: _inputDecoration('سعر الجملة'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                              ],
                            ),
                          ],
                      const SizedBox(height: 32),
                      _buildVariantsSection(context, variants),
                      const SizedBox(height: 32),
                      _buildSectionHeader('تصنيفات وصور', Icons.category_outlined),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Consumer(builder: (context, ref, _) {
                              final cats = ref.watch(adminCategoriesProvider).value ?? [];
                              return Autocomplete<String>(
                                optionsBuilder: (val) => cats.map((c) => c.name).where((s) => s.contains(val.text)),
                                onSelected: (s) => categoryController.text = s,
                                fieldViewBuilder: (ctx, ctrl, focus, onFieldSubmitted) {
                                  if (ctrl.text.isEmpty && categoryController.text.isNotEmpty) ctrl.text = categoryController.text;
                                  return TextField(
                                    controller: ctrl,
                                    focusNode: focus,
                                    onChanged: (v) => categoryController.text = v,
                                    decoration: _inputDecoration('القسم / Category'),
                                  );
                                },
                              );
                            }),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: TextField(controller: unitController, decoration: _inputDecoration('الوحدة (قطعة، درزن...)'))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(controller: descriptionController, decoration: _inputDecoration('وصف المنتج'), maxLines: 2),
                      const SizedBox(height: 24),
                      const Text('صور المنتج:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      _buildImageGrid(images, tenantId, ref),
                      const SizedBox(height: 32),
                      _buildSectionHeader('خيارات إضافية', Icons.settings_outlined),
                      _buildAdvancedOptions(isOffer, isFeaturedDeal, isDailyStarred),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade200))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                      child: Text(isLoading.value ? 'جاري الحفظ...' : 'حفظ المنتج'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  ),
);
}

  Widget _buildVariantsSection(BuildContext context, ValueNotifier<List<ProductVariant>> variants) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('الأصناف والمتغيرات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ElevatedButton.icon(
              onPressed: () => _showAddVariantDialog(context, variants),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة صنف'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade700, elevation: 0),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (variants.value.isEmpty)
          const Center(child: Text('لا توجد أصناف مضافة.'))
        else if (isMobile)
          Column(
            children: variants.value.asMap().entries.map((entry) {
              final idx = entry.key;
              final variant = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${variant.color} - ${variant.size}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => variants.value = List.from(variants.value)..removeAt(idx)),
                        ],
                      ),
                      const Divider(),
                      ListTile(
                        dense: true,
                        title: const Text('المخازن والكميات'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (variant.storageLocations.isEmpty) const Text('لا يوجد مخازن مسجلة'),
                            ...variant.storageLocations.map((loc) => Text('${loc.warehouseName}: ${loc.quantity}')),
                          ],
                        ),
                        trailing: const Icon(Icons.edit_location_alt_outlined, color: Colors.blue),
                        onTap: () => _showManageLocationsDialog(context, variants, idx),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          )
        else
          DataTable(
            columnSpacing: 24,
            dataRowHeight: 80,
            headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
            columns: const [
              DataColumn(label: Text('اللون / الحجم', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('المخازن والكميات', style: TextStyle(fontWeight: FontWeight.bold))),
              DataColumn(label: Text('إجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
            ],
            rows: variants.value.asMap().entries.map((entry) {
              final idx = entry.key;
              final variant = entry.value;
              return DataRow(cells: [
                DataCell(Text('${variant.color} - ${variant.size}')),
                DataCell(InkWell(
                  onTap: () => _showManageLocationsDialog(context, variants, idx),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (variant.storageLocations.isEmpty) const Text('لا يوجد مخازن مسجلة', style: TextStyle(fontSize: 10)),
                      ...variant.storageLocations.take(2).map((loc) => Text('${loc.warehouseName}: ${loc.quantity}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
                      if (variant.storageLocations.length > 2) Text('... وأخرى', style: const TextStyle(fontSize: 9, color: Colors.blue)),
                    ],
                  ),
                )),
                DataCell(IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => variants.value = List.from(variants.value)..removeAt(idx))),
              ]);
            }).toList(),
          ),
      ],
    );
  }

  void _showManageLocationsDialog(BuildContext context, ValueNotifier<List<ProductVariant>> variants, int vIdx) {
    List<ProductStorageLocation> localLocations = List.from(variants.value[vIdx].storageLocations);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إدارة المخازن'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...localLocations.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Expanded(child: TextFormField(initialValue: entry.value.warehouseName, decoration: const InputDecoration(labelText: 'اسم المخزن'), onChanged: (v) => localLocations[entry.key] = entry.value.copyWith(warehouseName: v))),
                        const SizedBox(width: 8),
                        SizedBox(width: 60, child: TextFormField(initialValue: entry.value.quantity.toString(), decoration: const InputDecoration(labelText: 'الكمية'), keyboardType: TextInputType.number, onChanged: (v) => localLocations[entry.key] = entry.value.copyWith(quantity: int.tryParse(v) ?? 0))),
                        IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () { localLocations.removeAt(entry.key); setState(() {}); }),
                      ],
                    ),
                  )),
                  TextButton.icon(onPressed: () { localLocations.add(const ProductStorageLocation(warehouseName: 'مخزن جديد', quantity: 0)); setState(() {}); }, icon: const Icon(Icons.add), label: const Text('إضافة مخزن')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(onPressed: () { variants.value = List.from(variants.value)..[vIdx] = variants.value[vIdx].copyWith(storageLocations: localLocations); Navigator.pop(ctx); }, child: const Text('حفظ')),
          ],
        ),
      ),
    );
  }

  void _showAddVariantDialog(BuildContext context, ValueNotifier<List<ProductVariant>> variants) {
    final colorController = TextEditingController();
    final sizeController = TextEditingController();
    final quantityController = TextEditingController(text: '0');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة نوع جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: colorController, decoration: const InputDecoration(labelText: 'اللون')),
            TextField(controller: sizeController, decoration: const InputDecoration(labelText: 'الحجم')),
            TextField(controller: quantityController, decoration: const InputDecoration(labelText: 'الكمية'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            final qty = int.tryParse(quantityController.text) ?? 0;
            variants.value = [...variants.value, ProductVariant(
              color: colorController.text.isEmpty ? 'Default' : colorController.text.trim(),
              size: sizeController.text.isEmpty ? 'Default' : sizeController.text.trim(),
              stock: qty,
              storageLocations: [ProductStorageLocation(warehouseName: 'المخزن الرئيسي', quantity: qty)],
            )];
            Navigator.pop(ctx);
          }, child: const Text('إضافة')),
        ],
      ),
    );
  }

  Widget _buildAdvancedOptions(ValueNotifier<bool> isOffer, ValueNotifier<bool> isFeaturedDeal, ValueNotifier<bool> isDailyStarred) {
    return Column(
      children: [
        SwitchListTile(title: const Text('تمييز كعرض (Offer)'), value: isOffer.value, onChanged: (v) => isOffer.value = v),
        SwitchListTile(title: const Text('منتج مميز (Featured)'), value: isFeaturedDeal.value, onChanged: (v) => isFeaturedDeal.value = v),
        SwitchListTile(title: const Text('منتج يومي (Daily Starred)'), value: isDailyStarred.value, onChanged: (v) => isDailyStarred.value = v),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(children: [Icon(icon, color: Colors.blue.shade700, size: 20), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]);
  }

  Widget _buildImageGrid(ValueNotifier<List<String>> images, String tenantId, WidgetRef ref) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: images.value.length + 1,
        itemBuilder: (ctx, i) {
          if (i == images.value.length) {
            return InkWell(
              onTap: () async {
                final url = await ref.read(storageServiceProvider).pickAndUploadImage('products');
                if (url != null) images.value = [...images.value, url];
              },
              child: Container(width: 100, decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.add_a_photo)),
            );
          }
          return Stack(
            children: [
              Container(margin: const EdgeInsets.only(right: 8), width: 100, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(images.value[i], fit: BoxFit.cover))),
              IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => images.value = List.from(images.value)..removeAt(i)),
            ],
          );
        },
      ),
    );
  }
}
