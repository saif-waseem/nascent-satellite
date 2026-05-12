import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/models/sync_queue_item.dart';
import '../../products/data/product_repository.dart';

final salesRepositoryProvider = Provider((ref) => SalesRepository(ref));

class SalesRepository {
  final Ref _ref;
  FirestoreRestService get _restService => _ref.read(firestoreRestServiceProvider);

  SalesRepository(this._ref);

  Box<SalesInvoiceModel> get _salesBox => LocalDbService.getBox<SalesInvoiceModel>('sales');
  Box<CustomerModel> get _customerBox => LocalDbService.getBox<CustomerModel>('customers');
  Box<ProductModel> get _productBox => LocalDbService.getBox<ProductModel>('products');
  Box<TenantModel> get _tenantBox => LocalDbService.getBox<TenantModel>('tenants');

  Future<CustomerModel?> getCustomerById(String tenantId, String customerId) async {
    // Check local first
    final cached = _customerBox.get(customerId);
    if (cached != null) return cached;

    if (tenantId == 'local_default') return null;

    try {
      if (customerId.startsWith('user_')) {
        final userId = customerId.replaceFirst('user_', '');
        final data = await _restService.getDocument('users/$userId');
        if (data == null) return null;
        
        final user = UserModel.fromJson(data);
        final customer = CustomerModel(
          id: 'user_${user.id}',
          name: user.name ?? user.email.split('@').first,
          phoneNumber: user.phone ?? user.email,
          balance: user.balance,
          loyaltyPoints: user.loyaltyPoints,
          tenantId: tenantId,
          createdAt: user.createdAt,
        );
        await _customerBox.put(customer.id, customer);
        return customer;
      }
      
      final data = await _restService.getDocument('customers/$customerId');
      if (data == null) return null;
      final customer = CustomerModel.fromJson(data);
      await _customerBox.put(customer.id, customer);
      return customer;
    } catch (e) {
      return null;
    }
  }

