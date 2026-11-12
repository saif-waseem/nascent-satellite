import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:user_app/features/shared/providers.dart';
import 'package:user_app/core/utils/formatters.dart';
import 'package:shared_models/shared_models.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:user_app/core/utils/animations.dart';
import 'package:user_app/features/shared/widgets/optimized_image.dart';


class ProductDetailsScreen extends ConsumerStatefulWidget {
  final ProductModel? product;
  const ProductDetailsScreen({super.key, this.product});

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _quantity = 1;
  final GlobalKey _cartKey = GlobalKey();
  String? _selectedColor;
  String? _selectedSize;
  int _currentImageIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Initial call
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSelection();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _initializeSelection() {
    final item = widget.product;
    if (item == null) return;

    setState(() {
      // 1. Initial candidates (visible colors/sizes)
      final visibleColors = item.colors.where((c) => c != 'Default' && c != 'none').toList();
      final visibleSizes = item.sizes.where((s) => s != 'Default' && s != 'none').toList();

      // 2. Try to find first color-size combination WITH stock
      bool found = false;
      if (item.variants.isNotEmpty) {
        for (var v in item.variants) {
          if (v.stock > 0) {
            _selectedColor = v.color;
            _selectedSize = v.size;
            found = true;
            break;
          }
        }
      }

      // 3. Fallback if no variant found with stock or no variants defined
      if (!found) {
        if (visibleColors.isNotEmpty) {
          _selectedColor = visibleColors.first;
        } else if (item.colors.contains('Default')) {
          _selectedColor = 'Default';
        }

        if (visibleSizes.isNotEmpty) {
          _selectedSize = visibleSizes.first;
        } else if (item.sizes.contains('Default')) {
          _selectedSize = 'Default';
        }
      }
      
      // 4. Update quantity based on selection
      if (_selectedColor != null && _selectedSize != null) {
        final stock = _getStockFor(_selectedColor!, _selectedSize!, item.variants);
        _quantity = stock > 0 ? 1 : 0;
      } else {
        _quantity = item.stockQuantity > 0 ? 1 : 0;
      }
    });
  }



  // Inventory Helper
  int _getStockFor(String color, String size, List<ProductVariant> variants) {
    if (variants.isEmpty) return widget.product?.stockQuantity ?? 0;
    try {
      // Try exact match first
      return variants.firstWhere((v) => v.color == color && v.size == size).stock;
    } catch (_) {
      try {
        // Try matching with 'Default' if exact match fails
        return variants.firstWhere((v) => 
          (v.color == color || v.color == 'Default') && 
          (v.size == size || v.size == 'Default')
        ).stock;
      } catch (_) {
        // Fallback to main stock if searching for Default and not found in variants
        if (color == 'Default' && size == 'Default') {
          return widget.product?.stockQuantity ?? 0;
        }
        return 0;
      }
    }
  }

  bool _isVariantAvailable(String color, String size, List<ProductVariant> variants) {
    if (variants.isEmpty) return (widget.product?.stockQuantity ?? 0) > 0;
    
    // Check if this specific combo OR its 'Default' fallbacks have stock
    final v = variants.where((v) => 
      (v.color == color || v.color == 'Default' || color == 'Default') && 
      (v.size == size || v.size == 'Default' || size == 'Default')
    );
    
    if (v.isEmpty && color == 'Default' && size == 'Default') {
      return (widget.product?.stockQuantity ?? 0) > 0;
    }
    
    return v.isNotEmpty && v.any((v) => v.stock > 0);
  }

  double _getRating(String productId, double staticRating, WidgetRef ref) {
    final asyncReviews = ref.watch(productReviewsProvider(productId));
    return asyncReviews.maybeWhen(
      data: (reviews) {
        if (reviews.isEmpty) return staticRating;
        final totalRating = reviews.fold(0.0, (sum, r) => sum + (r['rating'] as num).toDouble());
        return totalRating / reviews.length;
      },
      orElse: () => staticRating,
    );
  }

