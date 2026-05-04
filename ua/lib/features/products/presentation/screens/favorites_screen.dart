import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:user_app/features/shared/providers.dart';
import 'package:user_app/core/utils/formatters.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:shared_models/shared_models.dart';
import 'package:user_app/features/shared/widgets/optimized_image.dart';

class FavoritesScreen extends HookConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final favoriteIds = ref.watch(favoritesProvider);
    final asyncProducts = ref.watch(productsProvider);
    final searchQuery = useState('');
    
    return asyncProducts.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text('Error: $err'))),
      data: (allProducts) {
        final favoriteProducts = allProducts.where((p) {
          final isFavorite = favoriteIds.contains(p.id);
          final matchesSearch = p.name.toLowerCase().contains(searchQuery.value.toLowerCase());
          return isFavorite && matchesSearch;
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(AppStrings.get('favorites', lang)),
          ),
          body: Column(
            children: [
              if (favoriteIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      onChanged: (v) => searchQuery.value = v,
                      decoration: InputDecoration(
                        hintText: AppStrings.get('search_hint', lang),
                        prefixIcon: const Icon(Icons.search),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: favoriteProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              searchQuery.value.isEmpty 
                                  ? AppStrings.get('no_favorites', lang)
                                  : 'No matches found',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.65, // Taller cards for bigger images
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: favoriteProducts.length,
                        itemBuilder: (context, index) {
                          final product = favoriteProducts[index];
                          return _buildProductCard(context, ref, product);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductCard(BuildContext context, WidgetRef ref, ProductModel product) {
    return InkWell(
      onTap: () => context.push('/product-details', extra: product.toJson()),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3, // Give more space to image
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildImageOrIcon(product.images.isNotEmpty ? product.images.first : null, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.8),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.red, size: 20),
                        onPressed: () => ref.read(favoritesProvider.notifier).toggleFavorite(product.id),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2, // Content area
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 12, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(product.rating.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      formatCurrency(product.price), 
                      style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary, fontSize: 13),
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

  Widget _buildImageOrIcon(String? data, {BoxFit fit = BoxFit.cover}) {
    if (data != null && (data.startsWith('http') || data.startsWith('https') || data.contains('/'))) {
      return OptimizedImage(
        imageUrl: data,
        width: double.infinity,
        height: double.infinity,
        fit: fit,
        memCacheWidth: 300, // Small grid thumbnails
      );
    }
    final iconCode = int.tryParse(data ?? '58900') ?? 58900;
    return Center(
      child: Icon(IconData(iconCode, fontFamily: 'MaterialIcons'), size: 40, color: Colors.grey[400]),
    );
  }
}
