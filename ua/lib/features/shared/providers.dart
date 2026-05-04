import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:user_app/core/config/app_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:user_app/core/services/firestore_service.dart';
import 'package:user_app/core/services/local_cache_service.dart';
import 'package:shared_models/shared_models.dart';
import 'package:user_app/core/utils/formatters.dart';
import 'package:user_app/core/services/notification_service.dart';

// --- Services ---
final firestoreServiceProvider = Provider((ref) => FirestoreService());
final localCacheServiceProvider = Provider((ref) => LocalCacheService());

// --- Auth Provider ---
// 1. Current Phone Cache
final userPhoneProvider = NotifierProvider<UserPhoneNotifier, String?>(UserPhoneNotifier.new);

class UserPhoneNotifier extends Notifier<String?> {
  bool _initialized = false;
  bool get initialized => _initialized;

  @override
  String? build() {
    _loadPhone();
    return null;
  }

  Future<void> _loadPhone() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString('user_phone');
    _initialized = true;
    ref.notifyListeners(); // Force refresh if needed
  }

  void setPhone(String? phone) {
    state = phone;
    _initialized = true;
  }
}

// Helper to check if auth state is ready
final isAuthInitializedProvider = Provider<bool>((ref) {
  final notifier = ref.watch(userPhoneProvider.notifier);
  return notifier.initialized;
});

// 2. Real-time User Data Stream
final userProvider = StreamProvider<UserModel?>((ref) {
  final phone = ref.watch(userPhoneProvider);
  if (phone == null) return Stream.value(null);
  
  final tenantId = ref.watch(currentTenantIdProvider);
  final compositeId = '${tenantId}_$phone';
  
  return FirebaseFirestore.instance
      .collection('users')
      .doc(compositeId)
      .snapshots()
      .map((doc) {
    if (!doc.exists) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return UserModel.fromJson(data);
  });
});

// Helper for User Actions
final userActionsProvider = Provider((ref) => UserActions(ref));

class UserActions {
  final Ref ref;
  UserActions(this.ref);

  Future<void> login(String phone, String password, {bool rememberMe = true}) async {
    final tenantId = await ref.read(resolvedTenantIdProvider.future);
    
    // Normalize phone: Ensure we try both 07... and 7... if it's a 10/11 digit number
    String cleanPhone = phone.trim();
    if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      cleanPhone = cleanPhone.substring(1);
    }
    
    final compositeId = '${tenantId}_$cleanPhone';
    final user = await ref.read(firestoreServiceProvider).getUser(compositeId);
    
