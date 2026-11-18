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
import '../providers/product_settings_provider.dart';
import '../../../../core/utils/printing_service.dart';

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
    final videoUrl = useState<String?>(product?.videoUrl);
    final isUploadingVideo = useState<bool>(false);
    final supplierId = useState<String?>(product?.lastSupplierId);
    final sizes = useState<List<String>>(product?.sizes ?? []);
    final colors = useState<List<String>>(product?.colors ?? []);
    final variants = useState<List<ProductVariant>>(product?.variants ?? []);
    
    final isOffer = useState(product?.isOffer ?? false);
    final isFeaturedDeal = useState(product?.isFeaturedDeal ?? false);
    final isDailyStarred = useState(product?.isDailyStarred ?? false);

    final suppliersAsync = ref.watch(suppliersListProvider(tenantId));
    final categoriesAsync = ref.watch(categoriesListProvider);

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
        await ref.read(productRepositoryProvider).deleteProduct(tenantId, product!.id, permanent: !archivalEnabled);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(archivalEnabled ? 'تم النقل للأرشيف' : 'تم الحذف نهائياً')));
        }
      }
    }

    void _handleSave() async {
      if (nameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال اسم المنتج')));
        return;
      }

      int totalStock = int.tryParse(stockController.text) ?? 0;
      if (variants.value.isNotEmpty) {
        final variantTotal = variants.value.fold(0, (sum, v) {
          if (v.storageLocations.isNotEmpty) {
            return sum + v.storageLocations.fold(0, (s, loc) => s + loc.quantity);
          }
          return sum + v.stock;
        });
        if (variantTotal > 0) {
          totalStock = variantTotal;
        }
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
        videoUrl: videoUrl.value,
        sizes: sizes.value,
        colors: colors.value,
        variants: variants.value,
        isOffer: isOffer.value,
        isFeaturedDeal: isFeaturedDeal.value,
        isDailyStarred: isDailyStarred.value,
        lastSupplierId: supplierId.value,
        isArchived: false,
      );

      try {
        await ref.read(productRepositoryProvider).saveProduct(tenantId, newProduct);
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المنتج بنجاح')));
        }
      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
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
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
          margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionHeader('المعلومات الأساسية', Icons.info_outline),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameController,
                          decoration: _inputDecoration('اسم المنتج (بالعربي أو الإنجليزي)'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: barcodeController,
                                decoration: _inputDecoration('الباركود / Barcode', 
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.refresh, color: Colors.blue),
                                        tooltip: 'توليد باركود تلقائي',
                                        onPressed: () {
                                          barcodeController.text = DateTime.now().millisecondsSinceEpoch.toString();
                                        },
                                      ),
                                      if (isEditing)
                                        IconButton(
                                          icon: const Icon(Icons.print, color: Colors.grey),
                                          tooltip: 'طباعة الباركود',
                                          onPressed: () {
                                             ref.read(printingServiceProvider).printBarcodeLabel(
                                              name: nameController.text,
                                              barcode: barcodeController.text,
                                              price: double.tryParse(retailPriceController.text) ?? 0.0,
                                              currency: 'IQD',
                                              category: categoryController.text,
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: descriptionController,
                                decoration: _inputDecoration('وصف المنتج'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        _buildSectionHeader('الأسعار والمخزون', Icons.inventory_2_outlined),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: purchasePriceController, decoration: _inputDecoration('سعر الشراء'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                            const SizedBox(width: 16),
                            Expanded(child: TextField(controller: retailPriceController, decoration: _inputDecoration('سعر البيع (مفرد)'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                            const SizedBox(width: 16),
                            Expanded(child: TextField(controller: wholesalePriceController, decoration: _inputDecoration('سعر الجملة'), keyboardType: const TextInputType.numberWithOptions(decimal: true))),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: stockController, decoration: _inputDecoration('الكمية الحالية'), keyboardType: TextInputType.number)),
                            const SizedBox(width: 16),
                            Expanded(child: TextField(controller: minStockController, decoration: _inputDecoration('الحد الأدنى للمخزون'), keyboardType: TextInputType.number)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: expiryDate.value ?? DateTime.now(),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                  );
                                  if (date != null) expiryDate.value = date;
                                },
                                child: InputDecorator(
                                  decoration: _inputDecoration('تاريخ الصلاحية (اختياري)'),
                                  child: Text(expiryDate.value == null ? 'اختر تاريخ' : DateFormat('yyyy-MM-dd').format(expiryDate.value!)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        _buildSectionHeader('التصنيف والوحدات', Icons.category_outlined),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: categoriesAsync.when(
                                data: (list) => DropdownButtonFormField<String>(
                                  value: list.any((c) => c.name == categoryController.text) ? categoryController.text : null,
                                  decoration: _inputDecoration('التصنيف'),
                                  items: list.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name))).toList(),
                                  onChanged: (v) => categoryController.text = v ?? '',
                                ),
                                loading: () => const SizedBox(),
                                error: (_, __) => const SizedBox(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: suppliersAsync.when(
                                data: (list) => DropdownButtonFormField<String>(
                                  value: supplierId.value,
                                  decoration: _inputDecoration('المورد'),
                                  items: list.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))).toList(),
                                  onChanged: (val) => supplierId.value = val,
                                ),
                                loading: () => const SizedBox(),
                                error: (_, __) => const SizedBox(),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(child: TextField(controller: unitController, decoration: _inputDecoration('الوحدة'))),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        _buildSectionHeader('الأحجام والألوان (الأنواع والمخازن)', Icons.style_outlined),
                        const SizedBox(height: 16),
                        _buildVariantsSection(context, sizes, colors, variants, retailPriceController),
                        const SizedBox(height: 32),

                        _buildSectionHeader('الصور والفيديو', Icons.image_outlined),
                        const SizedBox(height: 16),
                        _buildImageGrid(images, tenantId, ref),
                        const SizedBox(height: 24),
                        _buildVideoSection(
                          videoUrl: videoUrl,
                          isUploading: isUploadingVideo,
                          tenantId: tenantId,
                          context: context,
                          ref: ref,
                        ),
                        const SizedBox(height: 32),

                        _buildSectionHeader('خيارات متقدمة', Icons.settings_outlined),
                        const SizedBox(height: 16),
                        _buildAdvancedOptions(isOffer, isFeaturedDeal, isDailyStarred),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(top: BorderSide(color: Colors.grey.shade200))),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleSave,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(isEditing ? 'تحديث البيانات' : 'حفظ المنتج'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildChipList(
                context, 
                'الأحجام المتوفرة (M, XL...)', 
                sizes, 
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildChipList(
                context, 
                'الألوان المتوفرة (أحمر، أزرق...)', 
                colors, 
                Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('إضافة نوع (Variant)'),
              onPressed: () => _showAddVariantDialog(context, sizes.value, colors.value, variants, priceController),
            ),
          ],
        ),
        if (variants.value.isNotEmpty) ...[
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: variants.value.length,
            itemBuilder: (context, idx) {
              final v = variants.value[idx];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${v.color} - ${v.size}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text('السعر: ${v.price != null ? "${v.price} IQD" : "السعر الأساسي"} | الكمية: ${v.stock} قطعة', style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                            if (v.storageLocations.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 6,
                                children: v.storageLocations.map((loc) => Chip(
                                  label: Text('${loc.warehouseName}: ${loc.quantity}', style: const TextStyle(fontSize: 10)),
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_location_alt_outlined, color: Colors.blue),
                        tooltip: 'إدارة المخازن',
                        onPressed: () => _showManageLocationsDialog(context, variants, idx),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'حذف النوع',
                        onPressed: () => variants.value = List.from(variants.value)..removeAt(idx),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  void _showManageLocationsDialog(BuildContext context, ValueNotifier<List<ProductVariant>> variants, int vIdx) {
    List<ProductStorageLocation> localLocations = List.from(variants.value[vIdx].storageLocations);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إدارة المخازن والكميات لهذا الصنف'),
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
                        Expanded(
                          child: TextFormField(
                            initialValue: entry.value.warehouseName,
                            decoration: const InputDecoration(labelText: 'اسم المخزن / الفرع'),
                            onChanged: (v) => localLocations[entry.key] = entry.value.copyWith(warehouseName: v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: TextFormField(
                            initialValue: entry.value.quantity.toString(),
                            decoration: const InputDecoration(labelText: 'الكمية'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => localLocations[entry.key] = entry.value.copyWith(quantity: int.tryParse(v) ?? 0),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            localLocations.removeAt(entry.key);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                  )),
                  TextButton.icon(
                    onPressed: () {
                      localLocations.add(const ProductStorageLocation(warehouseName: 'مخزن جديد', quantity: 0));
                      setState(() {});
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة مخزن'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final totalQty = localLocations.fold(0, (sum, loc) => sum + loc.quantity);
                variants.value = List.from(variants.value)..[vIdx] = variants.value[vIdx].copyWith(
                  storageLocations: localLocations,
                  stock: totalQty,
                );
                Navigator.pop(ctx);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChipList(BuildContext context, String label, ValueNotifier<List<String>> list, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          children: [
            ...list.value.asMap().entries.map((entry) => Chip(
              label: Text(entry.value, style: const TextStyle(fontSize: 10)),
              backgroundColor: color.withOpacity(0.1),
              onDeleted: () => list.value = List.from(list.value)..removeAt(entry.key),
            )),
            ActionChip(
              label: const Icon(Icons.add, size: 14),
              onPressed: () => _showAddChipDialog(context, label, list),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddChipDialog(BuildContext context, String title, ValueNotifier<List<String>> list) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة $title'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(onPressed: () {
            if (controller.text.isNotEmpty) list.value = [...list.value, controller.text.trim()];
            Navigator.pop(ctx);
          }, child: const Text('إضافة')),
        ],
      ),
    );
  }

  void _showAddVariantDialog(
    BuildContext context, 
    List<String> sizes, 
    List<String> colors, 
    ValueNotifier<List<ProductVariant>> variants,
    TextEditingController priceController,
  ) {
    String? selectedSize = sizes.isNotEmpty ? sizes.first : null;
    String? selectedColor = colors.isNotEmpty ? colors.first : null;
    final pController = TextEditingController(text: priceController.text);
    final qController = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('إضافة نوع مخصص'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sizes.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedSize,
                  items: sizes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setState(() => selectedSize = v),
                  decoration: const InputDecoration(labelText: 'الحجم'),
                )
              else
                TextField(
                  decoration: const InputDecoration(labelText: 'الحجم / القياس (مثال: XL)'),
                  onChanged: (v) => selectedSize = v,
                ),
              const SizedBox(height: 8),
              if (colors.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedColor,
                  items: colors.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => selectedColor = v),
                  decoration: const InputDecoration(labelText: 'اللون'),
                )
              else
                TextField(
                  decoration: const InputDecoration(labelText: 'اللون (مثال: أسود)'),
                  onChanged: (v) => selectedColor = v,
                ),
              const SizedBox(height: 8),
              TextField(controller: qController, decoration: const InputDecoration(labelText: 'الكمية'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextField(controller: pController, decoration: const InputDecoration(labelText: 'السعر المخصص (اختياري)'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final qty = int.tryParse(qController.text) ?? 0;
                variants.value = [...variants.value, ProductVariant(
                  size: (selectedSize != null && selectedSize!.isNotEmpty) ? selectedSize! : 'Default',
                  color: (selectedColor != null && selectedColor!.isNotEmpty) ? selectedColor! : 'Default',
                  price: double.tryParse(pController.text),
                  stock: qty,
                  storageLocations: [ProductStorageLocation(warehouseName: 'المخزن الرئيسي', quantity: qty)],
                )];
                Navigator.pop(ctx);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoSection({
    required ValueNotifier<String?> videoUrl,
    required ValueNotifier<bool> isUploading,
    required String tenantId,
    required BuildContext context,
    required WidgetRef ref,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.video_library_rounded, color: Colors.indigo, size: 20),
              const SizedBox(width: 8),
              const Text('فيديو المنتج الترويجي (Video Motion):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const Spacer(),
              if (videoUrl.value != null && videoUrl.value!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
                  child: const Text('مرفوع ومفعل ✅', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (videoUrl.value != null && videoUrl.value!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_fill, color: Colors.indigo, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      videoUrl.value!,
                      style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'إزالة الفيديو',
                    onPressed: () => videoUrl.value = null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (isUploading.value) ...[
            const Row(
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('جاري رفع الفيديو إلى السحابة... يرجى الانتظار', style: TextStyle(fontSize: 12, color: Colors.indigo)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file_rounded),
                label: const Text('رفع فيديو من الجهاز 📤'),
                onPressed: isUploading.value
                    ? null
                    : () async {
                        try {
                          isUploading.value = true;
                          final url = await ref.read(storageServiceProvider).pickAndUploadVideo(tenantId: tenantId);
                          if (url != null) {
                            videoUrl.value = url;
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم رفع الفيديو وتعيينه للمنتج بنجاح!'), backgroundColor: Colors.green),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('فشل رفع الفيديو: $e'), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          isUploading.value = false;
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey(videoUrl.value ?? 'empty_pos_video'),
            initialValue: videoUrl.value ?? '',
            decoration: InputDecoration(
              labelText: 'أو الصق رابط الفيديو المباشر (URL)',
              hintText: 'https://.../video.mp4',
              prefixIcon: const Icon(Icons.link, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (val) {
              videoUrl.value = val.trim().isEmpty ? null : val.trim();
            },
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
          title: const Text('عرض مميز (Featured Deal)'),
          subtitle: const Text('سيظهر في الشريط الإعلاني العلوي'),
          value: isFeaturedDeal.value,
          onChanged: (v) => isFeaturedDeal.value = v,
          secondary: Icon(Icons.star, color: Colors.amber.shade400),
        ),
        SwitchListTile(
          title: const Text('عرض اليوم المميز (Daily Starred)'),
          subtitle: const Text('تمييز المنتج لليوم الحالي'),
          value: isDailyStarred.value,
          onChanged: (v) => isDailyStarred.value = v,
          secondary: Icon(Icons.verified, color: Colors.blue.shade400),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade600, size: 24),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildImageGrid(ValueNotifier<List<String>> images, String tenantId, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ...images.value.asMap().entries.map((entry) => Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    margin: const EdgeInsets.only(left: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(entry.value),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 16,
                    child: IconButton(
                      icon: const Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () {
                        images.value = List.from(images.value)..removeAt(entry.key);
                      },
                    ),
                  ),
                ],
              )),
              InkWell(
                onTap: () async {
                  final url = await ref.read(storageServiceProvider).pickAndUploadImage(tenantId: tenantId);
                  if (url != null) {
                    images.value = [...images.value, url];
                  }
                },
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, color: Colors.blue.shade600, size: 32),
                      const SizedBox(height: 8),
                      Text('إضافة صورة', style: TextStyle(color: Colors.blue.shade600, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