  double _getCurrentPrice(ProductModel item) {
    if (_selectedColor != null && _selectedSize != null && item.variants.isNotEmpty) {
      try {
        final variant = item.variants.firstWhere(
          (v) => (v.color == _selectedColor || v.color == 'Default' || _selectedColor == 'Default') && 
                 (v.size == _selectedSize || v.size == 'Default' || _selectedSize == 'Default')
        );
        if (variant.price != null && variant.price! > 0) {
          return variant.price!;
        }
      } catch (_) {}
    }
    return item.price;
  }


  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final asyncProducts = ref.watch(productsProvider);
    
    // Attempt to get full product from list if only partial data was passed
    ProductModel item = widget.product ?? const ProductModel(
      id: '999',
      name: 'Unknown Product',
      category: 'All',
      price: 0.0,
      description: 'N/A',
      tenantId: 'default',
    );
    
    // Reactive update for variant initialization
    ref.listen(productsProvider, (previous, next) {
      next.whenData((products) {
        try {
          final full = products.firstWhere((p) => p.id == item.id);
          // If we had no variants before, but now we do, re-initialize
          if ((widget.product == null || widget.product!.variants.isEmpty) && full.variants.isNotEmpty) {
            _initializeSelection();
          }
        } catch (_) {}
      });
    });