    if (user == null) {
      // Fallback: Check if it was stored WITH the leading zero (older data)
      final legacyId = '${tenantId}_0$cleanPhone';
      final legacyUser = await ref.read(firestoreServiceProvider).getUser(legacyId);
      if (legacyUser == null) throw Exception('ACCOUNT_NOT_FOUND');
      
      if (legacyUser.password != password) throw Exception('WRONG_PASSWORD');
      if (rememberMe) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_phone', '0$cleanPhone');
      }
      ref.read(userPhoneProvider.notifier).setPhone('0$cleanPhone');
      return;
    }

    if (user.password != password) throw Exception('WRONG_PASSWORD');
    
    if (rememberMe) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_phone', cleanPhone);
    }
    ref.read(userPhoneProvider.notifier).setPhone(cleanPhone);
  }

  Future<void> register({
    required String name, 
    required String phone, 
    required String address, 
    String? landmark, 
    required String password,
    String? referredByCode,
  }) async {
    // Correctly track which tenant this user belongs to
    final resolvedId = await ref.read(resolvedTenantIdProvider.future);
    
    // Normalize phone for registration: strip leading zero to match country-picker standard
    String cleanPhone = phone.trim();
    if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      cleanPhone = cleanPhone.substring(1);
    }
    
    final compositeId = '${resolvedId}_$cleanPhone';
    
    // Generate a unique referral code (e.g., last 4 digits of phone + ms)
    final referralCode = cleanPhone.length >= 4 
        ? '${cleanPhone.substring(cleanPhone.length - 4)}${DateTime.now().millisecond}'
        : 'REF${DateTime.now().millisecondsSinceEpoch.toString().substring(10)}';

    var newUser = UserModel(
      id: compositeId,
      email: '$phone@$resolvedId.com',
      name: name,
      tenantId: resolvedId,
      loyaltyPoints: 50,
      password: password,
      address: address,
      landmark: landmark,
      phone: phone,
      createdAt: DateTime.now(),
      referralCode: referralCode,
      referredBy: referredByCode,
    );
    
    // Fetch default points from Tenant settings
    try {
      final tenantDoc = await FirebaseFirestore.instance.collection('tenants').doc(resolvedId).get();
      if (tenantDoc.exists) {
        final data = tenantDoc.data();
        if (data != null) {
          final points = data['registrationPoints'] as int? ?? AppConfig.defaultRegistrationPoints ?? 50;
          newUser = newUser.copyWith(loyaltyPoints: points);
        }
      }
    } catch (e) {
      // Ignore and use default 50
    }

    await ref.read(firestoreServiceProvider).saveUser(newUser);

    // Apply referral reward to the referrer
    if (referredByCode != null && referredByCode.isNotEmpty) {
      _applyReferralReward(resolvedId, referredByCode);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_phone', cleanPhone);
    await prefs.setString('user_address', address);
    
    ref.read(userPhoneProvider.notifier).setPhone(cleanPhone);
  }

  Future<void> _applyReferralReward(String tenantId, String code) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('tenantId', isEqualTo: tenantId)
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();
      
      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        final currentPoints = doc.data()['loyaltyPoints'] as int? ?? 0;
        await doc.reference.update({
          'loyaltyPoints': currentPoints + 50,
          'referralCount': FieldValue.increment(1),
        });
        debugPrint('Referral Reward: 50 points awarded to ${doc.id}');
      }
    } catch (e) {
      debugPrint('Referral Reward Error: $e');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_phone');
    ref.read(userPhoneProvider.notifier).setPhone(null);
  }

  Future<void> updateUserProfile({String? name, String? password, String? address, String? landmark}) async {
    final phone = ref.read(userPhoneProvider);
    if (phone == null) return;
    
    final tenantId = await ref.read(resolvedTenantIdProvider.future);
    final compositeId = '${tenantId}_$phone';
    
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (password != null) data['password'] = password;
    if (address != null) data['address'] = address;
    if (landmark != null) data['landmark'] = landmark;
    
    if (data.isNotEmpty) {
      await ref.read(firestoreServiceProvider).updateUser(compositeId, data);
    }
  }

  Future<void> addPoints(String phone, int amount) async {
    final tenantId = await ref.read(resolvedTenantIdProvider.future);
    final suffix = phone.contains('_') ? phone.split('_').last : phone;
    final compositeId = '${tenantId}_$suffix';
    final user = await ref.read(firestoreServiceProvider).getUser(compositeId);
    if (user != null) {
      await ref.read(firestoreServiceProvider).saveUser(user.copyWith(loyaltyPoints: user.loyaltyPoints + amount));
    }
  }

  Future<void> deductPoints(String phone, int amount) async {
    final tenantId = await ref.read(resolvedTenantIdProvider.future);
    final suffix = phone.contains('_') ? phone.split('_').last : phone;
    final compositeId = '${tenantId}_$suffix';
    final user = await ref.read(firestoreServiceProvider).getUser(compositeId);
    if (user != null) {
      await ref.read(firestoreServiceProvider).saveUser(user.copyWith(loyaltyPoints: (user.loyaltyPoints - amount).clamp(0, 999999)));
    }
  }

  Future<void> addPendingPoints(String phone, int amount) async {
    final tenantId = await ref.read(resolvedTenantIdProvider.future);
    final suffix = phone.contains('_') ? phone.split('_').last : phone;
    final compositeId = '${tenantId}_$suffix';
    final user = await ref.read(firestoreServiceProvider).getUser(compositeId);
    if (user != null) {
      await ref.read(firestoreServiceProvider).saveUser(user.copyWith(pendingPoints: user.pendingPoints + amount));
      if (amount > 0) {
        await ref.read(firestoreServiceProvider).updateDailyPurchasePoints(compositeId, amount);
      }
    }
  }

  Future<void> deductPendingPoints(String phone, int amount) async {
    final tenantId = await ref.read(resolvedTenantIdProvider.future);
    final suffix = phone.contains('_') ? phone.split('_').last : phone;
    final compositeId = '${tenantId}_$suffix';
    final user = await ref.read(firestoreServiceProvider).getUser(compositeId);
    if (user != null) {
      await ref.read(firestoreServiceProvider).saveUser(user.copyWith(pendingPoints: (user.pendingPoints - amount).clamp(0, 999999)));
    }
  }

  Future<bool> addReviewPoints(String phone, int amount) async {
    final tenantId = await ref.read(resolvedTenantIdProvider.future);
    final compositeId = '${tenantId}_$phone';
    final user = await ref.read(firestoreServiceProvider).getUser(compositeId);
    if (user != null) {
      await ref.read(firestoreServiceProvider).saveUser(user.copyWith(loyaltyPoints: user.loyaltyPoints + amount));
      return true;
    }
    return false;
  }
}

