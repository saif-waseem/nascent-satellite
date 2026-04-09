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

      final newProduct = (product ?? ProductModel(
        id: '', tenantId: tenantId, name: '', category: '', description: '', price: 0.0,
      )).copyWith(
        name: nameController.text.trim(),
        description: descriptionController.text.trim(),
        barcode: barcodeController.text.trim(),
        purchasePrice: double.tryParse(purchasePriceController.text) ?? 0.0,
        price: double.tryParse(retailPriceController.text) ?? 0.0,
        wholesalePrice: double.tryParse(wholesalePriceController.text) ?? 0.0,
        stockQuantity: int.tryParse(stockController.text) ?? 0,
        minStockLevel: int.tryParse(minStockController.text) ?? 0,
        unit: unitController.text.trim(),
        category: categoryController.text.trim(),
        expiryDate: expiryDate.value,
        images: images.value,
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
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ المنتج 성공')));
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
                            Expanded(child: TextField(controller: purchasePriceController, decoration: _inputDecoration('سعر الشراء'), keyboardType: TextInputType.number)),
                            const SizedBox(width: 16),
                            Expanded(child: TextField(controller: retailPriceController, decoration: _inputDecoration('سعر البيع (مفرد)'), keyboardType: TextInputType.number)),
                            const SizedBox(width: 16),
                            Expanded(child: TextField(controller: wholesalePriceController, decoration: _inputDecoration('سعر الجملة'), keyboardType: TextInputType.number)),
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
                        
                        _buildSectionHeader('الأحجام والألوان (الأنواع)', Icons.style_outlined),
                        const SizedBox(height: 16),
                        _buildVariantsSection(context, sizes, colors, variants, retailPriceController),
                        const SizedBox(height: 32),
                        const SizedBox(height: 32),

                        _buildSectionHeader('الصور', Icons.image_outlined),
                        const SizedBox(height: 16),
                        _buildImageGrid(images, tenantId, ref),
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
        if (sizes.value.isNotEmpty || colors.value.isNotEmpty)
          OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('إضافة نوع (Variant) بسعر مخصص'),
            onPressed: () => _showAddVariantDialog(context, sizes.value, colors.value, variants, priceController),
          ),
        if (variants.value.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: variants.value.asMap().entries.map((entry) {
              final v = entry.value;
              return Chip(
                label: Text('${v.size ?? ''} - ${v.color ?? ''} : ${v.price ?? 'سعر افتراضي'}'),
                onDeleted: () => variants.value = List.from(variants.value)..removeAt(entry.key),
              );
            }).toList(),
          ),
        ],
      ],
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
                ),
              if (colors.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: selectedColor,
                  items: colors.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => selectedColor = v),
                  decoration: const InputDecoration(labelText: 'اللون'),
                ),
              TextField(controller: pController, decoration: const InputDecoration(labelText: 'السعر لهذا النوع'), keyboardType: TextInputType.number),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            TextButton(onPressed: () {
              variants.value = [...variants.value, ProductVariant(
                size: selectedSize ?? 'Default',
                color: selectedColor ?? 'Default',
                price: double.tryParse(pController.text),
                stock: 0,
              )];
              Navigator.pop(ctx);
            }, child: const Text('إضافة')),
          ],
        ),
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(image: NetworkImage(images.value[i]), fit: BoxFit.cover),
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () => images.value = List.from(images.value)..removeAt(i),
              ),
            ),
          );
        },
      ),
    );
  }
}
