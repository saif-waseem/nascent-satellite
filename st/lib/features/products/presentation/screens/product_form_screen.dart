import 'package:shared_models/src/widgets/product_entry_options.dart';
import 'package:shared_ui/product_promo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/features/products/presentation/widgets/ai_video_generator_dialog.dart';
import 'package:store_admin/features/shared/barcode_scanner_dialog.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

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

    final productId = useMemoized(
      () => product?.id ?? ref.read(adminFirestoreServiceProvider).newProductId(),
      [tenantId, product?.id],
    );
    final nameController = useTextEditingController(text: product?.name ?? '');
    final barcodeController = useTextEditingController(text: product?.barcode ?? '');
    final purchasePriceController = useTextEditingController(text: product?.purchasePrice?.toString() ?? '');
    final retailPriceController = useTextEditingController(text: product?.price.toString() ?? '');
    final secondaryPriceController = useTextEditingController(text: product?.secondaryPrice != null ? product!.secondaryPrice.toString() : '');
    final secondaryCurrency = useState<String?>(product?.secondaryCurrency ?? '\$');
    final wholesalePriceController = useTextEditingController(text: product?.wholesalePrice?.toString() ?? '');
    final stockController = useTextEditingController(text: product?.stockQuantity.toString() ?? '0');
    final minStockController = useTextEditingController(text: product?.minStockLevel?.toString() ?? '5');
    final unitController = useTextEditingController(text: product?.unit ?? 'قطعة');
    final categoryController = useTextEditingController(text: product?.category ?? 'عام');
    final descriptionController = useTextEditingController(text: product?.description ?? '');
    
    final images = useState<List<String>>(product?.images ?? []);
    final videoUrl = useState<String?>(product?.videoUrl);
    final isUploadingVideo = useState<bool>(false);
    final variants = useState<List<ProductVariant>>(product?.variants ?? []);
    
    final advanced = useState(false);
    final colors = useState(entryValues([...?product?.colors, ...?product?.variants.map((v)=>v.color)]));
    final sizes = useState(entryValues([...?product?.sizes, ...?product?.variants.map((v)=>v.size)]));
    final useColors = useState(colors.value.isNotEmpty);
    final useSizes = useState(sizes.value.isNotEmpty);

    void changeOption(bool isColor, List<String> next) => changeEntryOption(
        context, isColor, next, colors:colors, sizes:sizes, variants:variants,
        useColors:useColors.value,useSizes:useSizes.value,baseStock:int.tryParse(stockController.text)??0);
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

      late List<ProductVariant> savedVariants;
      try {
        savedVariants = entryVariants(variants.value, useColors.value, useSizes.value);
      } on FormatException catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
      final totalStock = savedVariants.isEmpty ? int.tryParse(stockController.text) ?? 0
          : savedVariants.fold<int>(0,(sum,v)=>sum+v.stock);
      final newProduct = (product ?? ProductModel(
        id: productId, tenantId: tenantId, name: '', category: '', description: '', price: 0.0,
      )).copyWith(
        name: nameController.text.trim(),
        description: descriptionController.text.trim(),
        barcode: barcodeController.text.trim(),
        purchasePrice: double.tryParse(purchasePriceController.text) ?? 0.0,
        price: double.tryParse(retailPriceController.text) ?? 0.0,
        secondaryPrice: double.tryParse(secondaryPriceController.text),
        secondaryCurrency: secondaryPriceController.text.isNotEmpty ? secondaryCurrency.value : null,
        wholesalePrice: double.tryParse(wholesalePriceController.text) ?? 0.0,
        stockQuantity: totalStock,
        minStockLevel: int.tryParse(minStockController.text) ?? 0,
        unit: unitController.text.trim(),
        category: categoryController.text.trim(),
        images: images.value,
        videoUrl: videoUrl.value,
        sizes: useSizes.value ? entryValues([...sizes.value,...savedVariants.map((v)=>v.size)]) : [],
        colors: useColors.value ? entryValues([...colors.value,...savedVariants.map((v)=>v.color)]) : [],
        variants: savedVariants,
        isOffer: isOffer.value,
        isFeaturedDeal: isFeaturedDeal.value,
        isDailyStarred: isDailyStarred.value,
        inStock: totalStock > 0,
      );

      try {
        isLoading.value = true;
        await ref.read(adminSupabaseServiceProvider).saveProduct(newProduct, tenantId, previousStock: product?.stockQuantity);
        
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
        backgroundColor: const Color(0xff428345), foregroundColor: Colors.white,
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
              child: Material(type: MaterialType.transparency, child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(isMobile ? 16 : 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ProductEntryMode(advanced: advanced.value, onChanged: (v)=>advanced.value=v),
                        const SizedBox(height:16),
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
                          TextField(controller: descriptionController, decoration: _inputDecoration('وصف المنتج'), maxLines: 2),
                        ProductOptionValues(label:'الأصناف / الألوان',values:colors.value,enabled:useColors.value,
                          onToggle:(v)=>useColors.value=v,onChange:(v)=>changeOption(true,v)),
                        ProductOptionValues(label:'الأحجام',values:sizes.value,enabled:useSizes.value,
                          onToggle:(v)=>useSizes.value=v,onChange:(v)=>changeOption(false,v)),
                        const SizedBox(height:16),
                        if(!advanced.value) ...[
                          const SizedBox(height: 16),
                          _buildSectionHeader('الأسعار والمخزون الأولي', Icons.price_change_outlined),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: purchasePriceController,
                                  decoration: _inputDecoration('سعر الشراء (التكلفة)'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: retailPriceController,
                                  decoration: _inputDecoration('سعر البيع'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: stockController,
                                  decoration: _inputDecoration('الكمية الأولية (المخزون)'),
                                  keyboardType: TextInputType.number,
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
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: secondaryPriceController,
                                  decoration: _inputDecoration('سعر إضافي (عملة ثانوية - اختياري)'),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: ['\$', 'د.ع', 'ر.س', 'AED', 'EUR'].contains(secondaryCurrency.value) ? secondaryCurrency.value : '\$',
                                  decoration: _inputDecoration('العملة'),
                                  items: const [
                                    DropdownMenuItem(value: '\$', child: Text('\$ دولار')),
                                    DropdownMenuItem(value: 'د.ع', child: Text('د.ع دينار')),
                                    DropdownMenuItem(value: 'ر.س', child: Text('ر.س ريال')),
                                    DropdownMenuItem(value: 'AED', child: Text('AED درهم')),
                                    DropdownMenuItem(value: 'EUR', child: Text('€ يورو')),
                                  ],
                                  onChanged: (val) => secondaryCurrency.value = val,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if(advanced.value)...[
                        _buildSectionHeader('المخزون والأسعار', Icons.inventory_2_outlined),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                initialValue: variants.value.isEmpty ? null : variants.value.fold<int>(0,(n,v)=>n+entryStock(v)).toString(),
                                controller: variants.value.isEmpty ? stockController : null,
                                key: ValueKey((variants.value.isEmpty, variants.value.fold<int>(0,(n,v)=>n+entryStock(v)))),
                                  decoration: _inputDecoration('الكمية الإجمالية'),
                                  keyboardType: TextInputType.number,
                                  readOnly: variants.value.isNotEmpty,
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
                             const SizedBox(height: 16),
                             Row(
                               children: [
                                 Expanded(
                                   flex: 3,
                                   child: TextField(
                                     controller: secondaryPriceController,
                                     decoration: _inputDecoration('سعر إضافي (عملة أخرى)'),
                                     keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 Expanded(
                                   flex: 2,
                                   child: DropdownButtonFormField<String>(
                                     value: ['\$', 'د.ع', 'ر.س', 'AED', 'EUR'].contains(secondaryCurrency.value) ? secondaryCurrency.value : '\$',
                                     decoration: _inputDecoration('العملة'),
                                     items: const [
                                       DropdownMenuItem(value: '\$', child: Text('\$ دولار')),
                                       DropdownMenuItem(value: 'د.ع', child: Text('د.ع دينار')),
                                       DropdownMenuItem(value: 'ر.س', child: Text('ر.س ريال')),
                                       DropdownMenuItem(value: 'AED', child: Text('AED درهم')),
                                       DropdownMenuItem(value: 'EUR', child: Text('€ يورو')),
                                     ],
                                     onChanged: (val) => secondaryCurrency.value = val,
                                   ),
                                 ),
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
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    controller: secondaryPriceController,
                                    decoration: _inputDecoration('سعر إضافي'),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 100,
                                  child: DropdownButtonFormField<String>(
                                    value: ['\$', 'د.ع', 'ر.س', 'AED', 'EUR'].contains(secondaryCurrency.value) ? secondaryCurrency.value : '\$',
                                    decoration: _inputDecoration('العملة'),
                                    items: const [
                                      DropdownMenuItem(value: '\$', child: Text('\$')),
                                      DropdownMenuItem(value: 'د.ع', child: Text('د.ع')),
                                      DropdownMenuItem(value: 'ر.س', child: Text('ر.س')),
                                      DropdownMenuItem(value: 'AED', child: Text('AED')),
                                      DropdownMenuItem(value: 'EUR', child: Text('€')),
                                    ],
                                    onChanged: (val) => secondaryCurrency.value = val,
                                  ),
                                ),
                              ],
                            ),
                          ],
                      const SizedBox(height: 32),
                      Wrap(children:[TextButton.icon(icon:const Icon(Icons.add),label:const Text('إضافة صف للمخزون'),
                          onPressed:() => _showAddVariantDialog(context,variants,useColors.value,useSizes.value,colors,sizes))]),
                        EntryInventoryTable(variants:variants.value,onEdit:(i)=>editEntryLocations(context,variants,i),
                          onPrice:(i)=>editVariantPrice(context,variants,i),onRemove:(i)=>variants.value=List.of(variants.value)..removeAt(i)),
                        ],
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

                      const SizedBox(height: 24),
                      const Text('صور المنتج:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 12),
                      _buildImageGrid(images, tenantId, ref),
                      const SizedBox(height: 24),
                      _buildVideoSection(
                        videoUrl: videoUrl,
                        isUploading: isUploadingVideo,
                        productName: nameController.text,
                        price: double.tryParse(retailPriceController.text) ?? 0.0,
                        images: images.value,
                        description: descriptionController.text,
                        tenantId: tenantId,
                        context: context,
                        ref: ref,
                      ),
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
                child: Wrap( alignment: WrapAlignment.end, children: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
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
      ));
    },
  ),
);
}

  void _showAddVariantDialog(BuildContext context, ValueNotifier<List<ProductVariant>> variants, bool useColors, bool useSizes, ValueNotifier<List<String>> colors, ValueNotifier<List<String>> sizes) {
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
            if(useColors) TextField(controller: colorController, decoration: const InputDecoration(labelText: 'اللون')),
            if(useSizes) TextField(controller: sizeController, decoration: const InputDecoration(labelText: 'الحجم')),
            TextField(controller: quantityController, decoration: const InputDecoration(labelText: 'الكمية'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(onPressed: () {
            final qty = int.tryParse(quantityController.text.trim());
              final color=colorController.text.trim(), size=sizeController.text.trim();
              if(qty==null || qty<0 || (useColors && color.isEmpty) || (useSizes && size.isEmpty) ||
                 variants.value.any((v)=>v.color==(color.isEmpty?'Default':color) && v.size==(size.isEmpty?'Default':size))) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('أدخل كمية صحيحة وتنويعة غير مكررة.')));return;
              }
              if(useColors) colors.value=entryValues([...colors.value,color]);
              if(useSizes) sizes.value=entryValues([...sizes.value,size]);
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
    return Row(children: [Icon(icon, color: Colors.blue.shade700, size: 20), const SizedBox(width: 8), Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))]);
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

  Widget _buildVideoSection({
    required ValueNotifier<String?> videoUrl,
    required ValueNotifier<bool> isUploading,
    required String productName,
    required double price,
    required List<String> images,
    required String description,
    required String tenantId,
    required BuildContext context,
    required WidgetRef ref,
  }) {
    final tenant = ref.watch(tenantProvider).value;
    final currency = tenant?.currencyUnit ?? 'IQD';

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
              const Text('إعلان المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (videoUrl.value != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)),
                  child: const Text('تم اختياره', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (videoUrl.value != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_fill, color: Colors.indigo, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ProductPromo.styleOf(videoUrl.value) != null ? 'إعلان من صور المنتج' : videoUrl.value!,
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
                          final url = await ref.read(storageServiceProvider).pickAndUploadVideo();
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
              FilledButton.icon(
                icon: const Icon(Icons.auto_awesome),
                label: const Text('إنشاء إعلان من صور المنتج'),
                style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                onPressed: () {
                  final dummyProduct = ProductModel(
                    id: '',
                    tenantId: tenantId,
                    name: productName.isNotEmpty ? productName : 'منتج جديد',
                    price: price,
                    category: 'عام',
                    description: description,
                    rating: 5.0,
                    isOffer: false,
                    inStock: true,
                    images: images,
                    sizes: const [],
                    colors: const [],
                    stockQuantity: 10,
                    salesCount: 0,
                    variants: const [],
                  );

                  showDialog(
                    context: context,
                    builder: (ctx) => AiVideoGeneratorDialog(
                      product: dummyProduct,
                      currency: currency,
                      onVideoAssigned: (generatedUrl) {
                        videoUrl.value = generatedUrl;
                      },
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey(videoUrl.value ?? 'empty_video'),
            initialValue: ProductPromo.styleOf(videoUrl.value) == null ? videoUrl.value ?? '' : '',
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
}
