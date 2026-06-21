import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/features/shared/icon_selector_dialog.dart';
import 'package:store_admin/features/shared/media_gallery_dialog.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:go_router/go_router.dart';

class ProductFormScreen extends HookConsumerWidget {
  final ProductModel? product;
  const ProductFormScreen({super.key, this.product});

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon, String? errorText, String? hintText, String? prefixText}) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      errorText: errorText,
      prefixText: prefixText,
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
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final isEditing = product != null;
    
    final nameController = useTextEditingController(text: product?.name);
    final descriptionController = useTextEditingController(text: product?.description);
    
    // Pricing
    final priceController = useTextEditingController(text: product?.price.toString() ?? '');
    final purchasePriceController = useTextEditingController(text: product?.purchasePrice?.toString() ?? '');
    final wholesalePriceController = useTextEditingController(text: product?.wholesalePrice?.toString() ?? '');
    final oldPriceController = useTextEditingController(text: product?.oldPrice?.toString() ?? '');

    // Inventory & Other Retail fields
    final stockController = useTextEditingController(text: product?.stockQuantity.toString() ?? '10');
    final minStockController = useTextEditingController(text: product?.minStockLevel?.toString() ?? '5');
    final barcodeController = useTextEditingController(text: product?.barcode ?? '');
    final unitController = useTextEditingController(text: product?.unit ?? '');

    final images = useState<List<String>>(product?.images ?? []);
    final imageInputController = useTextEditingController();
    final isUploading = useState(false);
    
    // Promotions
    final isOffer = useState(product?.isOffer ?? false);
    final isFeatured = useState(product?.isFeaturedDeal ?? false);
    final isDailyStarred = useState(product?.isDailyStarred ?? false);

    // Variants
    final hasSizes = useState(product?.sizes.isNotEmpty ?? true);
    final hasColors = useState(product?.colors.isNotEmpty ?? true);
    final sizes = useState<List<String>>((product?.sizes ?? []).toSet().toList());
    final colors = useState<List<String>>((product?.colors ?? []).toSet().toList());
    
    final variantsState = useState<Map<String, int>>({});
    
    useEffect(() {
      if (product != null && product!.variants.isNotEmpty) {
        final Map<String, int> initialMap = {};
        for (var v in product!.variants) {
          initialMap['${v.color}-${v.size}'] = v.stock;
        }
        variantsState.value = initialMap;
      }
      return null;
    }, [product]);

    useEffect(() {
      final currentMap = variantsState.value;
      if (currentMap.isEmpty) return;

      final safeSizes = sizes.value.isEmpty ? ['Default'] : sizes.value;
      final safeColors = colors.value.isEmpty ? ['Default'] : colors.value;
      final validKeys = <String>{};
      
      for (final c in safeColors) {
        for (final s in safeSizes) {
          validKeys.add('$c-$s');
        }
      }

      final newMap = Map<String, int>.from(currentMap)
        ..removeWhere((key, _) => !validKeys.contains(key));
      
      if (newMap.length != currentMap.length) {
        variantsState.value = newMap;
      }
      return null;
    }, [sizes.value, colors.value]);
    
    final sizeInputController = useTextEditingController();
    final colorInputController = useTextEditingController();
    
    final asyncCategories = ref.watch(adminCategoriesProvider);
    final selectedCategory = useState<String>(product?.category ?? 'All');

    Widget buildSectionHeader(String title, IconData icon) {
      return Row(
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
        ],
      );
    }

    void handleSave() async {
      final tenantId = ref.read(currentTenantIdProvider);
      final name = nameController.text.trim();
      
      if (name.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.get('error', lang)}: ${AppStrings.get('product_name', lang)}'), backgroundColor: Colors.red));
         return;
      }

      if (imageInputController.text.isNotEmpty) {
        images.value = [...images.value, imageInputController.text.trim()];
        imageInputController.clear();
      }

      if (!isEditing) {
        final products = ref.read(adminProductsProvider).value ?? [];
        if (products.any((p) => p.name.toLowerCase() == name.toLowerCase())) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(AppStrings.get('duplicate_product_error', lang)), backgroundColor: Colors.red)
           );
           return;
        }
      }

      final newProduct = ProductModel(
        id: product?.id ?? '',
        tenantId: tenantId,
        name: name,
        category: selectedCategory.value,
        description: descriptionController.text,
        price: double.tryParse(priceController.text) ?? 0.0,
        purchasePrice: double.tryParse(purchasePriceController.text),
        wholesalePrice: double.tryParse(wholesalePriceController.text),
        oldPrice: double.tryParse(oldPriceController.text),
        stockQuantity: int.tryParse(stockController.text) ?? 0,
        minStockLevel: int.tryParse(minStockController.text),
        barcode: barcodeController.text.trim(),
        unit: unitController.text.trim(),
        images: images.value,
        isOffer: isOffer.value,
        isFeaturedDeal: isFeatured.value,
        isDailyStarred: isDailyStarred.value,
        sizes: hasSizes.value ? sizes.value : [],
        colors: hasColors.value ? colors.value : [],
        variants: hasSizes.value || hasColors.value 
            ? _generateVariantsList(hasSizes.value ? sizes.value : [], hasColors.value ? colors.value : [], variantsState.value)
            : [],
        inStock: (int.tryParse(stockController.text) ?? 0) > 0,
        discountPercentage: _calculateDiscountPercentage(
          double.tryParse(oldPriceController.text),
          double.tryParse(priceController.text) ?? 0.0,
        ),
      );

      if (hasSizes.value && sizes.value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('sizes_error', lang)), backgroundColor: Colors.red));
        return;
      }
      if (hasColors.value && colors.value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('colors_error', lang)), backgroundColor: Colors.red));
        return;
      }

      int finalStock = newProduct.stockQuantity;
      if (newProduct.variants.isNotEmpty) {
        finalStock = newProduct.variants.fold(0, (sum, v) => sum + v.stock);
      }

      final refinedProduct = newProduct.copyWith(stockQuantity: finalStock, inStock: finalStock > 0);

      if (refinedProduct.stockQuantity <= 0 && !hasSizes.value && !hasColors.value) {
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('stock_error', lang)), backgroundColor: Colors.red));
         }
         return;
      }

      try {
        if (isEditing) {
          await ref.read(adminFirestoreServiceProvider).updateProduct(refinedProduct, tenantId);
        } else {
          await ref.read(adminFirestoreServiceProvider).addProduct(refinedProduct, tenantId);
        }
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('save_success', lang))));
          context.go('/products'); 
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.get('error_occurred', lang)}: $e'), backgroundColor: Colors.red));
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(AppStrings.get(isEditing ? 'edit_product' : 'add_product', lang)),
        centerTitle: true,
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
                        buildSectionHeader(AppStrings.get('basic_info', lang), Icons.info_outline),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameController,
                          decoration: _inputDecoration(AppStrings.get('product_name', lang)),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: barcodeController,
                                decoration: _inputDecoration(
                                  AppStrings.get('barcode', lang),
                                  hintText: AppStrings.get('barcode_hint', lang),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.refresh, color: Colors.blue),
                                    tooltip: AppStrings.get('generate_barcode', lang),
                                    onPressed: () {
                                      barcodeController.text = DateTime.now().millisecondsSinceEpoch.toString();
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: descriptionController,
                                decoration: _inputDecoration(AppStrings.get('description', lang)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        buildSectionHeader(AppStrings.get('pricing_inventory', lang), Icons.inventory_2_outlined),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: purchasePriceController, decoration: _inputDecoration(AppStrings.get('purchase_price', lang)), keyboardType: TextInputType.number)),
                            const SizedBox(width: 16),
                            Expanded(child: TextField(controller: priceController, decoration: _inputDecoration(AppStrings.get('price', lang)), keyboardType: TextInputType.number)),
                            const SizedBox(width: 16),
                            Expanded(child: TextField(controller: wholesalePriceController, decoration: _inputDecoration(AppStrings.get('wholesale_price', lang)), keyboardType: TextInputType.number)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: TextField(controller: stockController, decoration: _inputDecoration(AppStrings.get('stock', lang)), keyboardType: TextInputType.number)),
                            const SizedBox(width: 16),
                            Expanded(child: TextField(controller: minStockController, decoration: _inputDecoration(AppStrings.get('min_stock_level', lang)), keyboardType: TextInputType.number)),
                            const SizedBox(width: 16),
                            Expanded(child: TextField(controller: unitController, decoration: _inputDecoration(AppStrings.get('unit', lang), hintText: AppStrings.get('unit_hint', lang)))),
                          ],
                        ),
                        const SizedBox(height: 32),

                        buildSectionHeader(AppStrings.get('categories_label', lang), Icons.category_outlined),
                        const SizedBox(height: 16),
                        asyncCategories.when(
                          data: (categories) => DropdownButtonFormField<String>(
                            value: categories.any((c) => c.id == selectedCategory.value) ? selectedCategory.value : (categories.isNotEmpty ? categories.first.id : 'All'),
                            onChanged: (v) => selectedCategory.value = v ?? 'All',
                            items: [
                              DropdownMenuItem(value: 'All', child: Text(AppStrings.get('all', lang))),
                              ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                            ],
                            decoration: _inputDecoration(AppStrings.get('categories_label', lang)),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (err, _) => Text('${AppStrings.get('error', lang)}: $err'),
                        ),
                        const SizedBox(height: 32),
                        
                        buildSectionHeader(AppStrings.get('product_images_label', lang), Icons.image_outlined),
                        const SizedBox(height: 16),
                        _buildVariantSection(
                          context: context,
                          ref: ref,
                          title: '',
                          controller: imageInputController,
                          list: images,
                          hint: AppStrings.get('image_hint', lang),
                          isImage: true,
                          isUploading: isUploading,
                          lang: lang,
                        ),
                        const SizedBox(height: 32),
                        
                        buildSectionHeader(AppStrings.get('advanced_options', lang), Icons.settings_outlined),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: Text(AppStrings.get('featured_deal', lang)),
                          subtitle: Text(AppStrings.get('featured_deal_subtitle', lang)),
                          value: isFeatured.value,
                          onChanged: (v) => isFeatured.value = v,
                        ),
                        SwitchListTile(
                          title: Text(AppStrings.get('daily_starred', lang)),
                          subtitle: Text(AppStrings.get('daily_starred_subtitle', lang)),
                          value: isDailyStarred.value,
                          onChanged: (v) => isDailyStarred.value = v,
                        ),
                        SwitchListTile(
                          title: Text(AppStrings.get('mega_sale', lang)),
                          value: isOffer.value,
                          onChanged: (v) => isOffer.value = v,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: oldPriceController,
                          decoration: _inputDecoration(
                            AppStrings.get('old_price', lang),
                            hintText: AppStrings.get('old_price_hint', lang),
                            prefixText: '${AppStrings.get('currency_unit', lang)} ',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        Builder(
                          builder: (context) {
                            final oldPriceText = oldPriceController.text;
                            final priceText = priceController.text;
                            final oldPrice = double.tryParse(oldPriceText);
                            final currentPrice = double.tryParse(priceText);
                            
                            if (oldPrice != null && currentPrice != null && oldPrice > currentPrice) {
                              final discountPercent = ((oldPrice - currentPrice) / oldPrice * 100).round();
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.local_offer, color: Colors.green),
                                      const SizedBox(width: 12),
                                      Text(AppStrings.get('discount_percent', lang).replaceFirst('{percent}', discountPercent.toString()), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                                      const SizedBox(width: 8),
                                      Text(AppStrings.get('auto_calculated', lang), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(height: 32),

                        buildSectionHeader('${AppStrings.get('sizes_label', lang)} & ${AppStrings.get('colors_label', lang)}', Icons.style_outlined),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  SwitchListTile(
                                    title: Text(AppStrings.get('enable_sizes', lang)),
                                    value: hasSizes.value,
                                    onChanged: (v) {
                                      hasSizes.value = v;
                                      if (!v) sizes.value = [];
                                    },
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  if (hasSizes.value)
                                    _buildVariantSection(context: context, ref: ref, title: '', controller: sizeInputController, list: sizes, hint: AppStrings.get('sizes_hint', lang), lang: lang),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                children: [
                                  SwitchListTile(
                                    title: Text(AppStrings.get('enable_colors', lang)),
                                    value: hasColors.value,
                                    onChanged: (v) {
                                      hasColors.value = v;
                                      if (!v) colors.value = [];
                                    },
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  if (hasColors.value)
                                    _buildVariantSection(context: context, ref: ref, title: '', controller: colorInputController, list: colors, hint: AppStrings.get('colors_hint', lang), lang: lang),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _InventoryTable(sizes: sizes.value, colors: colors.value, variantsState: variantsState, lang: lang),
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
                          onPressed: () => context.pop(),
                          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: Text(AppStrings.get('cancel', lang)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: handleSave,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(AppStrings.get(isEditing ? 'update_product' : 'save_product', lang)),
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

  Widget _buildVariantSection({
    required BuildContext context,
    required WidgetRef ref,
    required String title,
    required TextEditingController controller,
    required ValueNotifier<List<String>> list,
    required String hint,
    required String lang,
    bool isImage = false,
    ValueNotifier<bool>? isUploading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: hint, 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
            if (isImage) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () async {
                  final code = await showDialog<String>(context: context, builder: (ctx) => const IconSelectorDialog());
                  if (code != null) controller.text = code;
                },
                icon: const Icon(Icons.image_search),
              ),
               const SizedBox(width: 8),
               IconButton.filledTonal(
                tooltip: AppStrings.get('upload_image', lang),
                onPressed: (isUploading?.value ?? false) ? null : () async {
                  if (isUploading != null) isUploading.value = true;
                  try {
                    final url = await ref.read(storageServiceProvider).pickAndUploadImage('products');
                    if (url != null) {
                       list.value = [...list.value, url];
                       if (context.mounted) {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('image_uploaded', lang))));
                       }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('upload_failed', lang).replaceFirst('{error}', e.toString())), backgroundColor: Colors.red));
                    }
                  } finally {
                    if (isUploading != null) isUploading.value = false;
                  }
                },
                icon: (isUploading?.value ?? false) 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file),
              ),
               const SizedBox(width: 8),
               IconButton.filledTonal(
                onPressed: () async {
                  final url = await showDialog<String>(context: context, builder: (ctx) => const MediaGalleryDialog());
                  if (url != null) controller.text = url;
                },
                icon: const Icon(Icons.photo_library),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: (isUploading?.value ?? false) ? null : () async {
                   if (isUploading != null) isUploading.value = true;
                   try {
                     final urls = await ref.read(storageServiceProvider).pickAndUploadMultipleImages('products');
                     if (urls.isNotEmpty) {
                        list.value = [...list.value, ...urls];
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('images_added', lang).replaceFirst('{count}', urls.length.toString()))));
                        }
                     }
                   } finally {
                     if (isUploading != null) isUploading.value = false;
                   }
                },
                icon: const Icon(Icons.add_photo_alternate),
                tooltip: AppStrings.get('multi_upload', lang),
              ),
            ],
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  final val = controller.text.trim();
                  if (!list.value.contains(val)) {
                    list.value = [...list.value, val];
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('item_exists', lang).replaceFirst('{val}', val))));
                    }
                  }
                  controller.clear();
                }
              },
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: isImage ? 80 : 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: list.value.map((v) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: isImage 
                ? Stack(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey[300]!), borderRadius: BorderRadius.circular(8)),
                        child: Center(
                          child: (v.startsWith('http') || v.startsWith('https') || v.contains('/')) 
                            ? Image.network(v, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error_outline, color: Colors.orange))
                            : Icon(IconData(int.tryParse(v) ?? 58900, fontFamily: 'MaterialIcons'), size: 30),
                        ),
                      ),
                      Positioned(
                        top: -10,
                        right: -10,
                        child: IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                          onPressed: () => list.value = list.value.where((x) => x != v).toList(),
                        ),
                      ),
                    ],
                  )
                : Chip(
                    label: Text(v),
                    onDeleted: () => list.value = list.value.where((x) => x != v).toList(),
                  ),
            )).toList(),
          ),
        ),
      ],
    );
  }

  List<ProductVariant> _generateVariantsList(List<String> sizes, List<String> colors, Map<String, int> stockMap) {
    if (sizes.isEmpty && colors.isEmpty) return [];

    final List<ProductVariant> variants = [];
    final safeSizes = sizes.isEmpty ? ['Default'] : sizes;
    final safeColors = colors.isEmpty ? ['Default'] : colors;

    for (var color in safeColors) {
      for (var size in safeSizes) {
        final key = '$color-$size';
        final stock = stockMap[key] ?? 0;
        variants.add(ProductVariant(color: color, size: size, stock: stock));
      }
    }
    return variants;
  }

  int? _calculateDiscountPercentage(double? oldPrice, double currentPrice) {
    if (oldPrice == null || oldPrice <= currentPrice) return null;
    return ((oldPrice - currentPrice) / oldPrice * 100).round();
  }
}

