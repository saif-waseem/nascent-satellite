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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final isEditing = product != null;
    
    final nameController = useTextEditingController(text: product?.name);
    final descriptionController = useTextEditingController(text: product?.description);
    final priceController = useTextEditingController(text: product?.price.toString());
    final stockController = useTextEditingController(text: product?.stockQuantity.toString() ?? '10');
    
    final images = useState<List<String>>(product?.images ?? []);
    final imageInputController = useTextEditingController();
    final isUploading = useState(false);
    
    final isOffer = useState(product?.isOffer ?? false);
    final hasSizes = useState(product?.sizes.isNotEmpty ?? true);
    final hasColors = useState(product?.colors.isNotEmpty ?? true);
    final sizes = useState<List<String>>((product?.sizes ?? []).toSet().toList());
    final colors = useState<List<String>>((product?.colors ?? []).toSet().toList());
    
    // Initialize variants state
    // We need a map of "Color-Size" -> Stock
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

    // Cleanup stale variants when sizes/colors change
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
    
    // NEW: Promotion fields
    final isFeatured = useState(product?.isFeaturedDeal ?? false);
    final isDailyStarred = useState(product?.isDailyStarred ?? false);
    final oldPriceController = useTextEditingController(text: product?.oldPrice?.toString());
    
    final asyncCategories = ref.watch(adminCategoriesProvider);
    final selectedCategory = useState<String>(product?.category ?? 'All');

    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.get(isEditing ? 'edit_product' : 'add_product', lang)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: AppStrings.get('product_name', lang), 
                border: const OutlineInputBorder()
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: AppStrings.get('description', lang), 
                border: const OutlineInputBorder()
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('price', lang), 
                      border: const OutlineInputBorder(), 
                      prefixText: '${AppStrings.get('currency_unit', lang)} '
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: stockController,
                    decoration: InputDecoration(
                      labelText: AppStrings.get('stock', lang), 
                      border: const OutlineInputBorder()
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            asyncCategories.when(
              data: (categories) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.get('categories_label', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: categories.any((c) => c.id == selectedCategory.value) ? selectedCategory.value : (categories.isNotEmpty ? categories.first.id : 'All'),
                    onChanged: (v) => selectedCategory.value = v ?? 'All',
                    items: [
                      DropdownMenuItem(value: 'All', child: Text(AppStrings.get('all', lang))),
                      ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              loading: () => const LinearProgressIndicator(),
              error: (err, _) => Text('${AppStrings.get('error_prefix', lang)} $err'),
            ),
            const SizedBox(height: 24),
            _buildVariantSection(
              context: context,
              ref: ref,
              title: AppStrings.get('product_images_label', lang),
              controller: imageInputController,
              list: images,
              hint: AppStrings.get('image_hint', lang),
              isImage: true,
              isUploading: isUploading,
              lang: lang,
            ),
            const SizedBox(height: 16),
            
            // NEW: Promotion Section
            const Divider(thickness: 2),
            const SizedBox(height: 8),
            Text(AppStrings.get('product_promotion', lang), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
            const SizedBox(height: 12),
            
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
            
            const SizedBox(height: 16),
            TextField(
              controller: oldPriceController,
              decoration: InputDecoration(
                labelText: AppStrings.get('old_price', lang),
                hintText: AppStrings.get('old_price_hint', lang),
                border: const OutlineInputBorder(),
                helperText: AppStrings.get('old_price_helper', lang),
                prefixText: '${AppStrings.get('currency_unit', lang)} ',
              ),
              keyboardType: TextInputType.number,
            ),
            
            // Auto-calculated discount percentage display
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
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_offer, color: Colors.green),
                          const SizedBox(width: 12),
                          Text(
                            AppStrings.get('discount_percent', lang).replaceFirst('{percent}', discountPercent.toString()),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.get('auto_calculated', lang),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            
            const SizedBox(height: 8),
            const Divider(),
            
            SwitchListTile(
              title: Text(AppStrings.get('mega_sale', lang)),
              value: isOffer.value,
              onChanged: (v) => isOffer.value = v,
            ),
            const Divider(),
            
            _buildVariantSection(
              context: context,
              ref: ref,
              title: AppStrings.get('sizes_label', lang),
              controller: sizeInputController,
              list: sizes,
              hint: AppStrings.get('sizes_hint', lang),
              lang: lang,
            ),
            const SizedBox(height: 16),
            _buildVariantSection(
              context: context,
              ref: ref,
              title: AppStrings.get('colors_label', lang),
              controller: colorInputController,
              list: colors,
              hint: AppStrings.get('colors_hint', lang),
              lang: lang,
            ),
            
            const SizedBox(height: 24),
            const Divider(),

            SwitchListTile(
              title: Text(AppStrings.get('enable_sizes', lang)),
              subtitle: Text(AppStrings.get('enable_sizes_subtitle', lang)),
              value: hasSizes.value,
              onChanged: (v) {
                hasSizes.value = v;
                if (!v) sizes.value = [];
              },
            ),
            SwitchListTile(
              title: Text(AppStrings.get('enable_colors', lang)),
              subtitle: Text(AppStrings.get('enable_colors_subtitle', lang)),
              value: hasColors.value,
              onChanged: (v) {
                hasColors.value = v;
                if (!v) {
                  colors.value = [];
                }
              },
            ),
            
            const SizedBox(height: 24),
            _InventoryTable(
              sizes: sizes.value,
              colors: colors.value,
              variantsState: variantsState,
              lang: lang,
            ),
            
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () async {
                  final tenantId = ref.read(currentTenantIdProvider);
                  final name = nameController.text.trim();
                  
                  // Auto-add image if field is not empty
                  if (imageInputController.text.isNotEmpty) {
                    images.value = [...images.value, imageInputController.text.trim()];
                    imageInputController.clear();
                  }

                  // 1. Duplicate check (if new product)
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
                    stockQuantity: int.tryParse(stockController.text) ?? 0,
                    images: images.value,
                    isOffer: isOffer.value,
                    sizes: hasSizes.value ? sizes.value : [],
                    colors: hasColors.value ? colors.value : [],
                    variants: hasSizes.value || hasColors.value 
                        ? _generateVariantsList(
                            hasSizes.value ? sizes.value : [], 
                            hasColors.value ? colors.value : [], 
                            variantsState.value
                          )
                        : [],
                    inStock: (int.tryParse(stockController.text) ?? 0) > 0,
                    // NEW: Promotion fields
                    isFeaturedDeal: isFeatured.value,
                    isDailyStarred: isDailyStarred.value,
                    oldPrice: double.tryParse(oldPriceController.text),
                    discountPercentage: _calculateDiscountPercentage(
                      double.tryParse(oldPriceController.text),
                      double.tryParse(priceController.text) ?? 0.0,
                    ),
                  );

                  // Validation: If sizes/colors are enabled, they shouldn't be empty
                  if (hasSizes.value && sizes.value.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('sizes_error', lang)), backgroundColor: Colors.red));
                    return;
                  }
                  if (hasColors.value && colors.value.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('colors_error', lang)), backgroundColor: Colors.red));
                    return;
                  }

                  // If variants exist, the total stock must match the sum of variants
                  int finalStock = newProduct.stockQuantity;
                  if (newProduct.variants.isNotEmpty) {
                    finalStock = newProduct.variants.fold(0, (sum, v) => sum + v.stock);
                  }

                  final refinedProduct = newProduct.copyWith(
                    stockQuantity: finalStock,
                    inStock: finalStock > 0,
                  );

                  // Validation: Ensure stock is > 0
                  if (refinedProduct.stockQuantity <= 0 && !hasSizes.value && !hasColors.value) {
                     if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text(AppStrings.get('stock_error', lang)), backgroundColor: Colors.red)
                       );
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${AppStrings.get('error_occurred', lang)}: $e'), backgroundColor: Colors.red)
                      );
                    }
                  }
                },
                child: Text(AppStrings.get('save', lang)),
              ),
            ),
          ],
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
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
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
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                color: Colors.grey.shade100,
                padding: const EdgeInsets.all(8),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onChanged: (val) {
        final newStock = int.tryParse(val) ?? 0;
        widget.onChanged(newStock);
      },
    );
  }
}


