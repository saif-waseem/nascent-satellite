import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:shared_models/shared_models.dart';

class LocalCacheService {
  static const String productsBoxName = 'products';
  static const String categoriesBoxName = 'categories';
  static const String tenantsBoxName = 'tenants';

  Future<void> init() async {
    await Hive.initFlutter();
    
    // Register Adapters (MUST match typeIds in shared_models)
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ProductModelAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(ProductVariantAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CategoryModelAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(TenantModelAdapter());

    // Open Boxes
    await Hive.openBox<ProductModel>(productsBoxName);
    await Hive.openBox<CategoryModel>(categoriesBoxName);
    await Hive.openBox<TenantModel>(tenantsBoxName);
  }

  // --- Products ---
  Box<ProductModel> get _productsBox => Hive.box<ProductModel>(productsBoxName);

  Future<void> saveProducts(List<ProductModel> products) async {
    final Map<String, ProductModel> map = {
      for (var p in products) p.id: p
    };
    await _productsBox.putAll(map);
  }

  List<ProductModel> getCachedProducts() {
    return _productsBox.values.toList();
  }

  // --- Categories ---
  Box<CategoryModel> get _categoriesBox => Hive.box<CategoryModel>(categoriesBoxName);

  Future<void> saveCategories(List<CategoryModel> categories) async {
    final Map<String, CategoryModel> map = {
      for (var c in categories) c.id: c
    };
    await _categoriesBox.putAll(map);
  }

  List<CategoryModel> getCachedCategories() {
    return _categoriesBox.values.toList();
  }

  // --- Tenants ---
  Box<TenantModel> get _tenantsBox => Hive.box<TenantModel>(tenantsBoxName);

  Future<void> saveTenant(TenantModel tenant) async {
    await _tenantsBox.put(tenant.id, tenant);
  }

  TenantModel? getCachedTenant(String tenantId) {
    return _tenantsBox.get(tenantId);
  }

  Future<void> clearAll() async {
    await _productsBox.clear();
    await _categoriesBox.clear();
    await _tenantsBox.clear();
  }
}
