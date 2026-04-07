import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../data/product_repository.dart';

final productsStreamProvider = StreamProvider.autoDispose((ref) {
  final repo = ref.watch(productRepositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  return repo.watchProducts(tenantId);
});

final productSearchQueryProvider = NotifierProvider<ProductSearchQuery, String>(ProductSearchQuery.new);

class ProductSearchQuery extends Notifier<String> {
  @override
  String build() => '';
  void set(String val) => state = val;
}

final filteredProductsProvider = Provider.autoDispose((ref) {
  final productsAsync = ref.watch(productsStreamProvider);
  final query = ref.watch(productSearchQueryProvider).toLowerCase();

  return productsAsync.whenData((products) {
    var filtered = products.where((p) => !p.isArchived);
    if (query.isNotEmpty) {
      filtered = filtered.where((p) {
        final name = p.name.toLowerCase();
        final barcode = p.barcode?.toLowerCase() ?? '';
        final category = p.category.toLowerCase();
        return name.contains(query) || barcode.contains(query) || category.contains(query);
      });
    }
    return filtered.toList();
  });
});

final archivedProductsProvider = Provider.autoDispose((ref) {
  final productsAsync = ref.watch(productsStreamProvider);
  return productsAsync.whenData((products) {
    return products.where((p) => p.isArchived).toList();
  });
});

final categoryListProvider = Provider.autoDispose((ref) {
  final productsAsync = ref.watch(productsStreamProvider);
  return productsAsync.whenData((products) {
    return products.map((p) => p.category).toSet().toList()..sort();
  });
});

final lowStockProductsProvider = Provider.autoDispose((ref) {
  final productsAsync = ref.watch(productsStreamProvider);
  return productsAsync.whenData((products) {
    return products.where((p) {
      if (p.isArchived) return false;
      final threshold = p.minStockLevel ?? 5;
      return p.stockQuantity <= threshold;
    }).toList();
  });
});

final nearExpiryProductsProvider = Provider.autoDispose((ref) {
  final productsAsync = ref.watch(productsStreamProvider);
  return productsAsync.whenData((products) {
    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));
    return products.where((p) {
      if (p.expiryDate == null || p.isArchived) return false;
      return p.expiryDate!.isBefore(thirtyDaysLater);
    }).toList();
  });
});
