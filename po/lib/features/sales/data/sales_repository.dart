import '../../../core/services/cashier_stock_service.dart';
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

  Future<Map<String, dynamic>> _invoiceQueueData(SalesInvoiceModel invoice) async {
    final data = invoice.toJson();
    if (await _ref.read(cashierStockProvider).linked(invoice.tenantId)) {
      final movements = CashierStockService.movements(invoice, (id) => _productBox.get(id));
      if (movements.isNotEmpty) data['_stockMovements'] = movements;
    }
    return data;
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
      data: await _invoiceQueueData(finalInvoice),
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
    
    // 1. Update Stocks
    for (final item in invoice.items) {
      if (item.productId.isEmpty) continue;
      
      try {
        await productRepo.updateStock(
          tenantId, 
          item.productId, 
          -item.quantity.toInt(), // Negative for sale
          color: item.variantColor,
          size: item.variantSize,
          warehouseName: item.warehouseName ?? 'المخزن الرئيسي',
        );
      } catch (e) {
        debugPrint('OFFLINE STOCK UPDATE ERROR for ${item.productName}: $e');
      }
    }

    // 2. Update Customer Balance and Points
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
    final productRepo = _ref.read(productRepositoryProvider);

    // Validate the whole return before recording any local or cloud movement.
    final remaining = <(String, String?, String?), int>{};
    for (final item in originalInvoice.items) {
      final key = (item.productId, item.variantColor, item.variantSize);
      remaining.update(key, (n) => n + item.quantity, ifAbsent: () => item.quantity);
    }
    for (final item in returnedItems) {
      final key = (item.productId, item.variantColor, item.variantSize);
      final available = remaining[key] ?? 0;
      if (item.quantity <= 0 || item.quantity > available) {
        throw StateError('كمية الإرجاع غير صالحة للصنف ${item.productName}');
      }
      remaining[key] = available - item.quantity;
    }

    // 1. Create a "Return Invoice" record for financial reports
    if (totalReturnAmount > 0) {
      final returnInvoice = originalInvoice.copyWith(
        id: 'RET-${DateTime.now().millisecondsSinceEpoch}',
        receiptNumber: 'RET-${originalInvoice.receiptNumber}',
        items: returnedItems,
        totalAmount: totalReturnAmount,
        paidAmount: totalReturnAmount, // Considered as "paid back" or credited
        date: DateTime.now(),
        isReturned: true, // This flag triggers the deduction in ReportRepository
        status: SalesInvoiceStatus.finalized,
      );
      await _salesBox.put(returnInvoice.id, returnInvoice);
      
      if (tenantId != 'local_default') {
        await LocalDbService.addToSyncQueue(
          collectionPath: 'sales_invoices/${returnInvoice.id}', 
          data: await _invoiceQueueData(returnInvoice),
          action: SyncAction.create
        );
      }
    }

    // 2. Return stock to inventory
    for (final item in returnedItems) {
      if (item.productId.isEmpty) continue;
      
      await productRepo.returnStock(
        tenantId, 
        item.productId, 
        item.quantity.toInt(),
        color: item.variantColor,
        size: item.variantSize,
        warehouseName: item.warehouseName ?? 'المخزن الرئيسي',
      );
    }

    // 3. Process Exchange (as a new sale)
    if (exchangeItems.isNotEmpty) {
      final exchangeInvoice = originalInvoice.copyWith(
        id: 'EX-${DateTime.now().millisecondsSinceEpoch}',
        receiptNumber: 'EX-${originalInvoice.receiptNumber}',
        items: exchangeItems,
        totalAmount: totalExchangeAmount,
        paidAmount: totalReturnAmount.clamp(0, totalExchangeAmount),
        date: DateTime.now(),
        isReturned: false,
        status: SalesInvoiceStatus.finalized,
        addedBy: originalInvoice.addedBy,
        addedById: originalInvoice.addedById,
      );
      await saveInvoice(tenantId, exchangeInvoice);
    }

    // 4. Update Customer balance
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

  List<SalesInvoiceModel> getPreviousReturnsForInvoice(String tenantId, String receiptNumber) {
    return _salesBox.values.where((s) => 
      s.tenantId == tenantId && 
      s.isReturned && 
      (s.receiptNumber == 'RET-$receiptNumber' || s.receiptNumber.contains(receiptNumber))
    ).toList();
  }
}