final currentTenantIdProvider = NotifierProvider<TenantIdNotifier, String>(TenantIdNotifier.new);

class TenantIdNotifier extends Notifier<String> {
  @override
  String build() {
    _loadFromCache();
    return AppConfig.tenantId;
  }

  Future<void> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('last_tenant_id');
    if (cached != null && state == 'auto') {
      state = cached;
    }
  }

  void setTenant(String id) async {
    if (state == id) return;
    state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_tenant_id', id);
  }
}

final resolvedTenantIdProvider = FutureProvider<String>((ref) async {
  final initialId = ref.watch(currentTenantIdProvider);
  if (initialId != 'auto') {
    return initialId;
  }

  try {
    // 1. Try to find the first active tenant
    final activeSnapshot = await FirebaseFirestore.instance
        .collection('tenants')
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (activeSnapshot.docs.isNotEmpty) {
      final id = activeSnapshot.docs.first.id;
      ref.read(currentTenantIdProvider.notifier).setTenant(id);
      return id;
    }

    // 2. Fallback: Find ANY tenant (maybe all are inactive due to a bug or new setup)
    final anySnapshot = await FirebaseFirestore.instance
        .collection('tenants')
        .limit(1)
        .get();

    if (anySnapshot.docs.isNotEmpty) {
      final id = anySnapshot.docs.first.id;
      return id;
    }
  } catch (e) {
    // Error resolving tenant
  }
  
  return initialId;
});

final tenantProvider = StreamProvider<TenantModel?>((ref) {
  final tenantIdAsync = ref.watch(resolvedTenantIdProvider);
  return tenantIdAsync.when(
    data: (id) => ref.watch(firestoreServiceProvider).getTenant(id),
    loading: () => Stream.value(null), // Avoid empty stream that might close
    error: (_, __) => Stream.value(null),
  );
});

// 1. Products (Cache-then-Network)
final productsProvider = StreamProvider<List<ProductModel>>((ref) async* {
  final cache = ref.watch(localCacheServiceProvider);
  final firestore = ref.watch(firestoreServiceProvider);
  
  // 1. Yield cached data immediately
  final cached = cache.getCachedProducts();
  if (cached.isNotEmpty) {
    yield cached;
  }

  // 2. Resolve tenant ID and listen to Firestore
  final id = await ref.watch(resolvedTenantIdProvider.future);
  
  await for (final products in firestore.getProducts(id)) {
    // 3. Update cache in background
    await cache.saveProducts(products);
    // 4. Yield fresh data
    yield products;
  }
});

// 2. Categories (Cache-then-Network)
final categoriesProvider = StreamProvider<List<CategoryModel>>((ref) async* {
  final cache = ref.watch(localCacheServiceProvider);
  final firestore = ref.watch(firestoreServiceProvider);

  // 1. Yield cached data
  final cached = cache.getCachedCategories();
  if (cached.isNotEmpty) {
    yield cached;
  }

  // 2. Listen to Firestore
  final id = await ref.watch(resolvedTenantIdProvider.future);
  await for (final categories in firestore.getCategories(id)) {
    // 3. Update cache
    await cache.saveCategories(categories);
    // 4. Yield fresh data
    yield categories;
  }
});

// 3. Favorites
final favoritesProvider = NotifierProvider<FavoritesNotifier, List<String>>(FavoritesNotifier.new);

class FavoritesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void toggleFavorite(String id) {
    if (state.contains(id)) {
      state = [for (final i in state) if (i != id) i];
    } else {
      state = [...state, id];
    }
  }
}

// 3. Reviews (Firestore Stream)
final productReviewsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, productId) async* {
  final tenantId = await ref.watch(resolvedTenantIdProvider.future);
  yield* ref.watch(firestoreServiceProvider).getReviews(tenantId, productId);
});

// 3.5 Coupons
final couponsProvider = StreamProvider<List<CouponModel>>((ref) async* {
  final tenantId = await ref.watch(resolvedTenantIdProvider.future);
  yield* ref.watch(firestoreServiceProvider).getCoupons(tenantId);
});

