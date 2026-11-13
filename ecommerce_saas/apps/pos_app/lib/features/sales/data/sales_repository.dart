import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/services/pos_supabase_service.dart';

class SalesRepository {
  final FirebaseFirestore _firestore;
  final PosSupabaseService? _supabaseService;

  SalesRepository(this._firestore, [this._supabaseService]);

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
    // 1. Try Supabase SQL first
    if (_supabaseService != null) {
      try {
        final cust = await _supabaseService!.getCustomerById(tenantId, customerId);
        if (cust != null) return cust;
      } catch (_) {}
    }

    // 2. Fallback to Firestore
    try {
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
    } catch (_) {
      return null;
    }
  }

  Future<SalesInvoiceModel?> getInvoiceByReceiptNumber(
      String tenantId, String receiptNumber) async {
    // 1. Try Supabase SQL first
    if (_supabaseService != null) {
      try {
        final invoice = await _supabaseService!.getInvoiceByReceiptNumber(tenantId, receiptNumber);
        if (invoice != null) return invoice;
      } catch (_) {}
    }

    // 2. Fallback to Firestore
    try {
      final query = await _salesRef(tenantId)
          .where('tenantId', isEqualTo: tenantId)
          .where('receiptNumber', isEqualTo: receiptNumber)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return query.docs.first.data();
    } catch (_) {
      return null;
    }
  }

  Future<List<SalesInvoiceModel>> getRecentSales(String tenantId, {int limit = 50}) async {
    // 1. Try Supabase SQL first
    if (_supabaseService != null) {
      try {
        final list = await _supabaseService!.getRecentSales(tenantId, limit: limit);
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    // 2. Fallback to Firestore
    try {
      final snapshot = await _salesRef(tenantId)
          .where('tenantId', isEqualTo: tenantId)
          .limit(limit)
          .get();
      final list = snapshot.docs.map((doc) => doc.data()).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (_) {
      return [];
    }
  }

  Stream<List<SalesInvoiceModel>> watchSales(String tenantId, {int limit = 50}) async* {
    if (tenantId.isEmpty) {
      yield [];
      return;
    }

    // 1. Instant initial load from Supabase SQL (0ms latency)
    if (_supabaseService != null) {
      try {
        final initial = await _supabaseService!.getRecentSales(tenantId, limit: limit);
        if (initial.isNotEmpty) {
          yield initial;
        }
      } catch (_) {}

      // 2. Stream from Supabase SQL Realtime
      try {
        await for (final sales in _supabaseService!.getSalesInvoicesStream(tenantId)) {
          if (sales.isNotEmpty) {
            yield sales.take(limit).toList();
          }
        }
      } catch (_) {}
    }

    // 3. Fallback to Firestore stream
    yield* _salesRef(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }

  Future<List<SalesInvoiceModel>> getSalesByDateRange(String tenantId, DateTime start, DateTime end) async {
    // 1. Try Supabase SQL first
    if (_supabaseService != null) {
      try {
        final list = await _supabaseService!.getSalesByDateRange(tenantId, start, end);
        if (list.isNotEmpty) return list;
      } catch (_) {}
    }

    // 2. Fallback to Firestore
    try {
      final query = await _salesRef(tenantId)
          .where('tenantId', isEqualTo: tenantId)
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThanOrEqualTo: end)
          .orderBy('date', descending: true)
          .get();
      return query.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<SalesInvoiceModel>> getSalesByCustomer(String tenantId, String customerId) async {
    try {
      final query = await _salesRef(tenantId)
          .where('tenantId', isEqualTo: tenantId)
          .where('customerId', isEqualTo: customerId)
          .get();
      final list = query.docs.map((doc) => doc.data()).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> processReturnAndExchange({
    required String tenantId,
    required SalesInvoiceModel originalInvoice,
    required List<SalesItem> returnedItems,
    required List<SalesItem> exchangeItems,
    required double totalReturnAmount,
    required double totalExchangeAmount,
  }) async {
    final receiptNumber = '${originalInvoice.receiptNumber}-R';
    final returnInvoice = SalesInvoiceModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      tenantId: tenantId,
      receiptNumber: receiptNumber,
      items: returnedItems,
      totalAmount: totalReturnAmount,
      date: DateTime.now(),
      customerId: originalInvoice.customerId,
      customerName: originalInvoice.customerName,
      isReturned: true,
      status: SalesInvoiceStatus.finalized,
    );

    // 1. Save return invoice to Supabase SQL first
    if (_supabaseService != null) {
      try {
        await _supabaseService!.saveInvoice(returnInvoice, tenantId);
      } catch (_) {}
    }

    // 2. Fallback to Firestore batch
    try {
      final batch = _firestore.batch();
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

      final returnRef = _salesRef(tenantId).doc(returnInvoice.id);
      batch.set(returnRef, returnInvoice);
      await batch.commit();
    } catch (_) {}
  }

  Future<void> saveInvoice(String tenantId, SalesInvoiceModel invoice) async {
    final saleRef = _salesRef(tenantId).doc(invoice.id.isEmpty ? null : invoice.id);
    final receiptNumber = invoice.receiptNumber.isEmpty 
          ? DateTime.now().millisecondsSinceEpoch.toString() 
          : invoice.receiptNumber;

    final finalInvoice = invoice.copyWith(
      id: saleRef.id,
      receiptNumber: receiptNumber,
    );

    // 1. Save to Supabase SQL Database (Primary Architecture)
    // Note: saveInvoice automatically deducts stock in Supabase products table
    if (_supabaseService != null) {
      try {
        await _supabaseService!.saveInvoice(finalInvoice, tenantId);
      } catch (_) {}
    }

    // 2. Save to Firestore (Fallback & Cross-device real-time sync)
    try {
      final batch = _firestore.batch();
      batch.set(saleRef, finalInvoice);

      for (final item in finalInvoice.items) {
        if (item.productId.isEmpty) continue;
        final productRef = _firestore.collection('products').doc(item.productId);
        final productSnapshot = await productRef.get();
        
        if (productSnapshot.exists) {
          final data = productSnapshot.data();
          if (data == null) continue;
          final product = ProductModel.fromJson(<String, dynamic>{...data, 'id': productSnapshot.id});
          
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

      // Customer loyalty & balance
      if (finalInvoice.customerId != null) {
        final tenantDoc = await _firestore.collection('tenants').doc(tenantId).get();
        if (tenantDoc.exists) {
          final tenant = TenantModel.fromJson({...tenantDoc.data()!, 'id': tenantDoc.id});
          final pointsValue = finalInvoice.pointsRedeemed * tenant.pointsToCurrencyRatio;
          final netTotal = finalInvoice.totalAmount - finalInvoice.discountAmount - pointsValue;
          final debt = netTotal - finalInvoice.paidAmount;
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
      }

      await batch.commit();
    } catch (_) {}
  }
}

final salesRepositoryProvider =
    Provider((ref) => SalesRepository(FirebaseFirestore.instance, ref.watch(posSupabaseServiceProvider)));