  Future<List<SalesInvoiceModel>> getRecentSales(String tenantId, {int limit = 50}) async {
    final cached = _salesBox.values
        .where((s) => s.tenantId == tenantId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    
    final result = cached.take(limit).toList();
    
    if (tenantId == 'local_default') return result;

    // Background fetch from remote
    _fetchRecentSalesRemote(tenantId, limit);
    
    return result;
  }

  Future<void> _fetchRecentSalesRemote(String tenantId, int limit) async {
    try {
      final query = {
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'tenantId'},
            'op': 'EQUAL',
            'value': {'stringValue': tenantId}
          }
        },
        'orderBy': [
          {'field': {'fieldPath': 'date'}, 'direction': 'DESCENDING'}
        ],
        'limit': limit,
      };
      final results = await _restService.runQuery('sales_invoices', query);
      final remoteInvoices = results.map((data) => SalesInvoiceModel.fromJson(data)).toList();
      for (var inv in remoteInvoices) {
        await _salesBox.put(inv.id, inv);
      }
    } catch (e) {
      debugPrint('Error background fetching sales: $e');
    }
  }

  Future<void> saveInvoice(String tenantId, SalesInvoiceModel invoice) async {
    final invoiceId = invoice.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : invoice.id;
    final receiptNumber = invoice.receiptNumber.isEmpty 
          ? DateTime.now().millisecondsSinceEpoch.toString() 
          : invoice.receiptNumber;

    final finalInvoice = invoice.copyWith(
      id: invoiceId,
      receiptNumber: receiptNumber,
      tenantId: tenantId,
    );

    // 1. Save locally first
    await _salesBox.put(invoiceId, finalInvoice);

    // 2. Update local stock and customer balance
    await _updateLocalStateForSale(tenantId, finalInvoice);

    if (tenantId == 'local_default') return;

    // 3. Queue for sync
    await LocalDbService.addToSyncQueue(
      collectionPath: 'sales_invoices/$invoiceId', 
      data: finalInvoice.toJson(), 
      action: invoice.id.isNotEmpty ? SyncAction.update : SyncAction.create
    );
    
    // Note: In a real system, the server-side would handle stock deduction.
    // But since we are using Firestore REST, we might need to queue stock updates too 
    // OR have a cloud function do it.
    // Here we'll queue them individually for the REST service to process.
    for (final item in finalInvoice.items) {
      if (item.productId.isEmpty) continue;
      final product = _productBox.get(item.productId);
      if (product != null) {
        await LocalDbService.addToSyncQueue(
          collectionPath: 'products/${item.productId}', 
          data: product.toJson(), // We already updated product locally in step 2
          action: SyncAction.update
        );
      }
    }

    if (finalInvoice.customerId != null) {
      final customer = _customerBox.get(finalInvoice.customerId);
      if (customer != null) {
        await LocalDbService.addToSyncQueue(
          collectionPath: 'customers/${finalInvoice.customerId}', 
          data: customer.toJson(),
          action: SyncAction.update
        );
      }
    }
  }

  Future<void> _updateLocalStateForSale(String tenantId, SalesInvoiceModel invoice) async {
    final productRepo = _ref.read(productRepositoryProvider);
    // Update Stocks
    for (final item in invoice.items) {
      if (item.productId.isEmpty) continue;
      final product = _productBox.get(item.productId);
      if (product != null) {
        List<ProductVariant> updatedVariants = List.from(product.variants);
        
        // 1. Identify Variant
        int vIndex = updatedVariants.indexWhere((v) => 
           v.color == (item.variantColor ?? 'Default') && v.size == (item.variantSize ?? 'Default'));
        
        if (vIndex == -1) {
           if (updatedVariants.isEmpty) {
             // Create a default variant for simple products
             updatedVariants.add(ProductVariant(
               color: 'Default', 
               size: 'Default', 
               stock: product.stockQuantity, 
               storageLocations: [ProductStorageLocation(warehouseName: 'المخزن الرئيسي', quantity: product.stockQuantity)]
             ));
             vIndex = 0;
           } else {
             vIndex = 0; // Fallback to first if mismatch
           }
        }

        if (vIndex >= 0) {
          final v = updatedVariants[vIndex];
          List<ProductStorageLocation> updatedLocs = List.from(v.storageLocations);
          
          // 2. Identify Warehouse to deduct from
          int locIndex = -1;
          if (item.warehouseName != null) {
            locIndex = updatedLocs.indexWhere((l) => l.warehouseName == item.warehouseName);
          }
          
          // If automatic or not found, find first warehouse with stock
          if (locIndex == -1) {
            locIndex = updatedLocs.indexWhere((l) => l.quantity >= item.quantity);
            if (locIndex == -1 && updatedLocs.isNotEmpty) locIndex = 0;
          }

          if (locIndex >= 0) {
            final loc = updatedLocs[locIndex];
            updatedLocs[locIndex] = loc.copyWith(quantity: (loc.quantity - item.quantity).clamp(0, 999999));
            
            updatedVariants[vIndex] = v.copyWith(
              storageLocations: updatedLocs,
            );
          }
        }

        // 3. Final Integrity Check & Save
        final updatedProduct = product.copyWith(
          variants: updatedVariants,
          salesCount: (product.salesCount ?? 0) + item.quantity,
        );
        
        final finalProduct = productRepo.recalculateIntegrity(updatedProduct);
        await _productBox.put(item.productId, finalProduct);
      }
    }

    // Update Customer
    if (invoice.customerId != null) {
      final customer = _customerBox.get(invoice.customerId);
      if (customer != null) {
        final tenant = _tenantBox.get(tenantId) ?? TenantModel(id: '', name: 'Local', adminIds: const [], createdAt: DateTime.now());
        
        final pointsValue = invoice.pointsRedeemed * tenant.pointsToCurrencyRatio;
        final netTotal = invoice.totalAmount - invoice.discountAmount - pointsValue;
        final debt = netTotal - invoice.paidAmount;
        
        final pointsAwarded = (invoice.paidAmount * tenant.purchasePointsPercent).floor();
        final netPointsChange = pointsAwarded - invoice.pointsRedeemed;

        await _customerBox.put(invoice.customerId!, customer.copyWith(
          loyaltyPoints: (customer.loyaltyPoints ?? 0) + netPointsChange.toInt(),
          balance: (customer.balance) + debt,
        ));
      }
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
    // Offline return logic
    for (final item in returnedItems) {
      if (item.productId.isEmpty) continue;
      final product = _productBox.get(item.productId);
      if (product != null) {
        int newStock = product.stockQuantity + item.quantity;
        List<ProductVariant> updatedVariants = List.from(product.variants);
        if (item.variantColor != null || item.variantSize != null) {
          final vIndex = updatedVariants.indexWhere((v) => 
             v.color == item.variantColor && v.size == item.variantSize);
          if (vIndex >= 0) {
            final v = updatedVariants[vIndex];
            updatedVariants[vIndex] = v.copyWith(stock: v.stock + item.quantity);
          }
        }
        final updatedProduct = product.copyWith(stockQuantity: newStock, variants: updatedVariants);
        await _productBox.put(item.productId, updatedProduct);
        
        if (tenantId != 'local_default') {
          await LocalDbService.addToSyncQueue(
            collectionPath: 'products/${item.productId}', 
            data: updatedProduct.toJson(), 
            action: SyncAction.update
          );
        }
      }
    }

    if (exchangeItems.isNotEmpty) {
      final exchangeInvoice = originalInvoice.copyWith(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        receiptNumber: 'EX-${originalInvoice.receiptNumber}',
        items: exchangeItems,
        totalAmount: totalExchangeAmount,
        paidAmount: totalReturnAmount.clamp(0, totalExchangeAmount),
        date: DateTime.now(),
        status: SalesInvoiceStatus.finalized,
      );
      await saveInvoice(tenantId, exchangeInvoice);
    }

    // Update balance
    final netDiff = totalExchangeAmount - totalReturnAmount;
    if (originalInvoice.customerId != null && netDiff != 0) {
      final customer = _customerBox.get(originalInvoice.customerId);
      if (customer != null) {
        final updatedCustomer = customer.copyWith(balance: customer.balance + netDiff);
        await _customerBox.put(originalInvoice.customerId!, updatedCustomer);
        
        if (tenantId != 'local_default') {
          await LocalDbService.addToSyncQueue(
            collectionPath: 'customers/${originalInvoice.customerId}', 
            data: updatedCustomer.toJson(), 
            action: SyncAction.update
          );
        }
      }
    }
  }

  Future<List<SalesInvoiceModel>> getSalesByShift(String tenantId, String shiftId) async {
    return _salesBox.values.where((s) => s.tenantId == tenantId && s.shiftId == shiftId).toList();
  }
  Future<SalesInvoiceModel?> getInvoiceByReceiptNumber(String tenantId, String receiptNumber) async {
    try {
      return _salesBox.values.firstWhere(
        (s) => s.tenantId == tenantId && s.receiptNumber == receiptNumber,
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<SalesInvoiceModel>> getSalesByCustomer(String tenantId, String customerId) async {
    return _salesBox.values.where((s) => s.tenantId == tenantId && s.customerId == customerId).toList();
  }
}

