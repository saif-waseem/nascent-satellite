import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';

class FirestoreService {
  final stockSync = OrderStockSync(() async => FirebaseAuth.instance.currentUser?.getIdToken());
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- Users ---
  Future<void> saveUser(UserModel user) async {
    await _db.collection('users').doc(user.id).set(user.toJson(), SetOptions(merge: true));
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _db.collection('users').doc(userId).update(data);
  }

  Future<UserModel?> getUser(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return UserModel.fromJson(data);
  }

  // --- Tenant ---
  Stream<TenantModel?> getTenant(String tenantId) {
    return _db.collection('tenants').doc(tenantId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      data['id'] = doc.id;
      return TenantModel.fromJson(data);
    });
  }

  // --- Products ---
  Stream<List<ProductModel>> getProducts(String tenantId) {
    return ProductCatalog.watch(tenantId, () async {
      final snapshot = await _db.collection('products').where('tenantId',isEqualTo:tenantId).get();
      return snapshot.docs.map((doc)=>ProductModel.fromJson({...doc.data(),'id':doc.id})).toList();
    });
  }

  // --- Categories ---
  Stream<List<CategoryModel>> getCategories(String tenantId) {
    return _db
        .collection('categories')
        .where('tenantId', isEqualTo: tenantId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return CategoryModel.fromJson(data);
      }).toList();
    });
  }

  // --- Orders ---
  Future<void> placeOrder(OrderModel order, {String? couponId}) async {
    try {
      print('FirestoreService: Placing order ${order.id} for tenant ${order.tenantId}');
      final orderRef = _db.collection('orders').doc(order.id);
      await _db.runTransaction((transaction) async {
        final old = (await transaction.get(orderRef)).data();
        if (old != null && (old['tenantId'] != order.tenantId || old['userId'] != order.userId || old['status'] != 'active')) {
          throw StateError('تعذر تعديل هذا الطلب');
        }
        final changes = <String, Map<(String,String),int>>{};
        void count(Iterable<dynamic> items, int sign) {
          for (final item in items) {
            final id = (item['productId'] ?? item['id']) as String;
            final key = ((item['color'] ?? 'Default') as String,(item['size'] ?? 'Default') as String);
            final qty = item['quantity'] as int;
            if (qty < 1) throw StateError('كمية غير صالحة');
            (changes[id] ??= {}).update(key,(n)=>n+sign*qty,ifAbsent:()=>sign*qty);
          }
        }
        count(old?['items'] as List? ?? [], -1);
        count(order.items, 1);
        final updates = <DocumentReference<Map<String,dynamic>>,Map<String,dynamic>>{};
        for (final entry in changes.entries) {
          if (entry.value.values.every((v)=>v == 0)) continue;
          final productRef = _db.collection('products').doc(entry.key);
          final data = (await transaction.get(productRef)).data();
          if (data == null || data['tenantId'] != order.tenantId) throw StateError('PRODUCT_NOT_FOUND');
          final product = ProductModel.fromJson({...data,'id':entry.key});
          final variants = [...product.variants];
          var total = product.stockQuantity;
          for (final change in entry.value.entries.where((e)=>e.value!=0)) {
            total -= change.value;
            if (variants.isEmpty) continue;
            final index = variants.indexWhere((v)=>v.color == change.key.$1 && v.size == change.key.$2);
            if(index<0) throw StateError('VARIANT_NOT_FOUND');
            final quantity=variants[index].stock-change.value;
            if(quantity<0) throw StateError('OUT_OF_STOCK');
            variants[index]=variants[index].copyWith(stock:quantity);
          }
          if(total<0) throw StateError('OUT_OF_STOCK');
          updates[productRef]={
            'stockQuantity':total, 'inStock':total>0,
            if(variants.isNotEmpty) 'variants':variants.map((v)=>v.toJson()).toList(),
            'salesCount':FieldValue.increment(product.stockQuantity-total),
          };
        }
        final redeemedDifference = order.pointsRedeemed - (old?['pointsRedeemed'] as int? ?? 0);
        final userRef = _db.collection('users').doc(order.userId);
        final awardedDifference = order.pointsAwarded - (old?['pointsAwarded'] as int? ?? 0);
        final customer = (redeemedDifference != 0 || awardedDifference != 0) ? await transaction.get(userRef) : null;
        if (redeemedDifference > 0) {
          final balance = customer?.data()?['loyaltyPoints'] as num? ?? 0;
          if(balance < redeemedDifference) throw StateError('رصيد النقاط غير كافٍ');
        }
        for(final entry in updates.entries) { transaction.update(entry.key,entry.value); }
        if(redeemedDifference != 0) transaction.update(userRef,{'loyaltyPoints':FieldValue.increment(-redeemedDifference)});
        if (awardedDifference != 0 && customer?.exists == true) {
          transaction.update(userRef,{'pendingPoints':FieldValue.increment(awardedDifference)});
          final dateKey = order.date.toIso8601String().substring(0,10);
          transaction.set(userRef.collection('daily_stats').doc(dateKey),{'purchasePointsAwarded':FieldValue.increment(awardedDifference)},SetOptions(merge:true));
        }
        if (couponId != null && (old == null || old['couponCode'] != order.couponCode)) {
          transaction.update(_db.collection('coupons').doc(couponId),{'usageCount':FieldValue.increment(1)});
        }
        final enabled = old == null || old['stockSyncEnabled'] == true;
        transaction.set(orderRef,{...order.toJson(),if(enabled) 'stockSyncEnabled':true,if(enabled) 'stockSyncPending':true},SetOptions(merge:true));
      });
      stockSync.enqueue(order.id);

      print('FirestoreService: Order ${order.id} placed successfully with stock check');
    } catch (e, stackTrace) {
      print('FirestoreService: Error placing order: $e');
      print('FirestoreService: Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> deleteOrder(String tenantId, String orderId) async {
    await _db
        .collection('orders')
        .doc(orderId)
        .update({'isHiddenForUser': true});
  }

  Stream<List<OrderModel>> getOrdersForUser(String userId, String tenantId) {
    return _db
        .collection('orders')
        .where('tenantId', isEqualTo: tenantId)
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final orders = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return OrderModel.fromJson(data);
      }).where((o) => !o.isHiddenForUser).toList();
      
      // Sort in memory instead of using Firestore orderBy (avoids composite index requirement)
      orders.sort((a, b) => b.date.compareTo(a.date)); // descending order
      
      return orders;
    });
  }

  Future<void> updateOrderStatus(String tenantId, String orderId, OrderStatus status, String tracking) async {
    await _db
        .collection('orders')
        .doc(orderId)
        .update({
      'stockSyncPending': true,
      'status': status.name,
      'tracking': tracking,
    });
    stockSync.enqueue(orderId);
  }

  // --- Reviews ---
  Stream<List<Map<String, dynamic>>> getReviews(String tenantId, String productId) {
    return _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  Future<void> addReview(String tenantId, String productId, Map<String, dynamic> review, {int rewardPoints = 0, int dailyLimit = 50}) async {
    final productRef = _db.collection('products').doc(productId);
    final reviewsRef = productRef.collection('reviews');
    final now = DateTime.now();
    final dateKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final userId = review['userId'] as String?;

    await _db.runTransaction((transaction) async {
      // 1. Add the review
      transaction.set(reviewsRef.doc(), {
        ...review,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 2. Award points if any and within limits
      if (rewardPoints > 0 && userId != null) {
        final statsRef = _db.collection('users').doc(userId).collection('daily_stats').doc(dateKey);
        final statsSnapshot = await transaction.get(statsRef);
        
        int currentPoints = 0;
        if (statsSnapshot.exists) {
          currentPoints = (statsSnapshot.data()?['reviewPointsAwarded'] as int? ?? 0);
        }

        if (currentPoints < dailyLimit) {
          final pointsToAward = (rewardPoints).clamp(0, dailyLimit - currentPoints);
          if (pointsToAward > 0) {
            final userRef = _db.collection('users').doc(userId);
            transaction.update(userRef, {
              'loyaltyPoints': FieldValue.increment(pointsToAward),
            });
            transaction.set(statsRef, {
              'reviewPointsAwarded': FieldValue.increment(pointsToAward),
            }, SetOptions(merge: true));
          }
        }
      }
    });

    // Recalculate average
    final snapshot = await reviewsRef.get();
    final reviews = snapshot.docs;
    if (reviews.isNotEmpty) {
      double totalRating = 0;
      for (var doc in reviews) {
        totalRating += (doc.data()['rating'] as num? ?? 0.0).toDouble();
      }
      final averageRating = double.parse((totalRating / reviews.length).toStringAsFixed(1));
      await productRef.update({'rating': averageRating});
    }
  }

  Future<int> awardSharePoints(String userId, int pointsPerShare, int dailyLimit) async {
    if (pointsPerShare <= 0) return 0;
    
    final now = DateTime.now();
    final dateKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final userRef = _db.collection('users').doc(userId);
    final statsRef = userRef.collection('daily_stats').doc(dateKey);

    return await _db.runTransaction((transaction) async {
      final statsSnapshot = await transaction.get(statsRef);
      
      int currentPoints = 0;
      if (statsSnapshot.exists) {
        currentPoints = (statsSnapshot.data()?['sharePointsAwarded'] as int? ?? 0);
      }

      if (currentPoints >= dailyLimit) return 0;

      final pointsToAward = (pointsPerShare).clamp(0, dailyLimit - currentPoints);
      if (pointsToAward <= 0) return 0;

      transaction.update(userRef, {
        'loyaltyPoints': FieldValue.increment(pointsToAward),
      });
      transaction.set(statsRef, {
        'sharePointsAwarded': FieldValue.increment(pointsToAward),
      }, SetOptions(merge: true));

      return pointsToAward;
    });
  }
  Future<void> updateReview(String tenantId, String productId, String reviewId, Map<String, dynamic> data) async {
    await _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(reviewId)
        .update({
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> replyToReview(String tenantId, String productId, String reviewId, Map<String, dynamic> reply) async {
    final reviewRef = _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(reviewId);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(reviewRef);
      if (!snapshot.exists) return;
      
      final currentReplies = (snapshot.data()?['replies'] as List? ?? []).cast<Map<String, dynamic>>();
      currentReplies.add({
        ...reply,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      transaction.update(reviewRef, {'replies': currentReplies});
    });
  }

  Future<void> deleteReview(String tenantId, String productId, String reviewId) async {
    await _db
        .collection('products')
        .doc(productId)
        .collection('reviews')
        .doc(reviewId)
        .delete();
  }

  // --- Coupons ---
  Stream<List<CouponModel>> getCoupons(String tenantId) {
    return _db
        .collection('coupons')
        .where('tenantId', isEqualTo: tenantId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return CouponModel.fromJson(data);
      }).toList();
    });
  }

  Future<CouponModel?> verifyCoupon(String tenantId, String code) async {
    final normalizedCode = code.trim().toUpperCase();
    final snapshot = await _db
        .collection('coupons')
        .where('tenantId', isEqualTo: tenantId)
        .where('code', isEqualTo: normalizedCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    
    final data = snapshot.docs.first.data();
    data['id'] = snapshot.docs.first.id;
    final coupon = CouponModel.fromJson(data);

    // Validation
    if (!coupon.isActive) return null;
    if (coupon.usageCount >= coupon.maxUsage) return null;
    if (coupon.expiryDate != null && coupon.expiryDate!.isBefore(DateTime.now())) return null;

    return coupon;
  }

  Future<void> incrementCouponUsage(String tenantId, String couponId) async {
    await _db
        .collection('coupons')
        .doc(couponId)
        .update({
          'usageCount': FieldValue.increment(1),
        });
  }

  Future<void> sendAdminNotification(String tenantId, String title, String body, {String? orderId}) async {
    final data = {
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    };
    
    // Add orderId if provided for deep linking
    if (orderId != null) {
      data['orderId'] = orderId;
    }
    
    await _db
        .collection('notifications')
        .add(data);
}

  // --- Inventory Management ---
  Future<void> updateProductVariantStock(String tenantId, String productId, String color, String size, int quantityToDeduct) async {
    await _db.runTransaction((transaction) async {
      final productRef = _db.collection('products').doc(productId);
      final snapshot = await transaction.get(productRef);
      
      if (!snapshot.exists) {
        throw Exception('Product not found: $productId');
      }
      
      final data = snapshot.data()!;
      final product = ProductModel.fromJson({...data, 'id': productId});
      
      // Find and update the matching variant
      final updatedVariants = product.variants.map((variant) {
        if (variant.color == color && variant.size == size) {
          final newStock = (variant.stock - quantityToDeduct).clamp(0, 999999);
          return ProductVariant(color: variant.color, size: variant.size, stock: newStock);
        }
        return variant;
      }).toList();
      
      // Update total stock quantity
      // If product has no variants, deduct directly from stockQuantity
      int totalStock;
      if (product.variants.isEmpty) {
        totalStock = (product.stockQuantity - quantityToDeduct).clamp(0, 999999);
      } else {
        totalStock = updatedVariants.fold<int>(0, (sum, v) => sum + v.stock);
      }
      
      transaction.update(productRef, {
        if (product.variants.isNotEmpty) 'variants': updatedVariants.map((v) => v.toJson()).toList(),
        'stockQuantity': totalStock,
        'inStock': totalStock > 0,
      });
    });
  }

  // --- Daily Check-in ---
  Future<int> dailyCheckIn(String userId, int pointsToAward) async {
    final userRef = _db.collection('users').doc(userId);
    return await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      if (!snapshot.exists) throw Exception('User not found');
      
      final data = snapshot.data()!;
      final lastCheckIn = data['lastCheckInDate'] != null ? DateTime.parse(data['lastCheckInDate']) : null;
      final now = DateTime.now();
      
      int newStreak = 1;
      if (lastCheckIn != null) {
        final lastZero = DateTime(lastCheckIn.year, lastCheckIn.month, lastCheckIn.day);
        final nowZero = DateTime(now.year, now.month, now.day);
        final difference = nowZero.difference(lastZero).inDays;
        
        if (difference == 1) {
          newStreak = (data['checkInStreak'] ?? 0) + 1;
        } else if (difference == 0) {
          throw Exception('ALREADY_CHECKED_IN');
        }
      }
      
      transaction.update(userRef, {
        'loyaltyPoints': FieldValue.increment(pointsToAward),
        'checkInStreak': newStreak,
        'lastCheckInDate': now.toIso8601String(),
      });
      
      return pointsToAward;
    });
  }

  Future<Map<String, dynamic>> getDailyStats(String userId) async {
    final now = DateTime.now();
    final dateKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final doc = await _db.collection('users').doc(userId).collection('daily_stats').doc(dateKey).get();
    return doc.data() ?? {};
  }

  Future<void> updateDailyPurchasePoints(String userId, int amount) async {
    final now = DateTime.now();
    final dateKey = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final statsRef = _db.collection('users').doc(userId).collection('daily_stats').doc(dateKey);
    await statsRef.set({
      'purchasePointsAwarded': FieldValue.increment(amount),
    }, SetOptions(merge: true));
  }

  // --- Shared Carts ---
  Future<String> createSharedCart(List<Map<String, dynamic>> items) async {
    final docRef = await _db.collection('shared_carts').add({
      'items': items,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  Future<List<Map<String, dynamic>>?> getSharedCart(String shareId) async {
    final doc = await _db.collection('shared_carts').doc(shareId).get();
    if (!doc.exists || doc.data() == null) return null;
    final items = doc.data()?['items'] as List?;
    return items?.cast<Map<String, dynamic>>();
  }

  // --- Promo Banners ---
  Stream<List<PromoBannerModel>> getBanners(String tenantId) {
    return _db
        .collection('banners')
        .where('tenantId', isEqualTo: tenantId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      final banners = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return PromoBannerModel.fromJson(data);
      }).toList();
      banners.sort((a, b) => b.priority.compareTo(a.priority));
      return banners;
    });
  }

  // --- Real-time Chat ---
  Stream<List<ChatMessageModel>> getChatMessages(String userId) {
    return _db
        .collection('chats')
        .where('chatId', isEqualTo: userId) // Simplified: Every user has one chat thread with the store
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          if (data['timestamp'] is Timestamp) {
            data['timestamp'] = (data['timestamp'] as Timestamp).toDate().toIso8601String();
          }
          return ChatMessageModel.fromJson(data);
        }).toList());
  }

  Future<void> sendMessage(ChatMessageModel message) async {
    await _db.collection('chats').add({
      ...message.toJson(),
      'chatId': message.senderId.contains('store') ? message.receiverId : message.senderId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