// 4. Cart
final cartProvider = NotifierProvider<CartNotifier, List<Map<String, dynamic>>>(CartNotifier.new);
final abandonedCartFlagProvider = NotifierProvider<AbandonedCartFlagNotifier, bool>(AbandonedCartFlagNotifier.new);

class AbandonedCartFlagNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  set state(bool value) => super.state = value;
}

class CartNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() => [];

  void addToCart(Map<String, dynamic> product) {
    // Ensure variants are set
    final item = {
      ...product,
      'color': product['color'] ?? 'Default',
      'size': product['size'] ?? 'Default',
    };
    state = [...state, item];
    _syncToFirestore();
  }
  void updateQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      removeFromCart(index);
      return;
    }
    var newState = [...state];
    newState[index] = {...newState[index], 'quantity': newQuantity};
    state = newState;
    _syncToFirestore();
  }

  void removeFromCart(int index) {
    var newState = [...state];
    newState.removeAt(index);
    state = newState;
    _syncToFirestore();
  }
  
  void clear() {
    state = [];
    _syncToFirestore();
  }

  Future<void> loadCartFromFirestore() async {
    final phone = ref.read(userPhoneProvider);
    if (phone == null) return;
    
    final tenantId = await ref.read(resolvedTenantIdProvider.future);
    final compositeId = '${tenantId}_$phone';
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(compositeId).get();
      if (doc.exists && doc.data()!.containsKey('cart')) {
        final cartData = doc.data()!['cart'] as List?;
        if (cartData != null && cartData.isNotEmpty) {
          state = cartData.cast<Map<String, dynamic>>();
          
          // Check for abandoned cart logic (e.g. older than 24h)
          final lastModified = doc.data()!['cartLastModified'] as Timestamp?;
          if (lastModified != null) {
            final diff = DateTime.now().difference(lastModified.toDate());
            if (diff.inHours >= 24) {
              // Set a flag that we can read in HomeScreen
              ref.read(abandonedCartFlagProvider.notifier).state = true;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Cart Load Error: $e');
    }
  }

  void _syncToFirestore() async {
    final phone = ref.read(userPhoneProvider);
    if (phone == null) return;
    
    final tenantId = await ref.read(resolvedTenantIdProvider.future);
    final compositeId = '${tenantId}_$phone';
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(compositeId).update({
        'cart': state,
        'cartLastModified': FieldValue.serverTimestamp(),
        'hasAbandonedCart': state.isNotEmpty,
      });
    } catch (e) {
      debugPrint('Cart Sync Error: $e');
    }
  }

  void loadFromOrder(OrderModel order) {
    state = order.items.map((i) => {
      'id': i['id'],
      'name': i['name'],
      'price': i['price'],
      'quantity': i['quantity'],
      'color': i['color'],
      'size': i['size'],
      'imageUrl': i['imageUrl'],
    }).toList();
  }

  Future<String> generateCartLink() async {
    return generatePartialCartLink(state.asMap().keys.toSet());
  }

  Future<String> generatePartialCartLink(Set<int> indices) async {
    final List<Map<String, dynamic>> minimalItems = indices.map((idx) {
      final i = state[idx];
      return {
        'id': i['id'],
        'q': i['quantity'],
        'c': i['color'],
        's': i['size'],
      };
    }).toList();
    
    final shareId = await ref.read(firestoreServiceProvider).createSharedCart(minimalItems);
    return shareId;
  }

  Future<void> loadFromSharedId(String shareId) async {
    try {
      final items = await ref.read(firestoreServiceProvider).getSharedCart(shareId);
      if (items == null) return;
      
      final products = ref.read(productsProvider).value ?? [];
      final List<Map<String, dynamic>> newItems = [];
      
      for (var d in items) {
        try {
          final product = products.firstWhere((p) => p.id == d['id']);
          newItems.add({
            ...product.toJson(),
            'quantity': d['q'] ?? 1,
            'color': d['c'] ?? 'Default',
            'size': d['s'] ?? 'Default',
          });
        } catch (_) {}
      }
      
      if (newItems.isNotEmpty) {
        state = [...state, ...newItems];
      }
    } catch (e) {
      // Error loading shared cart
    }
  }

  void loadFromLink(String data) {
    // Legacy support for Base64 links if needed, but we'll prefer loadFromSharedId
    try {
      final bytes = base64Url.decode(data);
      final jsonStr = utf8.decode(bytes);
      final List<dynamic> decoded = jsonDecode(jsonStr);
      
      final products = ref.read(productsProvider).value ?? [];
      
      final List<Map<String, dynamic>> newItems = [];
      for (var d in decoded) {
        try {
          final product = products.firstWhere((p) => p.id == d['id']);
          newItems.add({
            ...product.toJson(),
            'quantity': d['q'] ?? 1,
            'color': d['c'] ?? 'Default',
            'size': d['s'] ?? 'Default',
          });
        } catch (_) {
          // Skip if product not found
        }
      }
      state = [...state, ...newItems];
    } catch (e) {
      // Invalid link format
    }
  }
}

// 5. Orders
final ordersProvider = StreamProvider<List<OrderModel>>((ref) async* {
  final phone = ref.watch(userPhoneProvider);
  if (phone == null) {
    yield [];
    return;
  }
  
  final tenantId = await ref.watch(resolvedTenantIdProvider.future);
  final compositeId = '${tenantId}_$phone';
  yield* ref.watch(firestoreServiceProvider).getOrdersForUser(compositeId, tenantId);
});

// Helper for Order Actions
// --- Order Actions & State ---
final editingOrderIdProvider = NotifierProvider<EditingOrderIdNotifier, String?>(EditingOrderIdNotifier.new);

class EditingOrderIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? id) => state = id;
}

