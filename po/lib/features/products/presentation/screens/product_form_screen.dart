import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:intl/intl.dart';
import '../../data/product_repository.dart';
import '../../../suppliers/data/supplier_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../providers/category_provider.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/printing_service.dart';
import '../providers/product_settings_provider.dart';
import '../../../reports/data/audit_repository.dart';
import '../../../../core/providers/permissions_provider.dart';
import '../../presentation/providers/product_providers.dart';
import '../../../suppliers/presentation/providers/suppliers_provider.dart';
import 'dart:async';
import '../../../../core/widgets/smart_image.dart';

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
    final tenantId = ref.watch(tenantIdProvider);
    final archivalEnabled = ref.watch(productArchivalEnabledProvider);

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
    
    final expiryDate = useState<DateTime?>(product?.expiryDate);
    final images = useState<List<String>>(product?.images ?? []);
    final supplierId = useState<String?>(product?.lastSupplierId);
    final sizes = useState<List<String>>(product?.sizes ?? []);
    final colors = useState<List<String>>(product?.colors ?? []);
    final variants = useState<List<ProductVariant>>(product?.variants ?? []);
    
    final isOffer = useState(product?.isOffer ?? false);
    final isFeaturedDeal = useState(product?.isFeaturedDeal ?? false);
    final isDailyStarred = useState(product?.isDailyStarred ?? false);

    final suppliersAsync = ref.watch(suppliersFutureProvider);
    final categoriesAsync = ref.watch(categoriesListProvider);

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
          final repo = ref.read(productRepositoryProvider);
          final match = await repo.getProductByBarcode(tenantId, barcode);
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

    void _handleDelete() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(archivalEnabled ? 'نقل للأرشيف؟' : 'حذف نهائي؟'),
          content: Text(archivalEnabled 
            ? 'هل تريد نقل هذا المنتج للأرشيف؟ يمكنك استعادته لاحقاً.' 
            : 'سيتم حذف هذا المنتج نهائياً من السيرفر. لا يمكن التراجع!'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(archivalEnabled ? 'نقل للأرشيف' : 'حذف نهائي'),
            ),
          ],
        ),
      );

      if (confirmed == true && isEditing) {
        final repo = ref.read(productRepositoryProvider);
        await repo.deleteProduct(tenantId, product!.id, permanent: !archivalEnabled);
        
        final staff = ref.read(currentStaffProvider);
        ref.read(auditRepositoryProvider).log(
          tenantId: tenantId,
          staffId: staff?.id ?? 'system',
          staffName: staff?.name ?? 'System',
          action: archivalEnabled ? 'archive_product' : 'delete_product',
          description: '${archivalEnabled ? "أرشفة" : "حذف"} المنتج: ${product!.name}',
          metadata: {'productId': product!.id},
        );

        ref.invalidate(pagedGeneralProductsProvider);
        ref.invalidate(productCountProvider);

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(archivalEnabled ? 'تم النقل للأرشيف' : 'تم الحذف نهائياً')));
        }
      }
    }

    final isLoading = useState(false);

    void _handleSave() async {
      if (isLoading.value) return;
      if (nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم المنتج')));
        return;
      }

      int totalStock = int.tryParse(stockController.text) ?? 0;
      // Always calculate total stock from variants if they exist
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
        expiryDate: expiryDate.value,
        images: images.value,
        sizes: sizes.value,
        colors: colors.value,
        variants: variants.value.map((v) {
          final vStock = v.storageLocations.fold(0, (s, loc) => s + loc.quantity);
          return v.copyWith(stock: vStock);
        }).toList(),
        isOffer: isOffer.value,
        isFeaturedDeal: isFeaturedDeal.value,
        isDailyStarred: isDailyStarred.value,
        lastSupplierId: supplierId.value,
        isArchived: false,
      );

      try {
        isLoading.value = true;
        final repo = ref.read(productRepositoryProvider);
        await repo.saveProduct(tenantId, newProduct);
        
        final staff = ref.read(currentStaffProvider);
        ref.read(auditRepositoryProvider).log(
          tenantId: tenantId,
          staffId: staff?.id ?? 'system',
          staffName: staff?.name ?? 'System',
          action: isEditing ? 'edit_product' : 'add_product',
          description: '${isEditing ? "تعديل" : "إضافة"} منتج: ${newProduct.name}',
          metadata: {'productId': newProduct.id},
        );

        ref.invalidate(pagedGeneralProductsProvider);
        ref.invalidate(productCountProvider);

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح')));
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
        actions: [
          if (isEditing)
             IconButton(
               icon: const Icon(Icons.delete_forever, color: Colors.red),
               onPressed: _handleDelete,
               tooltip: archivalEnabled ? 'أرشفة' : 'حذف نهائي',
             ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 650;
          final isTablet = constraints.maxWidth >= 650 && constraints.maxWidth < 1024;
          
          return Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 950),
              margin: isMobile ? EdgeInsets.zero : EdgeInsets.symmetric(
                vertical: isTablet ? 12 : 24, 
                horizontal: isTablet ? 8 : 16
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(20),
                boxShadow: isMobile ? [] : [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                ],
              ),
              child: ClipRRect(
                borderRadius: isMobile ? BorderRadius.zero : BorderRadius.circular(20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
                      ),
                      child: Row(
                        children: [
                          if (isMobile) 
                            IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                          const Spacer(),
                          _windowControl(Icons.remove, Colors.grey, () => Navigator.pop(context)),
                          const SizedBox(width: 12),
                          _windowControl(Icons.crop_square, Colors.grey, () {}),
                          const SizedBox(width: 12),
                          _windowControl(Icons.close, Colors.red, () => Navigator.pop(context)),
                        ],
                      ),
                    ),
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
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                            icon: const Icon(Icons.refresh, color: Colors.blue),
                                            onPressed: () => barcodeController.text = DateTime.now().millisecondsSinceEpoch.toString(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                          Row(
                            children: [
                              Expanded(child: TextField(controller: purchasePriceController, decoration: _inputDecoration('سعر الشراء'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                              const SizedBox(width: 16),
                              Expanded(child: TextField(controller: retailPriceController, decoration: _inputDecoration('سعر البيع'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: TextField(controller: wholesalePriceController, decoration: _inputDecoration('سعر الجملة'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                              const SizedBox(width: 16),
                              const Spacer(),
                            ],
                          ),
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
                        _buildVariantsSection(context, sizes, colors, variants, retailPriceController),
                        const SizedBox(height: 32),
                        _buildSectionHeader('تصنيفات وصور', Icons.category_outlined),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Consumer(builder: (context, ref, _) {
                                final cats = ref.watch(categoriesListProvider).value ?? [];
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
        ),
      );
    },
  ),
);
}

  Widget _buildVariantsSection(
    BuildContext context, 
    ValueNotifier<List<String>> sizes, 
    ValueNotifier<List<String>> colors, 
    ValueNotifier<List<ProductVariant>> variants,
    TextEditingController priceController,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'الأصناف والمتغيرات',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddVariantDialog(context, variants),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة صنف'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50, 
                foregroundColor: Colors.blue.shade700, 
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (variants.value.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text('لا توجد أصناف مضافة.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            ),
          )
        else if (isMobile)
          // Mobile View: Cards
          Column(
            children: variants.value.asMap().entries.map((entry) {
              final idx = entry.key;
              final variant = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${variant.color} - ${variant.size}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                            onPressed: () => variants.value = List.from(variants.value)..removeAt(idx),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Expanded(child: Text('السعر الخاص:', style: TextStyle(fontSize: 12, color: Colors.grey))),
                          SizedBox(
                            width: 100,
                            child: _VariantPriceField(
                              initialValue: variant.price?.toString() ?? '',
                              onChanged: (val) {
                                final price = double.tryParse(val);
                                variants.value = List.from(variants.value)..[idx] = variant.copyWith(price: price, clearPrice: val.isEmpty);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('المخازن والكميات:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () => _showManageLocationsDialog(context, variants, idx),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (variant.storageLocations.isEmpty)
                                const Text('لا يوجد مخازن مسجلة', style: TextStyle(color: Colors.grey, fontSize: 11)),
                              ...variant.storageLocations.map((loc) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warehouse_outlined, size: 14, color: Colors.blueGrey),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('${loc.warehouseName}: ${loc.quantity}', style: const TextStyle(fontSize: 12))),
                                  ],
                                ),
                              )),
                              const SizedBox(height: 4),
                              const Text('إدارة المخازن ⚙️', style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          )
        else
          // Desktop View: Table
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                dataRowHeight: 120,
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade50),
                columns: const [
                  DataColumn(label: Text('اللون / الحجم', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('السعر الخاص', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('المخازن والكميات', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('إجراءات', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: variants.value.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final variant = entry.value;
                  return DataRow(cells: [
                    DataCell(Text('${variant.color} - ${variant.size}')),
                    DataCell(SizedBox(
                      width: 120,
                      child: _VariantPriceField(
                        initialValue: variant.price?.toString() ?? '',
                        onChanged: (val) {
                          final price = double.tryParse(val);
                          variants.value = List.from(variants.value)..[idx] = variant.copyWith(price: price, clearPrice: val.isEmpty);
                        },
                      ),
                    )),
                    DataCell(InkWell(
                      onTap: () => _showManageLocationsDialog(context, variants, idx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        width: 250,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (variant.storageLocations.isEmpty)
                              const Text('لا يوجد مخازن مسجلة', style: TextStyle(color: Colors.grey, fontSize: 10)),
                            ...variant.storageLocations.take(3).map((loc) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Row(
                                children: [
                                  const Icon(Icons.warehouse, size: 10, color: Colors.blueGrey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '${loc.warehouseName}${loc.shelf != null ? ' (رف: ${loc.shelf})' : ''}: ${loc.quantity}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            if (variant.storageLocations.length > 3)
                              Text('... و ${variant.storageLocations.length - 3} أخرى', style: const TextStyle(fontSize: 9, color: Colors.blue)),
                            const SizedBox(height: 4),
                            const Text('إدارة المخازن ⚙️', style: TextStyle(fontSize: 9, color: Colors.blue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    )),
                    DataCell(IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => variants.value = List.from(variants.value)..removeAt(idx),
                    )),
                  ]);
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }


  void _showManageLocationsDialog(BuildContext context, ValueNotifier<List<ProductVariant>> variants, int vIdx) {
    // We will keep a local copy of storage locations for editing
    List<ProductStorageLocation> localLocations = List.from(variants.value[vIdx].storageLocations);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final variant = variants.value[vIdx];
          return AlertDialog(
            title: Text('إدارة مخازن: ${variant.color}/${variant.size}'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...localLocations.asMap().entries.map((entry) {
                      final lIdx = entry.key;
                      final loc = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: TextFormField(
                                    initialValue: loc.warehouseName,
                                    decoration: const InputDecoration(labelText: 'اسم المخزن', isDense: true),
                                    onChanged: (val) {
                                      localLocations[lIdx] = localLocations[lIdx].copyWith(warehouseName: val);
                                    },
                                  )),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () {
                                      localLocations.removeAt(lIdx);
                                      setState(() {});
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: loc.shelf ?? '',
                                          decoration: const InputDecoration(labelText: 'الرف', isDense: true),
                                          onChanged: (val) {
                                            localLocations[lIdx] = localLocations[lIdx].copyWith(shelf: val);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: loc.box ?? '',
                                          decoration: const InputDecoration(labelText: 'الصندوق', isDense: true),
                                          onChanged: (val) {
                                            localLocations[lIdx] = localLocations[lIdx].copyWith(box: val);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: loc.quantity.toString(),
                                          decoration: const InputDecoration(labelText: 'الكمية', isDense: true),
                                          keyboardType: TextInputType.number,
                                          onChanged: (val) {
                                            localLocations[lIdx] = localLocations[lIdx].copyWith(quantity: int.tryParse(val) ?? 0);
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: TextFormField(
                                          initialValue: loc.priceOverride?.toString() ?? '',
                                          decoration: const InputDecoration(labelText: 'سعر خاص', isDense: true),
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          onChanged: (val) {
                                            localLocations[lIdx] = localLocations[lIdx].copyWith(
                                              priceOverride: double.tryParse(val),
                                              clearPriceOverride: val.isEmpty,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        localLocations.add(const ProductStorageLocation(warehouseName: 'مخزن جديد', quantity: 0));
                        setState(() {});
                      },
                      icon: const Icon(Icons.add_business),
                      label: const Text('إضافة مخزن آخر'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () {
                  final newVStock = localLocations.fold(0, (sum, l) => sum + l.quantity);
                  variants.value = List.from(variants.value)..[vIdx] = variant.copyWith(
                    storageLocations: localLocations,
                    stock: newVStock,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('حفظ'),
              ),
            ],
          );
        }
      ),
    );
  }

  void _showAddVariantDialog(
    BuildContext context, 
    ValueNotifier<List<ProductVariant>> variants,
  ) {
    final colorController = TextEditingController();
    final sizeController = TextEditingController();
    final quantityController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة نوع جديد (صنف)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: colorController, decoration: const InputDecoration(labelText: 'اللون (مثلاً: أحمر)')),
            TextField(controller: sizeController, decoration: const InputDecoration(labelText: 'الحجم (مثلاً: XL)')),
            TextField(
              controller: quantityController, 
              decoration: const InputDecoration(labelText: 'الكمية الابتدائية'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final qty = int.tryParse(quantityController.text) ?? 0;
              variants.value = [...variants.value, ProductVariant(
                color: colorController.text.isEmpty ? 'Default' : colorController.text.trim(),
                size: sizeController.text.isEmpty ? 'Default' : sizeController.text.trim(),
                stock: qty,
                storageLocations: [
                  ProductStorageLocation(warehouseName: 'المخزن الرئيسي', quantity: qty),
                ],
              )];
              Navigator.pop(ctx);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedOptions(
    ValueNotifier<bool> isOffer, 
    ValueNotifier<bool> isFeaturedDeal, 
    ValueNotifier<bool> isDailyStarred,
  ) {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('تمييز كعرض (Special Offer)'),
          subtitle: const Text('سيظهر المنتج في قسم العروض'),
          value: isOffer.value,
          onChanged: (v) => isOffer.value = v,
          secondary: Icon(Icons.local_offer, color: Colors.orange.shade400),
        ),
        SwitchListTile(
          title: const Text('منتج مميز (Featured Deal)'),
          subtitle: const Text('سيظهر في الشريط العلوي المميز'),
          value: isFeaturedDeal.value,
          onChanged: (v) => isFeaturedDeal.value = v,
          secondary: Icon(Icons.star, color: Colors.yellow.shade700),
        ),
        SwitchListTile(
          title: const Text('منتج يومي (Daily Starred)'),
          subtitle: const Text('تفعيل ميزة النجوم اليومية'),
          value: isDailyStarred.value,
          onChanged: (v) => isDailyStarred.value = v,
          secondary: Icon(Icons.calendar_today, color: Colors.purple.shade400),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
      ],
    );
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
                final url = await ref.read(storageServiceProvider).pickAndUploadImage(tenantId: tenantId, folder: 'products');
                if (url != null) images.value = [...images.value, url];
              },
              child: Container(
                width: 100,
                decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade100)),
                child: Icon(Icons.add_a_photo, color: Colors.blue.shade600),
              ),
            );
          }
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 12),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SmartImage(
                    imageUrl: images.value[i],
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => images.value = List.from(images.value)..removeAt(i),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _windowControl(IconData icon, Color color, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Icon(icon, color: color.withOpacity(0.8), size: 20),
      ),
    );
  }
}

class _VariantPriceField extends HookWidget {
  final String initialValue;
  final Function(String) onChanged;
  const _VariantPriceField({required this.initialValue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: initialValue);
    return TextField(
      decoration: const InputDecoration(
        labelText: 'سعر خاص لهذا النوع (اختياري)', 
        hintText: 'سيتم استخدام السعر الأساسي إذا تركت فارغة',
        isDense: true,
        border: OutlineInputBorder(),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      controller: controller,
      onChanged: onChanged,
    );
  }
}

class _StorageTextField extends HookWidget {
  final String initialValue;
  final String label;
  final Function(String) onChanged;
  final bool isNum;
  const _StorageTextField({required this.initialValue, required this.label, required this.onChanged, this.isNum = false});

  @override
  Widget build(BuildContext context) {
    final controller = useTextEditingController(text: initialValue);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontSize: 12),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
