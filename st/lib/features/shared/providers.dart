import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_admin/core/services/admin_firestore_service.dart';
import 'package:store_admin/core/services/admin_supabase_service.dart';
import 'package:store_admin/core/services/storage_service.dart';
import 'package:store_admin/core/services/notification_service.dart';
import 'package:store_admin/core/services/analytics_service.dart';
import 'package:shared_models/shared_models.dart';

import 'package:store_admin/core/services/local_cache_service.dart';
import 'package:store_admin/core/services/service_config_service.dart';

// --- Services ---
final adminFirestoreServiceProvider = Provider((ref) => AdminFirestoreService());
final adminSupabaseServiceProvider = Provider((ref) => AdminSupabaseService());
final localCacheServiceProvider = Provider((ref) => LocalCacheService());

final storageServiceProvider = Provider((ref) {
  final config = ref.watch(serviceConfigProvider).value ?? ServiceConfig(
    imageService: 'imgbb',
    imageApiKey: '4c2a2e4993d69bf3fe8bf8d09d1a2520',
    videoService: 'disabled',
    videoLibraryId: '',
    videoApiKey: '',
  );
  return StorageService(config);
});

final notificationServiceProvider = Provider((ref) => NotificationService());
final analyticsServiceProvider = Provider((ref) => AnalyticsService());

final dataHealthProvider = FutureProvider((ref) async {
  final tenantId = ref.watch(currentTenantIdProvider);
  return ref.read(analyticsServiceProvider).checkHealth(tenantId);
});

// --- Current Tenant (Store) Auth State ---
enum TenantAuthStatus { initial, verifying, unauthenticated, authenticated }

class TenantAuthState {
  final String tenantId;
  final TenantAuthStatus status;
  final String? error;

  TenantAuthState({
    this.tenantId = '',
    this.status = TenantAuthStatus.initial,
    this.error,
  });

  TenantAuthState copyWith({
    String? tenantId,
    TenantAuthStatus? status,
    String? error,
  }) {
    return TenantAuthState(
      tenantId: tenantId ?? this.tenantId,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

final currentTenantAuthProvider = NotifierProvider<TenantAuthNotifier, TenantAuthState>(TenantAuthNotifier.new);

class TenantAuthNotifier extends Notifier<TenantAuthState> {
  @override
  TenantAuthState build() {
    // Start verification immediately
    _loadAndVerifyTenant();
    return TenantAuthState(status: TenantAuthStatus.verifying);
  }

  Future<void> _loadAndVerifyTenant() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('tenant_id');
    
    if (saved == null || saved.isEmpty) {
      // For Dar London specific build, default to 'landan'
      await setTenant('landan');
      return;
    }

    try {
      // Stream for real-time updates but we just need the first value for initial verification
      final tenant = await ref.read(adminFirestoreServiceProvider).getTenant(saved).first;
      
      if (tenant == null || !tenant.isActive) {
        await clearTenant();
      } else {
        state = state.copyWith(
          tenantId: saved,
          status: TenantAuthStatus.authenticated,
        );
      }
    } catch (e) {
      // Network error, assume cached ID is still valid but log it
      state = state.copyWith(
        tenantId: saved,
        status: TenantAuthStatus.authenticated,
        error: e.toString(),
      );
    }
  }
  
  Future<void> setTenant(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tenant_id', id);
    state = state.copyWith(
      tenantId: id,
      status: TenantAuthStatus.authenticated,
    );
  }

  Future<void> clearTenant() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tenant_id');
    state = TenantAuthState(status: TenantAuthStatus.unauthenticated);
  }
}

// Keep currentTenantIdProvider for backward compatibility but redirect it
final currentTenantIdProvider = Provider<String>((ref) {
  return ref.watch(currentTenantAuthProvider).tenantId;
});

final isAppVerifyingProvider = Provider<bool>((ref) {
  return ref.watch(currentTenantAuthProvider).status == TenantAuthStatus.verifying;
});

final tenantProvider = StreamProvider<TenantModel?>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  if (tenantId.isEmpty) return Stream.value(null);
  return ref.watch(adminFirestoreServiceProvider).getTenant(tenantId);
});

// --- Products (Cache-First -> Supabase SQL Primary -> Firestore Fallback) ---
final adminProductsProvider = StreamProvider<List<ProductModel>>((ref) async* {
  final cache = ref.watch(localCacheServiceProvider);
  final supabase = ref.watch(adminSupabaseServiceProvider);
  final firestore = ref.watch(adminFirestoreServiceProvider);
  final tenantId = ref.watch(currentTenantIdProvider);
  
  // 1. Yield cached data immediately (instant zero-latency display)
  final cached = cache.getCachedProducts();
  if (cached.isNotEmpty) {
    yield cached;
  }

  // 2. Stream from Supabase SQL (Fast & Iraq friendly)
  if (tenantId.isNotEmpty) {
    try {
      await for (final products in supabase.getProductsStream(tenantId)) {
        await cache.saveProducts(products);
        yield products;
      }
    } catch (_) {
      // Fallback to Firestore if offline or during transition
      await for (final products in firestore.getProducts(tenantId)) {
        await cache.saveProducts(products);
        yield products;
      }
    }
  }
});

// --- Orders ---
final adminOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  return ref.watch(adminFirestoreServiceProvider).getAllOrders(tenantId);
});

// --- POS Sales Invoices Sync (مزامنة فواتير ومبيعات الكاشير) ---
final adminPosInvoicesProvider = StreamProvider<List<SalesInvoiceModel>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  return ref.watch(adminFirestoreServiceProvider).getSalesInvoices(tenantId);
});

// --- Customers ---
final customerListProvider = StreamProvider<List<UserModel>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  return ref.watch(adminFirestoreServiceProvider).getCustomers(tenantId);
});

// --- Categories (Cache-First -> Supabase SQL Primary -> Firestore Fallback) ---
final adminCategoriesProvider = StreamProvider<List<CategoryModel>>((ref) async* {
  final cache = ref.watch(localCacheServiceProvider);
  final supabase = ref.watch(adminSupabaseServiceProvider);
  final firestore = ref.watch(adminFirestoreServiceProvider);
  final tenantId = ref.watch(currentTenantIdProvider);

  // 1. Yield cached data
  final cached = cache.getCachedCategories();
  if (cached.isNotEmpty) {
    yield cached;
  }

  // 2. Stream from Supabase SQL
  if (tenantId.isNotEmpty) {
    try {
      await for (final categories in supabase.getCategoriesStream(tenantId)) {
        await cache.saveCategories(categories);
        yield categories;
      }
    } catch (_) {
      // Fallback to Firestore
      await for (final categories in firestore.getCategories(tenantId)) {
        await cache.saveCategories(categories);
        yield categories;
      }
    }
  }
});

final stockPredictionsProvider = FutureProvider<Map<String, double>>((ref) {
  final tenantId = ref.watch(currentTenantIdProvider);
  return ref.read(analyticsServiceProvider).getStockPredictions(tenantId);
});

// --- UI State ---
final adminOrderSearchProvider = NotifierProvider<AdminOrderSearchNotifier, String>(AdminOrderSearchNotifier.new);

class AdminOrderSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  
  void setSearch(String query) => state = query;
}

final globalSettingsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  return ref.watch(adminFirestoreServiceProvider).getGlobalSettings();
});