    // Derive the most up-to-date item
    item = asyncProducts.maybeWhen(
      data: (products) {
        try {
          return products.firstWhere((p) => p.id == item.id);
        } catch (_) {
          return item;
        }
      },
      orElse: () => item,
    );

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () {
              final tenant = ref.read(tenantProvider).value;
              final categories = ref.read(categoriesProvider).value ?? [];
              final storeName = tenant?.name ?? 'متجرنا';
              
              // Get Category Name instead of ID
              final category = categories.firstWhere(
                (c) => c.id == item.category,
                orElse: () => CategoryModel(id: 'All', name: AppStrings.get('cat_all', lang), icon: ''),
              );

              // Format Colors and Sizes
              final colors = item.colors.where((c) => c != 'Default' && c != 'none').join(', ');
              final sizes = item.sizes.where((s) => s != 'Default' && s != 'none').join(', ');
              
              // GitHub Pages URL for product sharing
              const githubPagesUrl = 'https://saif-waseem.github.io/store';
              final productUrl = '$githubPagesUrl/?p=${item.id}';
              
              // Create share message with product link
              final priceInfo = item.oldPrice != null 
                ? '💰 ${formatCurrency(item.price)} (كان ${formatCurrency(item.oldPrice!)})'
                : '💰 ${formatCurrency(item.price)}';
              
              final msg = '''
🛍️ ${item.name}

📁 القسم: ${category.name}
$priceInfo
${item.discountPercentage != null ? '🏷️ خصم ${item.discountPercentage}%' : ''}
${colors.isNotEmpty ? '🎨 الألوان: $colors' : ''}
${sizes.isNotEmpty ? '📏 المقاسات: $sizes' : ''}

📦 من متجر: $storeName

🔗 شاهد المنتج:
$productUrl

سيفتح التطبيق تلقائياً إذا كان مثبتاً لديك!
''';
              Share.share(msg.trim());

              // Award share points
              final userData = ref.read(userProvider).value;
              if (userData != null) {
                final points = tenant?.sharesRewardPoints ?? 10;
                final limit = tenant?.maxDailySharePoints ?? 50;
                ref.read(firestoreServiceProvider).awardSharePoints(userData.id, points, limit).then((awarded) {
                  if (awarded > 0 && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(AppStrings.get('reward_points_msg', lang).replaceFirst('{points}', awarded.toString()))
                    ));
                  }
                });
              }
            },
            icon: const Icon(Icons.share),
          ),
          Consumer(builder: (context, ref, _) {
            final tenant = ref.watch(tenantProvider).value;
            if (tenant == null || tenant.whatsappNumber.isEmpty) return const SizedBox.shrink();
            return IconButton(
              onPressed: () async {
                var phone = tenant.whatsappNumber.replaceAll(RegExp(r'\D'), '');
                if (phone.startsWith('0')) {
                  phone = '964${phone.substring(1)}';
                }
                final url = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(AppStrings.get('whatsapp_inquiry', lang).replaceFirst('{name}', item.name))}');
                try {
                   await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (e) {
                   if (context.mounted) {
                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('whatsapp_error', lang))));
                   }
                }
              },
              icon: const Icon(Icons.chat, color: Colors.green),
            );
          }),
          Consumer(builder: (context, ref, _) {
            final favorites = ref.watch(favoritesProvider);
            final isFav = favorites.contains(item.id);
            return IconButton(
              onPressed: () {
                 ref.read(favoritesProvider.notifier).toggleFavorite(item.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isFav ? AppStrings.get('remove_item', lang) : AppStrings.get('favorites', lang)))
                  );
              },
              icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null),
            );
          }),
          Consumer(builder: (context, ref, _) {
            final count = ref.watch(cartProvider).length;
             return Badge(
               label: Text('$count'),
               isLabelVisible: count > 0,
                child: IconButton(key: _cartKey, onPressed: () => context.push('/cart'), icon: const Icon(Icons.shopping_cart_outlined)),
             );
          }),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Gallery: Video appears FIRST if present, followed by images
            if (item.videoUrl != null && item.videoUrl!.isNotEmpty) ...[
              // Video Section First
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    height: 380,
                    width: double.infinity,
                    color: Colors.black,
                    child: AdaptiveVideoPlayer(
                      videoUrl: item.videoUrl!,
                      autoPlay: false,
                      looping: true,
                      previewImageUrl: item.images.isNotEmpty ? item.images.first : null,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.videocam, color: Colors.amber, size: 16),
                        SizedBox(width: 4),
                        Text(
                          'فيديو المنتج',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (item.images.isNotEmpty) ...[
                // Horizontal Image Thumbnails gallery when video is shown
                SizedBox(
                  height: 90,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: item.images.length,
                    itemBuilder: (context, idx) {
                      return GestureDetector(
                        onTap: () => _showZoomableImage(context, item.images, idx),
                        child: Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: OptimizedImage(
                            imageUrl: item.images[idx],
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ] else if (item.images.isNotEmpty)
              Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  SizedBox(
                    height: 350,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: item.images.length,
                      onPageChanged: (idx) => setState(() => _currentImageIndex = idx),
                      itemBuilder: (context, index) {
                        return GestureDetector(
                          onTap: () => _showZoomableImage(context, item.images, index),
                          child: Container(
                            width: double.infinity,
                            color: Colors.grey[100],
                            child: OptimizedImage(imageUrl: item.images[index], fit: BoxFit.cover, memCacheWidth: 800),
                          ),
                        );
                      },
                    ),
                  ),
                  if (item.images.length > 1)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: Text('${_currentImageIndex + 1}/${item.images.length}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              )
            else
              Container(
                height: 300,
                width: double.infinity,
                color: Colors.grey[200],
                child: Center(child: OptimizedImage(imageUrl: null)),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Price
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      item.name, 
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  if (item.oldPrice != null && item.oldPrice! > _getCurrentPrice(item)) ...[
                    Row(
                      children: [
                        Text(
                          formatCurrency(item.oldPrice!), 
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey, 
                            decoration: TextDecoration.lineThrough,
                          )
                        ),
                        const SizedBox(width: 8),
                        if (item.discountPercentage != null && item.discountPercentage! > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                            child: Text(
                              '-${item.discountPercentage}%',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],

                  Text(
                    formatCurrency(_getCurrentPrice(item)), 
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: (item.oldPrice != null && item.oldPrice! > _getCurrentPrice(item)) ? Colors.red : Theme.of(context).colorScheme.primary, 
                      fontWeight: FontWeight.bold
                    )
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Rating Section
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Consumer(builder: (context, ref, _) {
                        final currentRating = _getRating(item.id, item.rating, ref);
                        return Text(currentRating.toStringAsFixed(1), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
                      }),
                      const SizedBox(width: 8),
                       Consumer(builder: (context, ref, _) {
                          final allReviews = ref.watch(productReviewsProvider(item.id));
                          final count = allReviews.maybeWhen(
                            data: (reviews) => reviews.length,
                            orElse: () => 0,
                          );
                          return Text(
                            AppStrings.get('reviews_count', lang).replaceFirst('{count}', count.toString()), 
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          );
                       }),
                      const Spacer(),
                       Consumer(builder: (context, ref, _) {
                        final orders = ref.watch(ordersProvider).value ?? [];
                        final hasPurchased = orders.any((o) => o.status == OrderStatus.completed && o.items.any((i) => (i['productId'] ?? i['id']) == item.id));
                        
                        return TextButton.icon(
                          onPressed: () => _showRatingDialog(context, lang), 
                          icon: Icon(hasPurchased ? Icons.verified : Icons.rate_review_outlined, size: 18, color: hasPurchased ? Colors.amber : null),
                          label: Text(AppStrings.get('rate_this', lang)),
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 24),
                  
                  // Variations
                  if (item.colors.isNotEmpty && item.colors.any((c) => c != 'Default')) ...[
                    Text(AppStrings.get('color', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: item.colors.where((c) => c != 'Default').map((c) {
                        bool available = _selectedSize == null || item.variants.isEmpty || _isVariantAvailable(c, _selectedSize!, item.variants);
                        return ChoiceChip(
                          label: Text(c),
                          selected: _selectedColor == c,
                          onSelected: available ? (b) {
                            if (b) {
                              setState(() => _selectedColor = c);
                            } else {
                              setState(() => _selectedColor = null);
                            }
                          } : null,
                          backgroundColor: available ? null : Colors.grey[200],
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (item.sizes.isNotEmpty && item.sizes.any((s) => s != 'Default')) ...[
                    Text(AppStrings.get('size', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: item.sizes.where((s) => s != 'Default').map((s) {
                         bool available = _selectedColor == null || item.variants.isEmpty || _isVariantAvailable(_selectedColor!, s, item.variants);
                         return ChoiceChip(
                           label: Text(s),
                           selected: _selectedSize == s,
                           onSelected: available ? (b) => setState(() => _selectedSize = b ? s : null) : null,
                           backgroundColor: available ? null : Colors.grey[200],
                         );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Quantity
                   Row(
                    children: [
                      Expanded(child: Text(AppStrings.get('quantity_label', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Builder(
                        builder: (context) {
                          final stock = (_selectedColor != null && _selectedSize != null)
                            ? _getStockFor(_selectedColor!, _selectedSize!, item.variants)
                            : item.stockQuantity;
                          return Text(
                            '($stock ${AppStrings.get('qty', lang)})',
                            style: TextStyle(
                              color: stock > 0 ? Colors.grey[600] : Colors.red,
                              fontSize: 12,
                              fontWeight: stock > 0 ? null : FontWeight.bold,
                            ),
                          );
                        }
                      ),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null, 
                        icon: const Icon(Icons.remove)
                      ),
                      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('$_quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
                      IconButton.filledTonal(
                        onPressed: () {
                          final max = (_selectedColor != null && _selectedSize != null) 
                              ? _getStockFor(_selectedColor!, _selectedSize!, item.variants) 
                              : item.stockQuantity;
                          if (_quantity < max) {
                            setState(() => _quantity++);
                          } else if (max > 0 && _quantity > max) {
                             setState(() => _quantity = max);
                          }
                        }, 
                        icon: const Icon(Icons.add)
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),


                  Text(AppStrings.get('description', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    style: TextStyle(color: Colors.grey[700], height: 1.5),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Reviews
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                       Text(AppStrings.get('reviews', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                       TextButton(onPressed: () {}, child: Text(AppStrings.get('all', lang))),
                    ],
                  ),
                  
                  Consumer(builder: (context, ref, _) {
                     final asyncReviews = ref.watch(productReviewsProvider(item.id));
                     final user = ref.watch(userProvider).value;

                      return asyncReviews.when(
                        data: (reviews) {
                          if (reviews.isEmpty) {
                            return Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Text(AppStrings.get('no_reviews_yet', lang)));
                          }
                          return Column(
                           children: reviews.map((r) {
                             final rId = r['id'] as String? ?? '';
                              final isOwner = user != null && user.id == (r['userId'] ?? '');
                              final isPurchaser = r['isPurchaser'] == true;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildCommentItem(context, rId, r['user'], r['comment'], r['rating'], isOwner, isPurchaser, lang, (newComment) async {
                                    final tenantId = await ref.read(resolvedTenantIdProvider.future);
                                    ref.read(firestoreServiceProvider).updateReview(tenantId, item.id, rId, {'comment': newComment});
                                  }, null, // Disable Reply for users
                                  () {
                                     // Delete logic
                                     _confirmDeleteReview(context, ref, item.id, rId);
                                  }),
                                 // Show replies
                                 if (r['replies'] != null)
                                   Padding(
                                     padding: const EdgeInsets.only(left: 32),
                                     child: Column(
                                       children: (r['replies'] as List).map((rep) => _buildReplyItem(rep['user'], rep['message'])).toList(),
                                     ),
                                   ),
                                 const Divider(),
                               ],
                             );
                           }).toList(),
                         );
                       },
                       loading: () => const LinearProgressIndicator(),
                       error: (err, _) => Text('Error: $err'),
                     );
                  }),
                  
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(AppStrings.get('similar_products', lang), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: asyncProducts.when(
                      data: (products) {
                        final similar = products.where((p) => p.category == item.category && p.id != item.id).toList();
                        if (similar.isEmpty) return Center(child: Text(AppStrings.get('no_similar_products', lang)));
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: similar.length,
                          itemBuilder: (context, index) {
                            final p = similar[index];
                            return GestureDetector(
                              onTap: () => context.push('/product-details', extra: p),
                              child: Container(
                                width: 140,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[200]!),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        child: OptimizedImage(imageUrl: p.images.isNotEmpty ? p.images.first : null, fit: BoxFit.cover, memCacheWidth: 300),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                          Text(formatCurrency(p.price), style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
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
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))]),
        child: Builder(
          builder: (btnContext) {
            final currentStock = (_selectedColor != null && _selectedSize != null)
                ? _getStockFor(_selectedColor!, _selectedSize!, item.variants)
                : item.stockQuantity;
            final isAvailable = currentStock > 0;

            return FilledButton.icon(
              onPressed: (_quantity > 0 && isAvailable) ? () {
                // Animation
                AddToCartAnimation.run(
                  context,
                  startBox: btnContext.findRenderObject() as RenderBox?,
                  cartKey: _cartKey,
                  imageUrl: item.images.isNotEmpty ? item.images.first : '',
                );

                ref.read(cartProvider.notifier).addToCart({
                  ...item.toJson(),
                  'price': _getCurrentPrice(item),
                  'quantity': _quantity,
                  'color': _selectedColor ?? 'Default',
                  'size': _selectedSize ?? 'Default',
                  'imageUrl': item.images.isNotEmpty ? item.images.first : null,
                });
                
                 // Optional: Short delay before showing snackbar so animation is visible easier
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(AppStrings.get('added_to_cart_msg', lang).replaceFirst('{count}', _quantity.toString())), 
                  duration: const Duration(seconds: 1)
                ));
              } : null,
              icon: Icon(isAvailable ? Icons.shopping_cart : Icons.inventory_2_outlined),
              label: Text(isAvailable ? AppStrings.get('add_to_cart', lang) : AppStrings.get('out_of_stock', lang)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isAvailable ? null : Colors.grey,
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildCommentItem(
    BuildContext context, 
    String reviewId, 
    String user, 
    String comment, 
    int rating, 
    bool isOwner,
    bool isPurchaser,
    String lang,
    Function(String) onEdit,
    VoidCallback? onReply,
    VoidCallback onDelete,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPurchaser ? Colors.amber.shade50.withOpacity(0.3) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isPurchaser 
            ? Border.all(color: Colors.amber.shade700, width: 2) 
            : Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: isPurchaser ? [
          BoxShadow(
            color: Colors.amber.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(backgroundColor: Colors.grey[200], radius: 16, child: Text(user.isNotEmpty ? user[0] : '?')),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(user, style: const TextStyle(fontWeight: FontWeight.bold)),
                            if (isPurchaser) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(4)),
                                child: Text(AppStrings.get('verified_purchase', lang), style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
                        ),
                        _buildStars(rating),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(comment, style: TextStyle(color: Colors.grey[700])),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (isOwner)
                          TextButton(
                            onPressed: () => _showEditReviewDialog(context, comment, onEdit, lang),
                            child: Text(AppStrings.get('edit', lang), style: const TextStyle(fontSize: 12)),
                          ),
                        if (onReply != null)
                          TextButton(
                            onPressed: onReply,
                            child: Text(AppStrings.get('reply', lang), style: const TextStyle(fontSize: 12)),
                          ),
                        if (isOwner)
                          TextButton(
                            onPressed: onDelete,
                            child: Text(AppStrings.get('delete', lang), style: const TextStyle(fontSize: 12, color: Colors.red)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(String user, String message) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                Text(message, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditReviewDialog(BuildContext context, String currentComment, Function(String) onEdit, String lang) {
    final controller = TextEditingController(text: currentComment);
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('edit_review', lang)),
        content: TextField(controller: controller, maxLines: 3),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel', lang))),
          FilledButton(
            onPressed: () {
              onEdit(controller.text);
              Navigator.pop(ctx);
            },
            child: Text(AppStrings.get('save', lang)),
          ),
        ],
      ),
    );
  }



  Widget _buildStars(int rating) {
    return Row(
      children: List.generate(5, (index) => Icon(
        index < rating ? Icons.star : Icons.star_border,
        color: Colors.amber,
        size: 14,
      )),
    );
  }

  void _showRatingDialog(BuildContext context, String lang) {
    final userData = ref.read(userProvider).value;
    if (userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('login_required_msg', lang))));
      return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) {
        int rating = 5;
        bool isLoading = false;
        final commentController = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(AppStrings.get('rate_product', lang)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) => IconButton(
                    onPressed: () => setDialogState(() => rating = index + 1),
                    icon: Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 32),
                  )),
                ),
                TextField(
                  controller: commentController,
                  decoration: InputDecoration(hintText: AppStrings.get('comment_hint', lang)),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel', lang))),
              FilledButton(
                onPressed: isLoading ? null : () async {
                  if (commentController.text.trim().isEmpty) return;
                  setDialogState(() => isLoading = true);
                  try {
                    final orders = ref.read(ordersProvider).value ?? [];
                    final hasPurchased = orders.any((o) => 
                      o.status == OrderStatus.completed && 
                      o.items.any((i) => (i['productId'] ?? i['id']) == (widget.product?.id ?? ''))
                    );
                    
                    final review = {
                      'user': userData.name,
                      'userId': userData.id,
                      'comment': commentController.text,
                      'rating': rating,
                      'isPurchaser': hasPurchased,
                      'timestamp': DateTime.now().toIso8601String(),
                    };
                    final tenant = ref.read(tenantProvider).value;
                    final tenantId = tenant?.id ?? 'Unknown';
                    final rewardPoints = tenant?.reviewRewardPoints ?? 5;
                    final dailyLimit = tenant?.maxDailyReviewPoints ?? 50;
                    final productId = widget.product?.id ?? 'Unknown';
                    await ref.read(firestoreServiceProvider).addReview(tenantId, productId, review, rewardPoints: rewardPoints, dailyLimit: dailyLimit);
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(AppStrings.get('review_added_reward', lang).replaceFirst('{points}', rewardPoints.toString()))
                      ));
                    }
                  } catch (e) {
                    setDialogState(() => isLoading = false);
                  }
                },
                child: isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(AppStrings.get('submit', lang)),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteReview(BuildContext context, WidgetRef ref, String productId, String reviewId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete this review?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final tenantId = await ref.read(resolvedTenantIdProvider.future);
              ref.read(firestoreServiceProvider).deleteReview(tenantId, productId, reviewId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showZoomableImage(BuildContext context, List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
          body: PhotoViewGallery.builder(
            itemCount: images.length,
            builder: (context, index) => PhotoViewGalleryPageOptions(
              imageProvider: NetworkImage(images[index]),
              initialScale: PhotoViewComputedScale.contained,
              minScale: PhotoViewComputedScale.contained * 0.8,
              maxScale: PhotoViewComputedScale.covered * 2,
            ),
            pageController: PageController(initialPage: initialIndex),
            scrollPhysics: const BouncingScrollPhysics(),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
        ),
      ),
    );
  }


}