final orderActionsProvider = Provider((ref) => OrderActions(ref));

class OrderActions {
  final Ref ref;
  OrderActions(this.ref);

  Future<String> placeOrder({
    required List<Map<String, dynamic>> items,
    required double total,
    required String address,
    required String userName,
    required String userPhone,
    required int pointsAwarded,
    required int pointsRedeemed,
    double discountAmount = 0.0,
    double shippingCost = 0.0,
    String? couponCode,
    String? orderId,
    String? landmark,
  }) async {
    final resolvedId = await ref.read(resolvedTenantIdProvider.future);
    
    final finalOrderId = orderId ?? 'ORD${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final suffix = userPhone.contains('_') ? userPhone.split('_').last : userPhone;
    final newOrder = OrderModel(
      id: finalOrderId,
      tenantId: resolvedId,
      userId: '${resolvedId}_$suffix',
      userName: userName,
      userPhone: userPhone,
      total: total,
      items: items,
      date: DateTime.now(),
      address: address,
      landmark: landmark,
      pointsAwarded: pointsAwarded,
      pointsRedeemed: pointsRedeemed,
      discountAmount: discountAmount,
      shippingCost: shippingCost,
      couponCode: couponCode,
    );

    print('OrderActions: Saving order and updating stock atomically via Transaction...');
    await ref.read(firestoreServiceProvider).placeOrder(newOrder);
    
    print('OrderActions: Order placed successfully. Sending notifications...');
    
    // 2. Send notification to admin with orderId for deep linking
    try {
      // Send legacy Firestore notification (for local listener)
      await ref.read(firestoreServiceProvider).sendAdminNotification(
        resolvedId, 
        'New Order #${newOrder.id}', 
        'Customer ${newOrder.userName} has placed a new order for ${formatCurrency(newOrder.total)}',
        orderId: finalOrderId,
      );
      
      // Send OneSignal notification (for background)
      await ref.read(notificationServiceProvider).sendAdminNotification(
        tenantId: resolvedId,
        title: 'New Order #${newOrder.id}',
        body: 'Customer ${newOrder.userName} has placed a new order for ${formatCurrency(newOrder.total)}',
        orderId: finalOrderId,
      );
    } catch (e) {
       print('OrderActions: Notification failed (non-critical): $e');
    }
    
    return finalOrderId;
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final tenantId = await ref.read(resolvedTenantIdProvider.future);
    await ref.read(firestoreServiceProvider).updateOrderStatus(tenantId, orderId, status, 'Status updated');
  }

  Future<void> cancelOrder(String orderId) async {
    final asyncUser = ref.read(userProvider);
    final user = asyncUser.value;
    if (user == null) throw Exception('User not logged in');
    
    final orders = await ref.read(ordersProvider.future);
    final order = orders.firstWhere((o) => o.id == orderId);
    
    for (var item in order.items) {
      try {
        final productId = (item['productId'] ?? item['id']) as String?;
        if (productId != null) {
          final tenantId = await ref.read(resolvedTenantIdProvider.future);
          await ref.read(firestoreServiceProvider).updateProductVariantStock(
            tenantId,
            productId,
            item['color'] as String? ?? 'Default',
            item['size'] as String? ?? 'Default',
            -(item['quantity'] as int? ?? 1),
          );
        }
      } catch (_) {}
    }

    await updateOrderStatus(orderId, OrderStatus.cancelled);

    if (order.pointsRedeemed > 0) {
      await ref.read(userActionsProvider).addPoints(user.id, order.pointsRedeemed);
    }
    
    if (order.pointsAwarded > 0) {
      await ref.read(userActionsProvider).deductPendingPoints(user.id, order.pointsAwarded);
    }
    
    ref.invalidate(ordersProvider);
  }

