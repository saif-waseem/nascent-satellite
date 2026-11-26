import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:user_app/features/shared/providers.dart';
import 'package:user_app/core/utils/formatters.dart';
import 'package:user_app/features/home/presentation/providers/cart_key_provider.dart';
import 'package:user_app/core/utils/animations.dart'; // Just in case, though HomeScreen mainly provides the target
import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:shared_models/shared_models.dart';
import 'package:user_app/core/services/notification_service.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:user_app/features/shared/widgets/optimized_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _searchQuery = '';
  bool _sortByPrice = false;
  bool _sortByRating = false;
  bool _onlyOffers = false;
  double _minPrice = 0;
  double _maxPrice = double.infinity;
  double _minRating = 0;
  List<String> _selectedCategories = [];
  bool _showDailyCheckInBanner = false;
  int _dailyCheckInPoints = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationServiceProvider).startListening(context);
      
      // Handle cart sharing data if present in routing state
      final state = GoRouterState.of(context);
      final cartData = state.uri.queryParameters['data']; // Legacy
      final cartId = state.uri.queryParameters['cart']; // New Short ID
      final productId = state.uri.queryParameters['p'];
      
      if (cartData != null || cartId != null || productId != null) {
        final lang = ref.read(appSettingsProvider).locale.languageCode;
        if (cartData != null) {
          ref.read(cartProvider.notifier).loadFromLink(cartData);
          _onCartLoaded(context, lang);
        } else if (cartId != null) {
          ref.read(cartProvider.notifier).loadFromSharedId(cartId).then((_) {
            if (mounted) _onCartLoaded(context, lang);
          });
        } else if (productId != null) {
          context.push('/product/$productId');
        }
      }
      
      _checkDailyCheckIn();
      _checkAbandonedCart();
    });
  }

  void _onCartLoaded(BuildContext context, String lang) {
    // Clear query parameters to avoid re-loading on rebuild
    context.go('/home');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.get('cart_loaded_success', lang)),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _checkAbandonedCart() async {
    await ref.read(cartProvider.notifier).loadCartFromFirestore();
    final hasAbandonedCart = ref.read(abandonedCartFlagProvider);
    if (hasAbandonedCart && mounted) {
      final lang = ref.read(appSettingsProvider).locale.languageCode;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.shopping_cart_checkout, color: Colors.orange),
              const SizedBox(width: 8),
              const Expanded(child: Text('عربة التسوق بانتظارك!', style: TextStyle(fontSize: 18))),
            ],
          ),
          content: const Text('لقد تركت بعض المنتجات الرائعة في سلتك من زيارتك السابقة. هل تود إكمال الشراء الآن؟'),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(abandonedCartFlagProvider.notifier).state = false;
                Navigator.pop(ctx);
              },
              child: Text(AppStrings.get('later', lang), style: const TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: () {
                ref.read(abandonedCartFlagProvider.notifier).state = false;
                Navigator.pop(ctx);
                context.push('/cart');
              },
              child: const Text('الذهاب للسلة'),
            ),
          ],
        ),
      );
    }
  }

  void _checkDailyCheckIn() async {
    final user = ref.read(userProvider).value;
    if (user == null || user.isBlocked) return;

    final lastCheckIn = user.lastCheckInDate;
    final now = DateTime.now();
    final isCheckedInToday = lastCheckIn != null && 
        lastCheckIn.year == now.year && 
        lastCheckIn.month == now.month && 
        lastCheckIn.day == now.day;

    if (!isCheckedInToday) {
      final points = user.checkInStreak == 0 ? 5 : (1 + (DateTime.now().millisecond % 10));
      setState(() {
        _showDailyCheckInBanner = true;
        _dailyCheckInPoints = points;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncProducts = ref.watch(productsProvider);
    final asyncCategories = ref.watch(categoriesProvider);
    final asyncTenant = ref.watch(tenantProvider);
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final cartCount = ref.watch(cartProvider).length;

    // Daily Check-in Auto Popup
    ref.listen(userProvider, (prev, next) {
      if (next.value != null && prev?.value == null) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _checkDailyCheckIn();
        });
      }
    });

    // Global Error Listener
    ref.listen(globalErrorProvider, (prev, next) {
      if (next != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next), backgroundColor: Colors.red));
        ref.read(globalErrorProvider.notifier).set(null);
      }
    });

    return asyncProducts.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('...')),
        body: const SkeletonGrid(),
      ),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (allProducts) {
        final userAsync = ref.watch(userProvider);
        return userAsync.when(
          loading: () => Scaffold(
            appBar: AppBar(title: const Text('...')),
            body: const SkeletonGrid(),
          ),
          error: (err, _) => _buildMainScaffold(context, allProducts, lang, asyncCategories, asyncTenant, cartCount),
          data: (user) {
            if (user != null && user.isBlocked) {
              return _buildBlockedScreen(context, lang);
            }
            return _buildMainScaffold(context, allProducts, lang, asyncCategories, asyncTenant, cartCount);
          },
        );
      },
    );
  }

  Widget _buildBlockedScreen(BuildContext context, String lang) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.block, color: Colors.red, size: 80),
              const SizedBox(height: 24),
              Text(AppStrings.get('account_blocked_title', lang), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(AppStrings.get('account_blocked_body', lang), textAlign: TextAlign.center),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  ref.read(userActionsProvider).logout();
                  context.go('/login');
                },
                child: Text(AppStrings.get('login_btn', lang)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainScaffold(
    BuildContext context, 
    List<ProductModel> allProducts, 
    String lang, 
    AsyncValue<List<CategoryModel>> asyncCategories,
    AsyncValue<TenantModel?> asyncTenant,
    int cartCount
  ) {
    // Filter & Sort Logic
    var displayedProducts = allProducts.where((p) {
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty || p.name.toLowerCase().contains(query);
      final matchesCategory = _selectedCategories.isEmpty || _selectedCategories.contains(p.category);
      final matchesOffer = !_onlyOffers || p.isOffer == true;
      final matchesPrice = p.price >= _minPrice && p.price <= _maxPrice;
      
      final rating = p.rating; // Use static rating for filtering to ensure products show immediately
      final matchesRating = rating >= _minRating;

      return matchesSearch && matchesCategory && matchesOffer && matchesPrice && matchesRating;
    }).toList();

    if (_sortByPrice) {
      displayedProducts.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortByRating) {
      displayedProducts.sort((a, b) {
        final aRating = _getRating(a.id, a.rating, ref);
        final bRating = _getRating(b.id, b.rating, ref);
        return bRating.compareTo(aRating);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: asyncTenant.when(
          data: (tenant) => Row(
            children: [
               CircleAvatar(
                 radius: 16,
                 backgroundColor: Colors.white,
                 child: _buildImageOrIcon(tenant?.logoUrl, size: 20),
               ),
               const SizedBox(width: 8),
               Expanded(
                 child: Text(
                   tenant?.name ?? AppStrings.get('store', lang),
                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                   overflow: TextOverflow.ellipsis,
                   maxLines: 1,
                 ),
               ),
            ],
          ),
          error: (_, __) => Text(AppStrings.get('store', lang)),
          loading: () => const Text('...'),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final tenant = asyncTenant.value;
              if (tenant != null && tenant.whatsappNumber.isNotEmpty) {
                var phone = tenant.whatsappNumber.replaceAll(RegExp(r'\D'), '');
                // Basic cleanup for International format
                if (phone.startsWith('00')) {
                  phone = phone.substring(2);
                }
                final url = Uri.parse('https://wa.me/$phone');
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('contact_support_whatsapp_error', lang))));
                  }
                }
              }
            },
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.green),
          ),
          IconButton(
            onPressed: () => context.push('/favorites'),
            icon: const Icon(Icons.favorite_border),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                key: ref.read(cartKeyProvider), // Assign global key for animation target
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => context.push('/cart'),
              ),
              if (cartCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text('$cartCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_showDailyCheckInBanner) _buildDailyCheckInBanner(lang),
                _buildSectionTitle(AppStrings.get('categories', lang), Icons.category, Colors.blue),
                _buildCategoriesSection(lang, asyncCategories),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                       Expanded(child: _buildSearchBar(lang)),
                       const SizedBox(width: 8),
                       IconButton.filledTonal(
                         onPressed: () => _showFilterSheet(context, lang, asyncCategories.value ?? []),
                         icon: const Icon(Icons.tune),
                       ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                _buildFilterBar(lang),
                const SizedBox(height: 16),
                

                const SizedBox(height: 24),
                
                // Flash Sales Section
                _buildFlashSalesSection(lang, asyncTenant.value?.currencyUnit),
                
                // Featured Deals Carousel
                _buildFeaturedDealsCarousel(allProducts, lang, asyncTenant.value?.currencyUnit),
                const SizedBox(height: 24),
                
                // Top Rated Products Section
                _buildTopRatedSection(allProducts, lang, asyncTenant.value?.currencyUnit),
                const SizedBox(height: 24),
                
                _buildSectionTitle(AppStrings.get('all_products_section', lang), Icons.grid_view, Theme.of(context).colorScheme.primary),
                if (displayedProducts.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(AppStrings.get('no_products_yet', lang), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Text(AppStrings.get('try_changing_filters', lang), style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                else
                  _buildProductGrid(displayedProducts, context),
                const SizedBox(height: 24),
                Consumer(builder: (context, ref, _) {
                  final tenantIdAsync = ref.watch(resolvedTenantIdProvider);
                  return tenantIdAsync.maybeWhen(
                    data: (id) => Center(child: Text(AppStrings.get('connected_to_store', lang).replaceFirst('{id}', id), style: const TextStyle(fontSize: 10, color: Colors.grey))),
                    orElse: () => const SizedBox.shrink(),
                  );
                }),
                const SizedBox(height: 96),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(lang),
    );
  }

  double _getRating(String productId, double staticRating, WidgetRef ref) {
    final asyncReviews = ref.read(productReviewsProvider(productId));
    return asyncReviews.maybeWhen(
      data: (reviews) {
        if (reviews.isEmpty) return staticRating;
        final totalRating = reviews.fold(0.0, (sum, r) => sum + (r['rating'] as num).toDouble());
        return totalRating / reviews.length;
      },
      orElse: () => staticRating,
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
  
  Widget _buildCategoriesSection(String lang, AsyncValue<List<CategoryModel>> asyncCategories) {
    return asyncCategories.when(
      loading: () => SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: 5,
          itemBuilder: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ShimmerLoader(width: 60, height: 60, borderRadius: BorderRadius.all(Radius.circular(30))),
          ),
        ),
      ),
      error: (err, _) => const SizedBox(height: 90, child: Center(child: Icon(Icons.error))),
      data: (categories) {
        final allCats = [
          CategoryModel(id: 'All', name: AppStrings.get('cat_all', lang), icon: '0xe2eb'),
          ...categories,
        ];

        return SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: allCats.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final cat = allCats[index];
              final isCatSelected = _selectedCategories.contains(cat.id) || (_selectedCategories.isEmpty && cat.id == 'All');
              
              IconData iconData;
              if (cat.id == 'All') {
                iconData = Icons.grid_view_rounded;
              } else {
                int? code = int.tryParse(cat.icon);
                if (code == null && cat.icon.startsWith('0x')) {
                  code = int.tryParse(cat.icon.substring(2), radix: 16);
                }
                if (code != null && code > 0) {
                  iconData = IconData(code, fontFamily: 'MaterialIcons');
                } else {
                  final nameLower = cat.name.toLowerCase();
                  if (nameLower.contains('سير') || nameLower.contains('ذات')) {
                    iconData = Icons.person_pin_rounded;
                  } else if (nameLower.contains('قصص') || nameLower.contains('رواي') || nameLower.contains('خيال')) {
                    iconData = Icons.auto_stories_rounded;
                  } else if (nameLower.contains('سياس') || nameLower.contains('دول')) {
                    iconData = Icons.account_balance_rounded;
                  } else if (nameLower.contains('تاريخ')) {
                    iconData = Icons.history_edu_rounded;
                  } else if (nameLower.contains('دين') || nameLower.contains('إسلام')) {
                    iconData = Icons.menu_book_rounded;
                  } else {
                    iconData = Icons.category_rounded;
                  }
                }
              }

              return GestureDetector(
                onTap: () => setState(() {
                  if (cat.id == 'All') {
                    _selectedCategories = [];
                  } else {
                    if (_selectedCategories.contains(cat.id)) {
                      _selectedCategories.remove(cat.id);
                    } else {
                      _selectedCategories.add(cat.id);
                    }
                  }
                }),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCatSelected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: isCatSelected ? Colors.transparent : Colors.grey.withOpacity(0.2)),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
                      ),
                      child: Icon(iconData, color: isCatSelected ? Colors.white : Colors.grey, size: 24),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cat.name,
                      style: TextStyle(
                        fontSize: 12, 
                        fontWeight: isCatSelected ? FontWeight.bold : FontWeight.normal,
                        color: isCatSelected ? Theme.of(context).primaryColor : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductGrid(List<ProductModel> products, BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 2;
        if (width > 1200) {
          crossAxisCount = 5;
        } else if (width > 900) {
          crossAxisCount = 4;
        } else if (width > 600) {
          crossAxisCount = 3;
        }

        final scale = MediaQuery.textScalerOf(context).scale(1.0);
        return GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: scale > 1.05 ? 0.62 : 0.72,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) => _buildProductCard(products[index]),
        );
      },
    );
  }

  Widget _buildProductCard(ProductModel product, {double? width}) {
    return Consumer(
      builder: (context, ref, _) {
        final lang = ref.watch(appSettingsProvider).locale.languageCode;
        final asyncTenant = ref.watch(tenantProvider);
        final currencyUnit = asyncTenant.value?.currencyUnit;
        final asyncReviews = ref.watch(productReviewsProvider(product.id));
        double rating = product.rating;
        asyncReviews.whenData((reviews) {
          if (reviews.isNotEmpty) {
             final totalRating = reviews.fold(0.0, (sum, r) => sum + (r['rating'] as num).toDouble());
             rating = totalRating / reviews.length;
          }
        });

        final isFeaturedDeal = product.isFeaturedDeal;
        final isTopRated = rating >= 4.5;
        final hasSpecialBorder = isFeaturedDeal || isTopRated;

        return InkWell(
          onTap: () => context.push('/product-details', extra: product),
          child: Container(
            width: width,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasSpecialBorder 
                  ? (isFeaturedDeal ? Colors.deepOrange : Colors.amber)
                  : Colors.grey.withOpacity(0.05),
                width: hasSpecialBorder ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: hasSpecialBorder 
                    ? (isFeaturedDeal ? Colors.deepOrange.withOpacity(0.1) : Colors.amber.withOpacity(0.1))
                    : Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerLow,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: _buildImageOrIcon(product.imageUrl, size: 200, fit: BoxFit.cover, memWidth: 400),
                          ),
                        ),
                      ),
                      if (BatchInventoryHelper.sellableStock(product) <= 0)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  AppStrings.get('out_of_stock', lang),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (product.isOffer == true || isFeaturedDeal)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isFeaturedDeal ? Colors.deepOrange : Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isFeaturedDeal ? AppStrings.get('featured_tag', lang) : AppStrings.get('sale_tag', lang),
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Consumer(
                          builder: (context, ref, _) {
                            final favorites = ref.watch(favoritesProvider);
                            final isFav = favorites.contains(product.id);
                            return IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                child: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : Colors.grey, size: 16),
                              ),
                              onPressed: () => ref.read(favoritesProvider.notifier).toggleFavorite(product.id),
                            );
                          }
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 12, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const Spacer(),
                          if (product.oldPrice != null && product.oldPrice! > product.price)
                            Text(
                              formatCurrency(product.oldPrice!),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: lang == 'ar' ? Alignment.centerRight : Alignment.centerLeft,
                              child: Text(
                                formatCurrency(product.price, unitOverride: product.unit ?? currencyUnit), 
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: hasSpecialBorder ? Colors.deepOrange : Theme.of(context).colorScheme.primary,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.add_shopping_cart, size: 14, color: Theme.of(context).primaryColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildSearchBar(String lang) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: AppStrings.get('search_hint', lang),
          prefixIcon: const Icon(Icons.search),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildFilterBar(String lang) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          FilterChip(
            label: Text(AppStrings.get('filter_sort_price', lang)),
            selected: _sortByPrice,
            onSelected: (val) => setState(() { _sortByPrice = val; _sortByRating = false; }),
            avatar: const Icon(Icons.sort, size: 16),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(AppStrings.get('filter_sort_rating', lang)),
            selected: _sortByRating,
            onSelected: (val) => setState(() { _sortByRating = val; _sortByPrice = false; }),
            avatar: const Icon(Icons.star_border, size: 16),
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: Text(AppStrings.get('filter_offers', lang)),
            selected: _onlyOffers,
            onSelected: (val) => setState(() => _onlyOffers = val),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(String lang) {
    return const SizedBox.shrink();
  }

  Widget _buildImageOrIcon(String? data, {double size = 24, BoxFit fit = BoxFit.cover, double? memWidth, double? memHeight}) {
    if (data != null && data.startsWith('http')) {
      return OptimizedImage(
        imageUrl: data,
        width: size,
        height: size,
        fit: fit,
        memCacheWidth: memWidth ?? size * 2,
        memCacheHeight: memHeight ?? size * 2,
      );
    }
    if (data != null && (data.contains('/') || data.contains('\\')) && !data.startsWith('http')) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey[100],
        child: Icon(Icons.cloud_sync_outlined, size: size * 0.5, color: Colors.blue.withOpacity(0.5)),
      );
    }
    final iconCode = int.tryParse(data ?? '0x1234') ?? 58900;
    return Icon(IconData(iconCode, fontFamily: 'MaterialIcons'), size: size, color: Colors.grey);
  }

  Widget _buildFeaturedDealsCarousel(List<ProductModel> allProducts, String lang, String? currencyUnit) {
    final featuredProducts = allProducts.where((p) => p.isFeaturedDeal).toList();
    
    if (featuredProducts.isEmpty) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context).scale(1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.flash_on, color: Colors.orange, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.get('featured_deals', lang),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _onlyOffers = true),
                child: Text(AppStrings.get('view_all', lang)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: scale > 1.05 ? 385 : 350,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: featuredProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final product = featuredProducts[index];
              return _buildFeaturedCard(product, lang, currencyUnit);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCard(ProductModel product, String lang, String? currencyUnit) {
    return Consumer(
      builder: (context, ref, _) {
        final asyncReviews = ref.watch(productReviewsProvider(product.id));
        double rating = product.rating;
        asyncReviews.whenData((reviews) {
          if (reviews.isNotEmpty) {
            final totalRating = reviews.fold(0.0, (sum, r) => sum + (r['rating'] as num).toDouble());
            rating = totalRating / reviews.length;
          }
        });

        return InkWell(
          onTap: () => context.push('/product-details', extra: product.toJson()),
          child: Container(
            width: 240,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.orange.shade50, Colors.white],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.15),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(color: Colors.orange.shade100, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Hero(
                      tag: 'prod-${product.id}',
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildImageOrIcon(product.imageUrl, size: 200, fit: BoxFit.cover),
                      ),
                    ),
                    if (product.discountPercentage != null && product.discountPercentage! > 0)
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Colors.red, Colors.deepOrange]),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Text(
                            '-${product.discountPercentage}%',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                            child: Row(
                              children: [
                                const Icon(Icons.star, size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange)),
                              ],
                            ),
                          ),
                          const Spacer(),
                          if (product.oldPrice != null && product.oldPrice! > product.price)
                            Text(
                              formatCurrency(product.oldPrice!, unitOverride: currencyUnit),
                              style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: lang == 'ar' ? Alignment.centerRight : Alignment.centerLeft,
                              child: Text(
                                formatCurrency(product.price, unitOverride: product.unit ?? currencyUnit),
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Theme.of(context).primaryColor, shape: BoxShape.circle),
                            child: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 18),
                          ),
                        ],
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
  }

  Widget _buildTopRatedSection(List<ProductModel> allProducts, String lang, String? currencyUnit) {
    // Get top products sorted by rating (4.0+)
    final topRatedProducts = allProducts.where((p) {
      final rating = _getRating(p.id, p.rating, ref);
      return rating >= 4.0; 
    }).toList()
      ..sort((a, b) {
        final aRating = _getRating(a.id, a.rating, ref);
        final bRating = _getRating(b.id, b.rating, ref);
        return bRating.compareTo(aRating);
      });
    
    final displayProducts = topRatedProducts.take(15).toList();
    
    if (displayProducts.isEmpty) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context).scale(1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  AppStrings.get('top_rated_products', lang),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Optional: 'See All' button could go here
            ],
          ),
        ),
        SizedBox(
          height: scale > 1.05 ? 360 : 325, // Adaptive height for large fonts
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: displayProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final product = displayProducts[index];
              return _buildTopRatedCard(product, currencyUnit);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopRatedCard(ProductModel product, String? currencyUnit) {
    return Consumer(
      builder: (context, ref, _) {
        final asyncReviews = ref.watch(productReviewsProvider(product.id));
        double rating = product.rating;
        asyncReviews.whenData((reviews) {
          if (reviews.isNotEmpty) {
            final totalRating = reviews.fold(0.0, (sum, r) => sum + (r['rating'] as num).toDouble());
            rating = totalRating / reviews.length;
          }
        });

        return Builder(
          builder: (cardContext) {
            return InkWell(
              onTap: () => context.push('/product-details', extra: product.toJson()),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 210, // Wider card
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFFFD700), // Premium Gold
                    width: 2.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withOpacity(0.2), 
                      blurRadius: 15, 
                      spreadRadius: 1,
                      offset: const Offset(0, 4)
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05), 
                      blurRadius: 10, 
                      offset: const Offset(0, 2)
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Section
                    Stack(
                      children: [
                        Container(
                          height: 200, // Square-ish image
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _buildImageOrIcon(product.imageUrl, size: 200, fit: BoxFit.cover),
                        ),
                        // Minimalist Discount Tag
                        if (product.discountPercentage != null && product.discountPercentage! > 0)
                          Positioned(
                            top: 12,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              ),
                              child: Text(
                                '-${product.discountPercentage}%',
                                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        // Heart Icon
                         Positioned(
                          top: 8,
                          right: 8,
                          child: Consumer(
                            builder: (context, ref, _) {
                              final favorites = ref.watch(favoritesProvider);
                              final isFav = favorites.contains(product.id);
                              return InkWell(
                                onTap: () => ref.read(favoritesProvider.notifier).toggleFavorite(product.id),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isFav ? Icons.favorite : Icons.favorite_border,
                                    color: isFav ? Colors.red : Colors.black54,
                                    size: 18,
                                  ),
                                ),
                              );
                            }
                          ),
                        ),
                      ],
                    ),
                    
                    // Info Section
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, height: 1.2),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.star, size: 14, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      rating.toStringAsFixed(1), 
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[700])
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '(${product.salesCount})',
                                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (product.oldPrice != null && product.oldPrice! > product.price)
                                        Text(
                                          formatCurrency(product.oldPrice!, unitOverride: currencyUnit),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey,
                                            decoration: TextDecoration.lineThrough,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      Text(
                                        formatCurrency(product.price, unitOverride: currencyUnit),
                                        style: const TextStyle(
                                          fontSize: 16, 
                                          fontWeight: FontWeight.bold, 
                                          color: Colors.black87
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                if (product.inStock)
                                  InkWell(
                                    onTap: () {
                                      final cartKey = ref.read(cartKeyProvider);
                                      AddToCartAnimation.run(
                                        context,
                                        startBox: cardContext.findRenderObject() as RenderBox?,
                                        cartKey: cartKey,
                                        imageUrl: product.imageUrl ?? '',
                                      );
                                      ref.read(cartProvider.notifier).addToCart(product.toJson());
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.black, // Sleek black button
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.add, color: Colors.white, size: 20),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.red[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Sold Out',
                                      style: TextStyle(color: Colors.red[700], fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        );
      },
    );
  }



  void _showFilterSheet(BuildContext context, String lang, List<CategoryModel> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(AppStrings.get('filter_label', lang), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        _minPrice = 0;
                        _maxPrice = double.infinity;
                        _minRating = 0;
                        _onlyOffers = false;
                        _selectedCategories = [];
                      });
                      setState(() {});
                    },
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text(AppStrings.get('filter_offers', lang)),
                value: _onlyOffers,
                onChanged: (v) {
                  setModalState(() => _onlyOffers = v ?? false);
                  setState(() {});
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlashSalesSection(String lang, String? currency) {
    final asyncCoupons = ref.watch(couponsProvider);
    
    return asyncCoupons.when(
      data: (coupons) {
        // Filter coupons that have an expiry date in the future
        final activeFlashSales = coupons.where((c) => c.expiryDate != null && c.expiryDate!.isAfter(DateTime.now())).toList();
        
        if (activeFlashSales.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('⚡ عروض فلاش!', Icons.flash_on, Colors.orange),
            SizedBox(
              height: 120,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: activeFlashSales.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final coupon = activeFlashSales[index];
                  final timeRemaining = coupon.expiryDate!.difference(DateTime.now());
                  final hours = timeRemaining.inHours;
                  final minutes = timeRemaining.inMinutes.remainder(60);
                  
                  return Container(
                    width: 250,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              coupon.code,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.orange),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${hours}h ${minutes}m',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          coupon.type == DiscountType.percentage 
                              ? 'خصم ${coupon.value}%'
                              : 'خصم ${formatCurrency(coupon.value, lang: lang, unitOverride: currency)}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        const Spacer(),
                        Text(
                          'الحد الأدنى: ${formatCurrency(coupon.minPurchase, lang: lang, unitOverride: currency)}',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildDailyCheckInBanner(String lang) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade300, Colors.orange.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.redeem, color: Colors.orange),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.get('daily_reward_title', lang) ?? 'جائزتك اليومية جاهزة!',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'احصل على $_dailyCheckInPoints نقطة الآن',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _showDailyCheckInBanner = false),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              final user = ref.read(userProvider).value;
              if (user == null) return;
              try {
                await ref.read(firestoreServiceProvider).dailyCheckIn(user.id, _dailyCheckInPoints);
                setState(() => _showDailyCheckInBanner = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(AppStrings.get('check_in_success', lang).replaceFirst('{points}', _dailyCheckInPoints.toString())),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    )
                  );
                }
              } catch (_) {}
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(AppStrings.get('claim', lang) ?? 'احصل عليها'),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2, end: 0);
  }
}
