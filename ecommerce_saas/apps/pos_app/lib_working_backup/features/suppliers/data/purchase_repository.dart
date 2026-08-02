import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/models/sync_queue_item.dart';

final purchaseRepositoryProvider = Provider((ref) => PurchaseRepository(ref));

class PurchaseRepository {
  final Ref _ref;
  FirestoreRestService get _restService => _ref.read(firestoreRestServiceProvider);

  PurchaseRepository(this._ref);

  Box<PurchaseInvoiceModel> get _purchaseBox => LocalDbService.getBox<PurchaseInvoiceModel>('purchases');
  Box<ProductModel> get _productBox => LocalDbService.getBox<ProductModel>('products');
  Box<SupplierModel> get _supplierBox => LocalDbService.getBox<SupplierModel>('suppliers');

  Future<void> saveInvoice(String tenantId, PurchaseInvoiceModel invoice) async {
    final id = invoice.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : invoice.id;
    final updatedInvoice = invoice.copyWith(id: id, tenantId: tenantId);
    
    // 1. Save locally
    await _purchaseBox.put(id, updatedInvoice);

    // 2. Update local stock and supplier balance
    if (updatedInvoice.status == PurchaseInvoiceStatus.finalized) {
      await _updateLocalStateForPurchase(updatedInvoice);
    }

    if (tenantId == 'local_default') return;

    // 3. Sync queue
    await LocalDbService.addToSyncQueue(
      collectionPath: 'purchase_invoices/$id', 
      data: updatedInvoice.toJson(), 
      action: invoice.id.isNotEmpty ? SyncAction.update : SyncAction.create
    );

    // Queue related updates
    for (final item in updatedInvoice.items) {
      final p = _productBox.get(item.productId);
      if (p != null) {
        await LocalDbService.addToSyncQueue(collectionPath: 'products/${p.id}', data: p.toJson(), action: SyncAction.update);
      }
    }
    if (updatedInvoice.supplierId.isNotEmpty) {
      final s = _supplierBox.get(updatedInvoice.supplierId);
      if (s != null) {
        await LocalDbService.addToSyncQueue(collectionPath: 'suppliers/${s.id}', data: s.toJson(), action: SyncAction.update);
      }
    }
  }

  Future<void> _updateLocalStateForPurchase(PurchaseInvoiceModel invoice) async {
    // Stock
    for (final item in invoice.items) {
      if (item.productId.isNotEmpty) {
        final product = _productBox.get(item.productId);
        if (product != null) {
          final updatedProduct = product.copyWith(
            stockQuantity: product.stockQuantity + item.quantity,
            lastSupplierId: invoice.supplierId,
            purchasePrice: item.unitCost, // Update purchase price to last purchase price
            inStock: true,
          );
          await _productBox.put(item.productId, updatedProduct);
        }
      }
    }

    // Supplier Balance
    if (invoice.supplierId.isNotEmpty) {
      final supplier = _supplierBox.get(invoice.supplierId);
      if (supplier != null) {
        final updatedSupplier = supplier.copyWith(
          balance: supplier.balance + invoice.remainingAmount,
        );
        await _supplierBox.put(invoice.supplierId, updatedSupplier);
      }
    }
  }

  Future<List<PurchaseInvoiceModel>> getInvoices(String tenantId, {String? supplierId, int limit = 50}) async {
    final cached = _purchaseBox.values.where((inv) => inv.tenantId == tenantId).toList();
    
    if (supplierId != null) {
      cached.retainWhere((inv) => inv.supplierId == supplierId);
    }
    
    cached.sort((a, b) => b.date.compareTo(a.date));

    final result = cached.take(limit).toList();

    if (tenantId == 'local_default') return result;

    // Background fetch
    _fetchRecentPurchasesRemote(tenantId, limit, supplierId: supplierId);

    return result;
  }

  Future<void> _fetchRecentPurchasesRemote(String tenantId, int limit, {String? supplierId}) async {
    try {
      final filters = <Map<String, dynamic>>[
        {
          'fieldFilter': {
            'field': {'fieldPath': 'tenantId'},
            'op': 'EQUAL',
            'value': {'stringValue': tenantId}
          }
        }
      ];

      if (supplierId != null) {
        filters.add({
          'fieldFilter': {
            'field': {'fieldPath': 'supplierId'},
            'op': 'EQUAL',
            'value': {'stringValue': supplierId}
          }
        });
      }

      final query = {
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': filters,
          }
        },
        'orderBy': [
          {'field': {'fieldPath': 'date'}, 'direction': 'DESCENDING'}
        ],
        'limit': limit,
      };

      final results = await _restService.runQuery('purchase_invoices', query);
      final remoteInvoices = results.map((data) => PurchaseInvoiceModel.fromJson(data)).toList();
      for (var inv in remoteInvoices) {
        await _purchaseBox.put(inv.id, inv);
      }
    } catch (e) {
      debugPrint('Error background fetching purchases: $e');
    }
  }

  Future<List<PurchaseInvoiceModel>> getAllInvoices(String tenantId) => getInvoices(tenantId);
}

final purchasesListProvider = FutureProvider.family<List<PurchaseInvoiceModel>, String>((ref, tenantId) {
  return ref.watch(purchaseRepositoryProvider).getAllInvoices(tenantId);
});

