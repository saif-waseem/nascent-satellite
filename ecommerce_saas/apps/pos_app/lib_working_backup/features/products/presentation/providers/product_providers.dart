import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../data/product_repository.dart';

// Using FutureProvider instead of StreamProvider for REST
final productsFutureProvider = FutureProvider.autoDispose((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  ref.watch(productStockVersionProvider);
  if (tenantId.isEmpty) return <ProductModel>[];
  return await repo.getProducts(tenantId, limit: 100);
});

class PagedProductsState {
  final List<ProductModel> products;
  final bool isLoadingMore;
  final bool hasMore;
  final String? lastDocId;
  final String? error;

  PagedProductsState({
    required this.products,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.lastDocId,
    this.error,
  });

  PagedProductsState copyWith({
    List<ProductModel>? products,
    bool? isLoadingMore,
    bool? hasMore,
    String? lastDocId,
    String? error,
  }) {
    return PagedProductsState(
      products: products ?? this.products,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      lastDocId: lastDocId ?? this.lastDocId,
      error: error ?? this.error,
    );
  }
}

final pagedInventoryProductsProvider = NotifierProvider<PagedInventoryProductsNotifier, PagedProductsState>(PagedInventoryProductsNotifier.new);

class PagedInventoryProductsNotifier extends Notifier<PagedProductsState> {
  @override
  PagedProductsState build() {
    ref.watch(tenantIdProvider);
    ref.watch(productStockVersionProvider);
    Future.microtask(() => loadInitial());
    return PagedProductsState(products: []);
  }

  ProductRepository get repo => ref.read(productRepositoryProvider);
  String get tenantId => ref.read(tenantIdProvider);

  Future<void> loadInitial() async {
    try {
      state = state.copyWith(isLoadingMore: true, error: null);
      if (tenantId.isEmpty) {
        state = state.copyWith(isLoadingMore: false, error: 'Tenant ID is missing');
        return;
      }
      final result = await repo.getProductsPaginated(tenantId, limit: 50);
      state = state.copyWith(
        products: result.products,
        lastDocId: result.lastDocId,
        isLoadingMore: false,
        hasMore: result.products.length >= 50,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    
    try {
      state = state.copyWith(isLoadingMore: true, error: null);
      final result = await repo.getProductsPaginated(tenantId, limit: 50, lastDocId: state.lastDocId);
      
      state = state.copyWith(
        products: [...state.products, ...result.products],
        lastDocId: result.lastDocId,
        isLoadingMore: false,
        hasMore: result.products.length >= 50,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void updateProductInState(ProductModel updated) {
    final list = [...state.products];
    final idx = list.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
      state = state.copyWith(products: list);
    }
  }
}

final pagedGeneralProductsProvider = NotifierProvider<PagedGeneralProductsNotifier, PagedProductsState>(PagedGeneralProductsNotifier.new);

class PagedGeneralProductsNotifier extends Notifier<PagedProductsState> {
  @override
  PagedProductsState build() {
    ref.watch(tenantIdProvider);
    ref.watch(productStockVersionProvider);
    Future.microtask(() => loadInitial());
    return PagedProductsState(products: []);
  }

  ProductRepository get repo => ref.read(productRepositoryProvider);
  String get tenantId => ref.read(tenantIdProvider);

  Future<void> loadInitial() async {
    try {
      state = state.copyWith(isLoadingMore: true, error: null);
      if (tenantId.isEmpty) {
        state = state.copyWith(isLoadingMore: false, error: 'Tenant ID is missing');
        return;
      }
      final result = await repo.getProductsPaginated(tenantId, limit: 50);
      state = state.copyWith(
        products: result.products,
        lastDocId: result.lastDocId,
        isLoadingMore: false,
        hasMore: result.products.length >= 50,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    
    try {
      state = state.copyWith(isLoadingMore: true, error: null);
      final result = await repo.getProductsPaginated(tenantId, limit: 50, lastDocId: state.lastDocId);
      
      state = state.copyWith(
        products: [...state.products, ...result.products],
        lastDocId: result.lastDocId,
        isLoadingMore: false,
        hasMore: result.products.length >= 50,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  void updateProductInState(ProductModel updated) {
    final list = [...state.products];
    final idx = list.indexWhere((p) => p.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
      state = state.copyWith(products: list);
    }
  }
}

final productSearchQueryProvider = NotifierProvider<ProductSearchQuery, String>(ProductSearchQuery.new);

class ProductSearchQuery extends Notifier<String> {
  @override
  String build() => '';
  void set(String val) => state = val;
}

final filteredProductsProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final query = ref.watch(productSearchQueryProvider).toLowerCase();
  final productsAsync = ref.watch(productsFutureProvider);
  final allProducts = productsAsync.value ?? [];

  if (query.isEmpty) {
    return allProducts;
  } else {
    return allProducts.where((p) {
      return p.name.toLowerCase().contains(query) || 
             (p.barcode != null && p.barcode!.toLowerCase().contains(query));
    }).toList();
  }
});

final archivedProductsProvider = Provider.autoDispose((ref) {
  final productsAsync = ref.watch(productsFutureProvider);
  return productsAsync.whenData((products) {
    return products.where((p) => p.isArchived).toList();
  });
});

final categoryListProvider = Provider.autoDispose((ref) {
  final productsAsync = ref.watch(productsFutureProvider);
  return productsAsync.whenData((products) {
    return products.map((p) => p.category).toSet().toList()..sort();
  });
});

final lowStockProductsProvider = Provider.autoDispose((ref) {
  final productsAsync = ref.watch(productsFutureProvider);
  return productsAsync.whenData((products) {
    return products.where((p) {
      if (p.isArchived) return false;
      final threshold = p.minStockLevel ?? 5;
      return p.stockQuantity <= threshold;
    }).toList();
  });
});

final nearExpiryProductsProvider = Provider.autoDispose((ref) {
  final productsAsync = ref.watch(productsFutureProvider);
  return productsAsync.whenData((products) {
    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));
    return products.where((p) {
      if (p.expiryDate == null || p.isArchived) return false;
      return p.expiryDate!.isBefore(thirtyDaysLater);
    }).toList();
  });
});

final productCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  if (tenantId.isEmpty) return 0;
  return await repo.getProductCount(tenantId);
});

final inventoryValuationProvider = Provider.autoDispose((ref) {
  final productsAsync = ref.watch(productsFutureProvider);
  return productsAsync.whenData((products) {
    double totalValue = 0;
    for (final p in products) {
      if (p.isArchived) continue;
      totalValue += (p.stockQuantity * (p.purchasePrice ?? 0));
    }
    return totalValue;
  });
});

final totalProfitPotentialProvider = Provider.autoDispose((ref) {
  final productsAsync = ref.watch(productsFutureProvider);
  return productsAsync.whenData((products) {
    double totalProfit = 0;
    for (final p in products) {
      if (p.isArchived) continue;
      final cost = p.purchasePrice ?? 0;
      if (cost > 0) {
        totalProfit += (p.stockQuantity * (p.price - cost));
      }
    }
    return totalProfit;
  });
});