class _InventoryTable extends StatelessWidget {
  final List<String> sizes;
  final List<String> colors;
  final ValueNotifier<Map<String, int>> variantsState;
  final String lang;

  const _InventoryTable({
    required this.sizes,
    required this.colors,
    required this.variantsState,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    if (sizes.isEmpty && colors.isEmpty) return const SizedBox.shrink();

    final safeSizes = sizes.isEmpty ? [AppStrings.get('default_variant', lang)] : sizes;
    final safeColors = colors.isEmpty ? [AppStrings.get('default_variant', lang)] : colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppStrings.get('inventory_by_variant', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Badge(label: SizedBox.shrink(), child: Icon(Icons.inventory_2, color: Colors.blue, size: 20)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(AppStrings.get('color_label', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text(AppStrings.get('size_label', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                    Expanded(flex: 3, child: Text(AppStrings.get('stock_label', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
              const Divider(height: 1),
              ValueListenableBuilder<Map<String, int>>(
                valueListenable: variantsState,
                builder: (context, currentMap, _) {
                  return Column(
                    children: safeColors.expand((displayColor) {
                      return safeSizes.map((displaySize) {
                        final internalColor = colors.isEmpty ? 'Default' : displayColor;
                        final internalSize = sizes.isEmpty ? 'Default' : displaySize;
                        final key = '$internalColor-$internalSize';
                        final currentStock = currentMap[key] ?? 0;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text(displayColor)),
                              Expanded(flex: 2, child: Text(displaySize)),
                              Expanded(
                                flex: 3,
                                child: _StockInputField(
                                  key: ValueKey(key),
                                  initialValue: currentStock,
                                  onChanged: (val) {
                                    final newMap = Map<String, int>.from(variantsState.value);
                                    newMap[key] = val;
                                    variantsState.value = newMap;
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      });
                    }).toList(),
                  );
                }
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class _StockInputField extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;

  const _StockInputField({super.key, required this.initialValue, required this.onChanged});

  @override
  State<_StockInputField> createState() => _StockInputFieldState();
}

class _StockInputFieldState extends State<_StockInputField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: (val) {
        final newStock = int.tryParse(val) ?? 0;
        widget.onChanged(newStock);
      },
    );
  }
}


