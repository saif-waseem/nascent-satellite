import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';

class AdminFirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Store Settings (Tenant) ---
  Stream<TenantModel?> getTenant(String tenantId) {
    return _db.collection('tenants').doc(tenantId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      final data = doc.data()!;
      data['id'] = doc.id;
      return TenantModel.fromJson(data);
    }).handleError((_) => null);
  }

  Future<void> updateTenant(TenantModel tenant) async {
    await _db.collection('tenants').doc(tenant.id).set(tenant.toJson(), SetOptions(merge: true));
  }

  // --- Categories ---
  Stream<List<CategoryModel>> getCategories(String tenantId) async* {
    while (true) {
      try {
        final snapshot = await _db
            .collection('categories')
            .where('tenantId', isEqualTo: tenantId)
            .get();
        yield snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return CategoryModel.fromJson(data);
        }).toList();
      } catch (e) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> addCategory(CategoryModel category, String tenantId) async {
    final docRef = _db.collection('categories').doc();
    final newCategory = category.toJson();
    newCategory['id'] = docRef.id;
    newCategory['tenantId'] = tenantId;
    await docRef.set(newCategory);
  }

  Future<void> updateCategory(CategoryModel category, String tenantId) async {
    await _db.collection('categories').doc(category.id).set(category.toJson(), SetOptions(merge: true));
  }

  Future<void> deleteCategory(String categoryId, String tenantId) async {
    await _db.collection('categories').doc(categoryId).delete();
  }

  // --- Products ---
  Stream<List<ProductModel>> getProducts(String tenantId) async* {
    while (true) {
      try {
        final snapshot = await _db
            .collection('products')
            .where('tenantId', isEqualTo: tenantId)
            .get();
        yield snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return ProductModel.fromJson(data);
        }).toList();
      } catch (e) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> addProduct(ProductModel product, String tenantId) async {
    final docRef = _db.collection('products').doc();
    final newProduct = product.toJson();
    newProduct['id'] = docRef.id;
    newProduct['tenantId'] = tenantId;
    await docRef.set(newProduct);
  }

  Future<void> updateProduct(ProductModel product, String tenantId) async {
    await _db.collection('products').doc(product.id).set(product.toJson(), SetOptions(merge: true));
  }

  Future<void> deleteProduct(String productId, String tenantId) async {
    await _db.collection('products').doc(productId).delete();
  }

  // --- Orders ---
  Stream<List<OrderModel>> getAllOrders(String tenantId) async* {
    while (true) {
      try {
        final snapshot = await _db
            .collection('orders')
            .where('tenantId', isEqualTo: tenantId)
            .get();
        final orders = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return OrderModel.fromJson(data);
        }).where((o) => !o.isHiddenForAdmin).toList();
        orders.sort((a, b) => b.date.compareTo(a.date));
        yield orders;
      } catch (e) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  // --- Settings ---
  Stream<Map<String, dynamic>> getGlobalSettings() async* {
    while (true) {
      try {
        final doc = await _db.collection('settings').doc('global').get();
        yield doc.data() ?? {};
      } catch (e) {
        yield {};
      }
      await Future.delayed(const Duration(seconds: 10));
    }
  }

  Future<void> deleteOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).update({'isHiddenForAdmin': true});
  }

  Future<void> updateOrderDiscount(OrderModel order, double discount) async {
    final subtotal = order.items.fold<double>(0, (sum, i) => sum + ((i['price'] as num?)?.toDouble() ?? 0.0) * ((i['quantity'] as num?)?.toInt() ?? 1));
    // Assuming 10 points = 1 currency unit as per standard admin logic
    final newTotal = subtotal + order.shippingCost - (order.pointsRedeemed / 10.0) - discount;
    
    await _db.collection('orders').doc(order.id).update({
      'discountAmount': discount,
      'total': newTotal,
    });
  }

  Future<void> updateOrderItems(OrderModel order, List<Map<String, dynamic>> items) async {
    final subtotal = items.fold<double>(0, (sum, i) => sum + ((i['price'] as num?)?.toDouble() ?? 0.0) * ((i['quantity'] as num?)?.toInt() ?? 1));
    final newTotal = subtotal + order.shippingCost - (order.pointsRedeemed / 10.0) - order.discountAmount;
    
    await _db.collection('orders').doc(order.id).update({
      'items': items,
      'total': newTotal,
    });
  }

  Future<void> updateOrderStatus(OrderModel order, OrderStatus newStatus, String tracking) async {
    final batch = _db.batch();
    final orderRef = _db.collection('orders').doc(order.id);
    
    batch.update(orderRef, {
      'status': newStatus.name,
      'tracking': tracking,
    });

    // If order is completed, update customer stats and product salesCount
    if (newStatus == OrderStatus.completed && order.status != OrderStatus.completed) {
      final userRef = _db.collection('users').doc(order.userId);
      batch.update(userRef, {
        'totalSpent': FieldValue.increment(order.total),
        'loyaltyPoints': FieldValue.increment(order.pointsAwarded),
        'pendingPoints': FieldValue.increment(-order.pointsAwarded),
        'purchaseCount': FieldValue.increment(1), 
      });

      // Update product salesCount for each item
      for (var item in order.items) {
        final productId = (item['productId'] ?? item['id']) as String?;
        if (productId != null) {
          final productRef = _db.collection('products').doc(productId);
          batch.update(productRef, {
            'salesCount': FieldValue.increment(item['quantity'] as int? ?? 1),
          });
        }
      }
    }

    // If order is cancelled and was previously completed, revert everything
    if (newStatus == OrderStatus.cancelled && order.status == OrderStatus.completed) {
       final userRef = _db.collection('users').doc(order.userId);
       batch.update(userRef, {
        'totalSpent': FieldValue.increment(-order.total),
        'loyaltyPoints': FieldValue.increment(-order.pointsAwarded),
        'purchaseCount': FieldValue.increment(-1),
      });

      // Revert product salesCount and return to stock (variant-aware)
      for (var item in order.items) {
        _revertStock(item, revertSalesCount: true);
      }
    }

    // If order is cancelled but was NOT completed (still active/pending), just remove pending points and return to stock
    // If order is cancelled but was NOT completed (still active/pending), just remove pending points and return to stock
    if (newStatus == OrderStatus.cancelled && order.status == OrderStatus.active) {
       final userRef = _db.collection('users').doc(order.userId);
       batch.update(userRef, {
        'pendingPoints': FieldValue.increment(-order.pointsAwarded),
      });

      // Return to stock (assuming it was deducted at checkout) - variant-aware
      for (var item in order.items) {
        _revertStock(item, revertSalesCount: false);
      }
    }

    await batch.commit();
  }

  /// Helper to safely revert stock for an item, including variant-specific stock
  Future<void> _revertStock(Map<String, dynamic> item, {required bool revertSalesCount}) async {
    final productId = (item['productId'] ?? item['id']) as String?;
    if (productId == null) return;

    final color = item['color'] as String? ?? 'Default';
    final size = item['size'] as String? ?? 'Default';
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;

    final productRef = _db.collection('products').doc(productId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(productRef);
      if (!snapshot.exists) return;

      final data = snapshot.data()!;
      final variants = (data['variants'] as List? ?? []).cast<Map<String, dynamic>>();
      
      bool variantFound = false;
      final updatedVariants = variants.map((v) {
        if (v['color'] == color && v['size'] == size) {
          variantFound = true;
          return {
            ...v,
            'stock': (v['stock'] as int? ?? 0) + quantity,
          };
        }
        return v;
      }).toList();

      // If variant wasn't found (maybe deleted or 'Default' didn't exist), we still increment total stock
      // but we don't force a variant unless it was already there.
      
      final updates = <String, dynamic>{
        'stockQuantity': FieldValue.increment(quantity),
        'inStock': true,
      };

      if (variantFound) {
        updates['variants'] = updatedVariants;
      } else if (variants.isEmpty) {
        // If product has no variants, the total stock update above is enough
        // but we explicitly log or ensure we don't try to update variants
      }

      if (revertSalesCount) {
        updates['salesCount'] = FieldValue.increment(-quantity);
      }

      transaction.update(productRef, updates);
    });
  }

  // --- Customers (Users) ---
  Stream<List<UserModel>> getCustomers(String tenantId) async* {
    while (true) {
      try {
        final snapshot = await _db
            .collection('users')
            .where('tenantId', isEqualTo: tenantId)
            .get();
        yield snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return UserModel.fromJson(data);
        }).toList();
      } catch (e) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> updateUserPoints(String userId, int points) async {
    await _db.collection('users').doc(userId).update({'loyaltyPoints': points});
  }

  Future<void> toggleUserBlock(String userId, bool block) async {
    await _db.collection('users').doc(userId).update({'isBlocked': block});
  }

  // --- Coupons ---
  Stream<List<CouponModel>> getCoupons(String tenantId) async* {
    while (true) {
      try {
        final snapshot = await _db
            .collection('tenants')
            .doc(tenantId)
            .collection('coupons')
            .get();
        yield snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return CouponModel.fromJson(data);
        }).toList();
      } catch (e) {
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  Future<void> addCoupon(String tenantId, CouponModel coupon) async {
    final normalized = coupon.copyWith(code: coupon.code.trim().toUpperCase());
    await _db
        .collection('tenants')
        .doc(tenantId)
        .collection('coupons')
        .add(normalized.toJson());
  }

  Future<void> updateCoupon(String tenantId, CouponModel coupon) async {
    final normalized = coupon.copyWith(code: coupon.code.trim().toUpperCase());
    await _db
        .collection('tenants')
        .doc(tenantId)
        .collection('coupons')
        .doc(coupon.id)
        .set(normalized.toJson(), SetOptions(merge: true));
  }

  Future<void> deleteCoupon(String tenantId, String couponId) async {
    await _db
        .collection('tenants')
        .doc(tenantId)
        .collection('coupons')
        .doc(couponId)
        .delete();
  }

  // --- Marketing ---
  Future<void> sendMarketingNotification(String tenantId, String title, String body, {String? productId, String? actionUrl}) async {
    // Add to a global collection that users listen to, or many user sub-collections
    // For simplicity and "Background" support without real FCM, we'll use a global collection
    await _db.collection('marketing_notifications').add({
      'tenantId': tenantId,
      'title': title,
      'body': body,
      'productId': productId,
      'actionUrl': actionUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
