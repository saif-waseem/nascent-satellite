import 'package:user_app/core/utils/store_share.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:user_app/features/shared/providers.dart';
import 'package:user_app/core/utils/formatters.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';
import 'package:shared_ui/shared_ui.dart';

class CartScreen extends HookConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = cart.fold(0.0, (sum, item) => sum + (((item['price'] as num?)?.toDouble() ?? 0.0) * (item['quantity'] ?? 1)));
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final tenant = ref.watch(tenantProvider).value;
    final currencyUnit = tenant?.currencyUnit;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppStrings.get('cart_title', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (cart.isNotEmpty) IconButton(icon: const Icon(Icons.share_outlined),
            tooltip: 'مشاركة السلة', onPressed: () async {
              try {
                final id = await ref.read(cartProvider.notifier).generateCartLink();
                if (context.mounted) await shareStoreRoute(context, '/share/$id', 'سلة المنتجات');
              } catch (_) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذرت مشاركة السلة. تحقق من الاتصال.')));
              }
            }),
        ],
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.white.withOpacity(0.5)),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          
          cart.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey[300])
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(duration: 2.seconds, color: Colors.white)
                        .shake(hz: 2, curve: Curves.easeInOut),
                    const SizedBox(height: 24),
                    Text(
                      AppStrings.get('cart_empty', lang),
                      style: TextStyle(fontSize: 18, color: Colors.grey[400], fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.arrow_back),
                      label: Text(AppStrings.get('cat_all', lang)), // Using a generic 'Shop Now' like label
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 70, 16, 100),
                      itemCount: cart.length,
                      itemBuilder: (context, index) {
                        final item = cart[index];
                        return _CartItemCard(
                          item: item,
                          index: index,
                          currencyUnit: currencyUnit,
                          lang: lang,
                        ).animate().fadeIn(delay: (index * 50).ms).slideX(begin: 0.1, end: 0);
                      },
                    ),
                  ),
                ],
              ),
          
          if (cart.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _CartSummaryBar(
                total: total,
                currencyUnit: currencyUnit,
                lang: lang,
              ).animate().slideY(begin: 1, end: 0, duration: 500.ms, curve: Curves.easeOutBack),
            ),
        ],
      ),
    );
  }
}

class _CartItemCard extends ConsumerWidget {
  final Map<String, dynamic> item;
  final int index;
  final String? currencyUnit;
  final String lang;

  const _CartItemCard({
    required this.item,
    required this.index,
    required this.currencyUnit,
    required this.lang,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = item['name'] ?? 'Product';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final quantity = item['quantity'] ?? 1;
    final compact = MediaQuery.sizeOf(context).width < 400;
    final imageUrl = item['imageUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Image
            Container(
              width: compact ? 54 : 90,
              height: compact ? 64 : 90,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null && imageUrl.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const ShimmerLoader(width: 90, height: 90),
                      errorWidget: (context, url, err) => const Icon(Icons.broken_image),
                    )
                  : const Icon(Icons.shopping_bag_outlined, color: Colors.grey),
            ),
            const SizedBox(width: 16),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (item['size'] != null && item['size'] != 'Default' && item['size'] != 'none' ||
                      item['color'] != null && item['color'] != 'Default' && item['color'] != 'none')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${item['color'] ?? ''}${item['color'] != null && item['size'] != null ? ' / ' : ''}${item['size'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  Text(
                    formatCurrency(price, unitOverride: currencyUnit),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Quantity Adjuster
                  Wrap(alignment: WrapAlignment.start, crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _qtyBtn(Icons.remove, () {
                        ref.read(cartProvider.notifier).updateQuantity(index, quantity - 1);
                      }),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '$quantity',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      _qtyBtn(Icons.add, () {
                         ref.read(cartProvider.notifier).updateQuantity(index, quantity + 1);
                      }),
                    ],
                  ),
                ],
              ),
            ),
            
            // Delete
            IconButton(
              onPressed: () => ref.read(cartProvider.notifier).removeFromCart(index),
              icon: Icon(Icons.delete_outline, color: Colors.red[300], size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }
}

class _CartSummaryBar extends StatelessWidget {
  final double total;
  final String? currencyUnit;
  final String lang;

  const _CartSummaryBar({
    required this.total,
    required this.currencyUnit,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.get('cart_total', lang),
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      Text(
                        formatCurrency(total, unitOverride: currencyUnit),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 54,
                    width: 160,
                    child: Consumer(builder: (context, ref, _) {
                      return FilledButton(
                        onPressed: () {
                          final user = ref.read(userProvider).value;
                          if (user == null) {
                            context.push('/login');
                          } else {
                            context.push('/checkout');
                          }
                        },
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 8,
                          shadowColor: Theme.of(context).primaryColor.withOpacity(0.4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              AppStrings.get('checkout_btn', lang),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                      );
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

