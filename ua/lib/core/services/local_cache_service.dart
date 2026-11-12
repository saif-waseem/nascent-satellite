import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:shared_models/shared_models.dart';

class LocalCacheService {
  static const String productsBoxName = 'products';
  static const String categoriesBoxName = 'categories';
  static const String tenantsBoxName = 'tenants';
  static const String userBoxName = 'user_profile';
  static const String ordersBoxName = 'user_orders';

  Future<void> init() async {
    try {
      await Hive.initFlutter();
      
      // Register Adapters
      _registerIfMissing(ProductModelAdapter());
      _registerIfMissing(ProductVariantAdapter());
      _registerIfMissing(CategoryModelAdapter());
      _registerIfMissing(TenantModelAdapter());
      _registerIfMissing(UserModelAdapter());
      _registerIfMissing(OrderModelAdapter());
      _registerIfMissing(OrderStatusAdapter());

      // Open Boxes
      await Hive.openBox<ProductModel>(productsBoxName);
      await Hive.openBox<CategoryModel>(categoriesBoxName);
      await Hive.openBox<TenantModel>(tenantsBoxName);
      await Hive.openBox<UserModel>(userBoxName);
      await Hive.openBox<OrderModel>(ordersBoxName);
    } catch (e) {}
  }

  void _registerIfMissing(TypeAdapter adapter) {
    try {
      if (!Hive.isAdapterRegistered(adapter.typeId)) {
        Hive.registerAdapter(adapter);
      }
    } catch (_) {}
  }

  // --- Products ---
  Box<ProductModel>? get _productsBox => Hive.isBoxOpen(productsBoxName) ? Hive.box<ProductModel>(productsBoxName) : null;

  Future<void> saveProducts(List<ProductModel> products) async {
    final box = _productsBox;
    if (box == null) return;
    try {
      await box.clear(); // Keep only fresh products
      final Map<String, ProductModel> map = {
        for (var p in products) p.id: p
      };
      await box.putAll(map);
    } catch (e) {}
  }

  List<ProductModel> getCachedProducts() {
    return _productsBox?.values.toList() ?? [];
  }

  // --- Categories ---
  Box<CategoryModel>? get _categoriesBox => Hive.isBoxOpen(categoriesBoxName) ? Hive.box<CategoryModel>(categoriesBoxName) : null;

  Future<void> saveCategories(List<CategoryModel> categories) async {
    final box = _categoriesBox;
    if (box == null) return;
    try {
      await box.clear();
      final Map<String, CategoryModel> map = {
        for (var c in categories) c.id: c
      };
      await box.putAll(map);
    } catch (e) {}
  }

  List<CategoryModel> getCachedCategories() {
    return _categoriesBox?.values.toList() ?? [];
  }

  // --- User Profile ---
  Box<UserModel>? get _userBox => Hive.isBoxOpen(userBoxName) ? Hive.box<UserModel>(userBoxName) : null;

  Future<void> saveUser(UserModel user, String tenantId) async {
    await _userBox?.put('current_$tenantId', user);
  }

  UserModel? getCachedUser(String tenantId) {
    return _userBox?.get('current_$tenantId');
  }

  // --- Orders ---
  Box<OrderModel>? get _ordersBox => Hive.isBoxOpen(ordersBoxName) ? Hive.box<OrderModel>(ordersBoxName) : null;

  Future<void> saveOrders(List<OrderModel> orders) async {
    final box = _ordersBox;
    if (box == null) return;
    try {
      await box.clear();
      final Map<String, OrderModel> map = {
        for (var o in orders) o.id: o
      };
      await box.putAll(map);
    } catch (e) {}
  }

  List<OrderModel> getCachedOrders() {
    return _ordersBox?.values.toList() ?? [];
  }

  // --- Tenants ---
  Box<TenantModel>? get _tenantsBox => Hive.isBoxOpen(tenantsBoxName) ? Hive.box<TenantModel>(tenantsBoxName) : null;

  Future<void> saveTenant(TenantModel tenant) async {
    final box = _tenantsBox;
    if (box == null) return;
    try {
      await box.put(tenant.id, tenant);
    } catch (e) {}
  }

  TenantModel? getCachedTenant(String tenantId) {
    return _tenantsBox?.get(tenantId);
  }

  Future<void> clearAll() async {
    try {
      await _productsBox?.clear();
      await _categoriesBox?.clear();
      await _tenantsBox?.clear();
      await _userBox?.clear();
      await _ordersBox?.clear();
    } catch (e) {}
  }
}
