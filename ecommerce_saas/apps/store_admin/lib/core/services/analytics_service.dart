import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';

class AnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Verifies that the salesCount in ProductModel matches the actual number of 
  /// times that product appears in completed orders.
  Future<Map<String, int>> verifyProductSales(String tenantId) async {
    final Map<String, int> actualSales = {};
    
    // 1. Get all completed orders for this tenant
    // Path: collection('orders') with where('tenantId')
    final ordersQuery = await _firestore
        .collection('orders')
        .where('tenantId', isEqualTo: tenantId)
        .where('status', isEqualTo: OrderStatus.completed.name)
        .get();

    for (var doc in ordersQuery.docs) {
      final orderData = doc.data();
      final items = (orderData['items'] as List?) ?? [];
      
      for (var item in items) {
        final productId = item['productId'] ?? item['id'] as String?;
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        if (productId != null) {
          actualSales[productId] = (actualSales[productId] ?? 0) + quantity;
        }
      }
    }

    return actualSales;
  }

  /// Recalculates and updates salesCount for all products based on order history.
  Future<void> syncSalesMetrics(String tenantId) async {
    final actualSales = await verifyProductSales(tenantId);
    
    final batch = _firestore.batch();
    final productsQuery = await _firestore
        .collection('products')
        .where('tenantId', isEqualTo: tenantId)
        .get();

    for (var doc in productsQuery.docs) {
      final productId = doc.id;
      final expected = actualSales[productId] ?? 0;
      final current = (doc.data()['salesCount'] as num?)?.toInt() ?? 0;

      if (current != expected) {
        batch.update(doc.reference, {'salesCount': expected});
      }
    }

    await batch.commit();
  }

  /// Recalculates and updates product ratings based on reviews.
  Future<void> syncRatingMetrics(String tenantId) async {
    final productsQuery = await _firestore
        .collection('products')
        .where('tenantId', isEqualTo: tenantId)
        .get();

    final batch = _firestore.batch();
    bool hasChanges = false;

    for (var productDoc in productsQuery.docs) {
      final reviewsQuery = await productDoc.reference.collection('reviews').get();
      
      if (reviewsQuery.docs.isEmpty) {
        if ((productDoc.data()['rating'] as num? ?? 0.0) != 0.0) {
          batch.update(productDoc.reference, {'rating': 0.0});
          hasChanges = true;
        }
        continue;
      }

      double total = 0;
      for (var reviewDoc in reviewsQuery.docs) {
        total += (reviewDoc.data()['rating'] as num? ?? 0.0).toDouble();
      }
      
      final average = double.parse((total / reviewsQuery.docs.length).toStringAsFixed(1));
      final current = (productDoc.data()['rating'] as num? ?? 0.0).toDouble();

      if (current != average) {
        batch.update(productDoc.reference, {'rating': average});
        hasChanges = true;
      }
    }

    if (hasChanges) {
      await batch.commit();
    }
  }

  /// Verifies customer metrics (totalSpent, purchaseCount)
  Future<void> syncCustomerMetrics(String tenantId) async {
    final Map<String, double> customerSpending = {};
    final Map<String, int> customerPurchaseCount = {};

    final ordersQuery = await _firestore
        .collection('orders')
        .where('tenantId', isEqualTo: tenantId)
        .where('status', isEqualTo: OrderStatus.completed.name)
        .get();

    for (var doc in ordersQuery.docs) {
      final phone = doc.data()['userPhone'] as String?;
      final total = (doc.data()['total'] as num?)?.toDouble() ?? 0.0;
      
      if (phone != null) {
        customerSpending[phone] = (customerSpending[phone] ?? 0.0) + total;
        customerPurchaseCount[phone] = (customerPurchaseCount[phone] ?? 0) + 1;
      }
    }

    final batch = _firestore.batch();
    // Users are stored in 'users' collection with composite IDs: ${tenantId}_$phone
    final customersQuery = await _firestore
        .collection('users')
        .where('tenantId', isEqualTo: tenantId)
        .get();

    for (var doc in customersQuery.docs) {
      final userData = doc.data();
      final phone = userData['userPhone'] as String? ?? doc.id.split('_').last;
      
      final expectedSpent = customerSpending[phone] ?? 0.0;
      final expectedCount = customerPurchaseCount[phone] ?? 0;

      final currentSpent = (userData['totalSpent'] as num? ?? 0.0).toDouble();
      final currentCount = (userData['purchaseCount'] as num? ?? 0).toInt();

      if ((currentSpent - expectedSpent).abs() > 0.01 || currentCount != expectedCount) {
        batch.update(doc.reference, {
          'totalSpent': expectedSpent,
          'purchaseCount': expectedCount,
        });
      }
    }

    await batch.commit();
  }

  /// Calculates product sales velocity and predicts when stock will run out.
  /// Returns a map of productId to a prediction (days remaining)
  Future<Map<String, double>> getStockPredictions(String tenantId) async {
    final Map<String, int> recentSales = {};
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    
    // 1. Get completed orders from last 30 days
    final ordersQuery = await _firestore
        .collection('orders')
        .where('tenantId', isEqualTo: tenantId)
        .where('status', isEqualTo: OrderStatus.completed.name)
        .where('date', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo))
        .get();

    for (var doc in ordersQuery.docs) {
      final items = (doc.data()['items'] as List?) ?? [];
      for (var item in items) {
        final productId = item['productId'] ?? item['id'];
        final qty = (item['quantity'] as num?)?.toInt() ?? 0;
        if (productId != null) {
          recentSales[productId] = (recentSales[productId] ?? 0) + qty;
        }
      }
    }

    final Map<String, double> predictions = {};
    final productsQuery = await _firestore
        .collection('products')
        .where('tenantId', isEqualTo: tenantId)
        .get();

    for (var doc in productsQuery.docs) {
      final productId = doc.id;
      final stock = (doc.data()['stockQuantity'] as num? ?? 0).toInt();
      final totalSoldIn30Days = recentSales[productId] ?? 0;
      
      if (totalSoldIn30Days > 0) {
        final dailyVelocity = totalSoldIn30Days / 30.0;
        final daysRemaining = stock / dailyVelocity;
        predictions[productId] = daysRemaining;
      } else {
        // If 0 sales in 30 days, we can't predict based on velocity
        // We'll return a high value or null to indicate "stable"
        predictions[productId] = 999.0; 
      }
    }

    return predictions;
  }

  Future<bool> checkHealth(String tenantId) async {
    final actualSales = await verifyProductSales(tenantId);
    
    final productsQuery = await _firestore
        .collection('products')
        .where('tenantId', isEqualTo: tenantId)
        .get();

    for (var doc in productsQuery.docs) {
      final productId = doc.id;
      final expected = actualSales[productId] ?? 0;
      final current = (doc.data()['salesCount'] as num?)?.toInt() ?? 0;

      if (current != expected) return false;
    }
    return true;
  }
}
