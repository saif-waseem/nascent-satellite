import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
class SalesRepository {
  final FirebaseFirestore _firestore;

  SalesRepository(this._firestore);

  CollectionReference<SalesInvoiceModel> _salesRef(String tenantId) =>
      _firestore
          .collection('sales_invoices')
          .withConverter<SalesInvoiceModel>(
            fromFirestore: (snapshot, _) =>
                SalesInvoiceModel.fromJson(snapshot.data()!),
            toFirestore: (model, options) => model.toJson(),
          );

  CollectionReference<CustomerModel> _customersRef(String tenantId) =>
      _firestore.collection('customers').withConverter<CustomerModel>(
            fromFirestore: (snapshot, _) =>
                CustomerModel.fromJson(snapshot.data()!),
            toFirestore: (model, _) => model.toJson(),
          );

   Future<CustomerModel?> getCustomerById(String tenantId, String customerId) async {
    if (customerId.startsWith('user_')) {
      final userId = customerId.replaceFirst('user_', '');
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return null;
      
      final data = userDoc.data()!;
      data['id'] = userDoc.id;
      final user = UserModel.fromJson(data);
      
      return CustomerModel(
        id: 'user_${user.id}',
        name: user.name ?? user.email.split('@').first,
        phoneNumber: user.phone ?? user.email,
        balance: user.balance,
        loyaltyPoints: user.loyaltyPoints,
        tenantId: tenantId,
        createdAt: user.createdAt,
      );
    }
    
    final doc = await _customersRef(tenantId).doc(customerId).get();
    return doc.data();
  }