  Future<void> updateOrderItems(OrderModel order, List<Map<String, dynamic>> items, double newTotal) async {
    // 1. Calculate the difference in stock for each item
    for (var oldItem in order.items) {
      final oldId = (oldItem['productId'] ?? oldItem['id']) as String?;
      final oldQty = oldItem['quantity'] as int? ?? 0;
      final oldColor = oldItem['color'] as String? ?? 'Default';
      final oldSize = oldItem['size'] as String? ?? 'Default';

      // Find this item in the NEW list
      final newItem = items.firstWhere(
        (i) => (i['productId'] ?? i['id']) == oldId && i['color'] == oldColor && i['size'] == oldSize,
        orElse: () => <String, dynamic>{'quantity': 0},
      );
      final newQty = newItem['quantity'] as int? ?? 0;

      final diff = newQty - oldQty;
      if (diff != 0 && oldId != null) {
        final tenantId = await ref.read(resolvedTenantIdProvider.future);
        // Use updateProductVariantStock with the difference
        await ref.read(firestoreServiceProvider).updateProductVariantStock(tenantId, oldId, oldColor, oldSize, diff);
      }
    }

    // Check for NEWLY added items that weren't in the old order (though currently User app UI usually just adjusts existing ones)
    for (var newItem in items) {
       final newId = (newItem['productId'] ?? newItem['id']) as String?;
       final newColor = newItem['color'] as String? ?? 'Default';
       final newSize = newItem['size'] as String? ?? 'Default';
       final newQty = newItem['quantity'] as int? ?? 0;

        final existsInOld = order.items.any((i) => (i['productId'] ?? i['id']) == newId && i['color'] == newColor && i['size'] == newSize);
        if (!existsInOld && newId != null) {
          final tenantId = await ref.read(resolvedTenantIdProvider.future);
          await ref.read(firestoreServiceProvider).updateProductVariantStock(tenantId, newId, newColor, newSize, newQty);
        }
    }

    // 2. Update Firestore (Top-level collection for consistency)
    final tenantId = await ref.read(resolvedTenantIdProvider.future);
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(order.id)
        .update({
      'items': items,
      'total': newTotal,
    });
    
    ref.invalidate(ordersProvider);
  }

  Future<void> deleteOrder(String orderId) async {
    final tenantId = await ref.read(resolvedTenantIdProvider.future);
    await ref.read(firestoreServiceProvider).deleteOrder(tenantId, orderId);
    ref.invalidate(ordersProvider);
  }

  Future<void> updateOrderInfo(String orderId, String address, String phone) async {
    final tenantId = await ref.read(resolvedTenantIdProvider.future);
    await FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .update({
      'address': address,
      'userPhone': phone,
    });
    ref.invalidate(ordersProvider);
  }
}

// 6. Promo Banners
final bannersProvider = StreamProvider<List<PromoBannerModel>>((ref) async* {
  final tenantId = await ref.watch(resolvedTenantIdProvider.future);
  yield* ref.watch(firestoreServiceProvider).getBanners(tenantId);
});

// 7. Chat
final chatMessagesProvider = StreamProvider<List<ChatMessageModel>>((ref) async* {
  final user = ref.watch(userProvider).value;
  if (user == null) {
    yield [];
    return;
  }
  yield* ref.watch(firestoreServiceProvider).getChatMessages(user.id);
});

// --- Error Handling ---
final globalErrorProvider = NotifierProvider<GlobalErrorNotifier, String?>(GlobalErrorNotifier.new);

class GlobalErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void set(String? error) => state = error;
}

base class GlobalErrorObserver extends ProviderObserver {
  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (newValue is AsyncError) {
      final error = newValue.error.toString();
      // Silently log or handle specific errors
      final isPermissionErr = error.contains('permission-denied') || error.contains('not have permission');
      if (!error.contains('Null check operator used on a null value') && !isPermissionErr) {
        context.container.read(globalErrorProvider.notifier).set('Error: $error');
      }
    }
  }
}