  Future<SalesInvoiceModel?> getInvoiceByReceiptNumber(
      String tenantId, String receiptNumber) async {
    final query = await _salesRef(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .where('receiptNumber', isEqualTo: receiptNumber)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.data();
  }

  Future<List<SalesInvoiceModel>> getRecentSales(String tenantId, {int limit = 50}) async {
    final snapshot = await _salesRef(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .limit(limit)
        .get();
    final list = snapshot.docs.map((doc) => doc.data()).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Stream<List<SalesInvoiceModel>> watchSales(String tenantId, {int limit = 50}) {
    return _salesRef(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<List<SalesInvoiceModel>> getSalesByDateRange(String tenantId, DateTime start, DateTime end) async {
    final query = await _salesRef(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThanOrEqualTo: end)
        .orderBy('date', descending: true)
        .get();
    return query.docs.map((doc) => doc.data()).toList();
  }

  Future<List<SalesInvoiceModel>> getSalesByCustomer(String tenantId, String customerId) async {
    final query = await _salesRef(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .where('customerId', isEqualTo: customerId)
        .get();
    final list = query.docs.map((doc) => doc.data()).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  Future<void> processReturnAndExchange({
    required String tenantId,
    required SalesInvoiceModel originalInvoice,
    required List<SalesItem> returnedItems,
    required List<SalesItem> exchangeItems,
    required double totalReturnAmount,
    required double totalExchangeAmount,
  }) async {
    final batch = _firestore.batch();

    // 1. Update Inventory for each returned item (increase)
    for (final item in returnedItems) {
      if (item.productId.isEmpty) continue;
      final productRef = _firestore.collection('products').doc(item.productId);
      final productSnapshot = await productRef.get();
      
      if (productSnapshot.exists) {
        final data = productSnapshot.data();
        if (data != null) {
          data['id'] = productSnapshot.id;
          final product = ProductModel.fromJson(data);
          List<ProductVariant> updatedVariants = List.from(product.variants);
          if (item.variantColor != null || item.variantSize != null) {
            final vIndex = updatedVariants.indexWhere((v) => 
               v.color == item.variantColor && v.size == item.variantSize);
            if (vIndex >= 0) {
              final v = updatedVariants[vIndex];
              updatedVariants[vIndex] = v.copyWith(stock: v.stock + item.quantity);
            }
          }
          batch.set(productRef, product.copyWith(
            stockQuantity: product.stockQuantity + item.quantity,
            salesCount: product.salesCount - item.quantity,
            variants: updatedVariants,
          ).toJson());
        }
      }
    }

    // 2. Update Inventory for each exchange item (decrease)
    for (final item in exchangeItems) {
      if (item.productId.isEmpty) continue;
      final productRef = _firestore.collection('products').doc(item.productId);
      final productSnapshot = await productRef.get();
      
      if (productSnapshot.exists) {
        final data = productSnapshot.data();
        if (data != null) {
          data['id'] = productSnapshot.id;
          final product = ProductModel.fromJson(data);
          List<ProductVariant> updatedVariants = List.from(product.variants);
          if (item.variantColor != null || item.variantSize != null) {
            final vIndex = updatedVariants.indexWhere((v) => 
               v.color == item.variantColor && v.size == item.variantSize);
            if (vIndex >= 0) {
              final v = updatedVariants[vIndex];
              updatedVariants[vIndex] = v.copyWith(stock: v.stock - item.quantity);
            }
          }
          batch.set(productRef, product.copyWith(
            stockQuantity: product.stockQuantity - item.quantity,
            salesCount: product.salesCount + item.quantity,
            variants: updatedVariants,
          ).toJson());
        }
      }
    }

    // 3. Mark original invoice
    final originalRef = _salesRef(tenantId).doc(originalInvoice.id);
    batch.update(originalRef, {'isReturned': true});

    // 4. Loyalty points & balance
    final netDifference = totalExchangeAmount - totalReturnAmount;
    
    if (originalInvoice.customerId != null) {
      final tenantDoc = await _firestore.collection('tenants').doc(tenantId).get();
      final tenant = tenantDoc.exists ? TenantModel.fromJson(tenantDoc.data()!..['id'] = tenantDoc.id) : TenantModel(id: '', name: '', adminIds: const [], createdAt: DateTime.now());
      
      final netPointsChange = (netDifference * tenant.purchasePointsPercent).floor(); 
      
      if (originalInvoice.customerId!.startsWith('user_')) {
        final userId = originalInvoice.customerId!.replaceFirst('user_', '');
        final userRef = _firestore.collection('users').doc(userId);
        batch.update(userRef, {
          'loyaltyPoints': FieldValue.increment(netPointsChange),
        });
      } else {
        final customerRef = _customersRef(tenantId).doc(originalInvoice.customerId);
        batch.update(customerRef, {
          'loyaltyPoints': FieldValue.increment(netPointsChange),
        });
      }
    }

    // 5. Create Return/Exchange Invoice
    final returnRef = _salesRef(tenantId).doc();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    
    final returnedItemsNeg = returnedItems.map((e) => SalesItem(
      productId: e.productId,
      productName: e.productName,
      quantity: -e.quantity,
      unitPrice: e.unitPrice,
      discount: e.discount,
      category: e.category,
      variantColor: e.variantColor,
      variantSize: e.variantSize,
    )).toList();

    final returnInvoice = SalesInvoiceModel(
      id: returnRef.id,
      tenantId: tenantId,
      receiptNumber: "RX-${timestamp.substring(timestamp.length - 6)}", 
      items: [...returnedItemsNeg, ...exchangeItems],
      totalAmount: netDifference,
      discountAmount: 0,
      paidAmount: netDifference > 0 ? netDifference : 0,
      pointsRedeemed: 0, 
      date: DateTime.now(),
      customerId: originalInvoice.customerId,
      customerName: originalInvoice.customerName,
      sessionName: originalInvoice.sessionName,
      addedBy: originalInvoice.addedBy,
      addedById: originalInvoice.addedById,
      isReturned: true, 
    );

    batch.set(returnRef, returnInvoice);
    await batch.commit();
  }

  Future<void> saveInvoice(String tenantId, SalesInvoiceModel invoice) async {
    final batch = _firestore.batch();

    // 1. Record the sale
    final saleRef = _salesRef(tenantId).doc(invoice.id.isEmpty ? null : invoice.id);
    final receiptNumber = invoice.receiptNumber.isEmpty 
          ? DateTime.now().millisecondsSinceEpoch.toString() 
          : invoice.receiptNumber;

    final finalInvoice = invoice.copyWith(
      id: saleRef.id,
      receiptNumber: receiptNumber,
    );
    batch.set(saleRef, finalInvoice);

    // 2. Deduct stock for each item
    for (final item in finalInvoice.items) {
      if (item.productId.isEmpty) continue;
      final productRef = _firestore.collection('products').doc(item.productId);
      
      // Read outside transaction to prevent Windows native crashes
      final productSnapshot = await productRef.get();
      
      if (productSnapshot.exists) {
        final data = productSnapshot.data();
        if (data == null) continue;
        final product = ProductModel.fromJson(data..['id'] = productSnapshot.id);
        
        List<ProductVariant> updatedVariants = List.from(product.variants);
        if (item.variantColor != null || item.variantSize != null) {
          final vIndex = updatedVariants.indexWhere((v) => 
             v.color == item.variantColor && v.size == item.variantSize);
          
          if (vIndex >= 0) {
            final v = updatedVariants[vIndex];
            updatedVariants[vIndex] = v.copyWith(stock: v.stock - item.quantity);
          }
        }

        batch.set(productRef, product.copyWith(
          stockQuantity: product.stockQuantity - item.quantity,
          salesCount: product.salesCount + item.quantity,
          variants: updatedVariants,
        ).toJson());
      }
    }

    // 3. Loyalty and Balance (Debt)
    if (finalInvoice.customerId != null) {
      // Fetch Tenant settings for loyalty rules (Authoritative cloud settings)
      final tenantDoc = await _firestore.collection('tenants').doc(tenantId).get();
      if (!tenantDoc.exists) {
         // Fallback to minimal calculation if tenant not found (should not happen)
         return;
      }
      final tenant = TenantModel.fromJson(tenantDoc.data()!..['id'] = tenantDoc.id);
      
      final pointsValue = finalInvoice.pointsRedeemed * tenant.pointsToCurrencyRatio;
      final netTotal = finalInvoice.totalAmount - finalInvoice.discountAmount - pointsValue;
      final debt = netTotal - finalInvoice.paidAmount;
      
      // Calculate awarded points based on Tenant's purchasePointsPercent
      final pointsAwarded = (finalInvoice.paidAmount * tenant.purchasePointsPercent).floor();
      final netPointsChange = pointsAwarded - finalInvoice.pointsRedeemed;

      if (finalInvoice.customerId!.startsWith('user_')) {
        final userId = finalInvoice.customerId!.replaceFirst('user_', '');
        final userRef = _firestore.collection('users').doc(userId);
        batch.update(userRef, {
          'loyaltyPoints': FieldValue.increment(netPointsChange),
          if (debt != 0) 'balance': FieldValue.increment(debt),
        });
      } else {
        final customerRef = _customersRef(tenantId).doc(finalInvoice.customerId);
        batch.update(customerRef, {
          'loyaltyPoints': FieldValue.increment(netPointsChange),
          if (debt != 0) 'balance': FieldValue.increment(debt),
        });
      }
    }

    await batch.commit();
  }
}

final salesRepositoryProvider =
    Provider((ref) => SalesRepository(FirebaseFirestore.instance));
