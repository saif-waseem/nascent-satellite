import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/models/sync_queue_item.dart';

final supplierRepositoryProvider = Provider((ref) => SupplierRepository(ref));

class SupplierRepository {
  final Ref _ref;
  FirestoreRestService get _restService => _ref.read(firestoreRestServiceProvider);

  SupplierRepository(this._ref);

  Box<SupplierModel> get _supplierBox => LocalDbService.getBox<SupplierModel>('suppliers');

  Future<List<SupplierModel>> getSuppliers(String tenantId) async {
    final cached = _supplierBox.values.where((s) => s.tenantId == tenantId).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    
    if (tenantId == 'local_default') return cached;

    // Background fetch
    _fetchSuppliersRemote(tenantId);
    
    return cached;
  }

  Future<void> _fetchSuppliersRemote(String tenantId) async {
    try {
      final query = {
        'where': {
          'fieldFilter': {
            'field': {'fieldPath': 'tenantId'},
            'op': 'EQUAL',
            'value': {'stringValue': tenantId}
          }
        }
      };
      final results = await _restService.runQuery('suppliers', query);
      final list = results.map((data) => SupplierModel.fromJson(data)).toList();
      for (var s in list) {
        await _supplierBox.put(s.id, s);
      }
    } catch (e) {
      debugPrint('Error fetching suppliers: $e');
    }
  }

  Future<void> addSupplier(String tenantId, SupplierModel supplier) async {
    final id = supplier.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : supplier.id;
    final finalSupplier = supplier.copyWith(id: id, tenantId: tenantId);
    
    await _supplierBox.put(id, finalSupplier);

    if (tenantId == 'local_default') return;

    await LocalDbService.addToSyncQueue(
      collectionPath: 'suppliers/$id', 
      data: finalSupplier.toJson(), 
      action: supplier.id.isNotEmpty ? SyncAction.update : SyncAction.create
    );
  }

  Future<void> updateSupplier(String tenantId, SupplierModel supplier) async {
    await _supplierBox.put(supplier.id, supplier);

    if (tenantId == 'local_default') return;

    await LocalDbService.addToSyncQueue(
      collectionPath: 'suppliers/${supplier.id}', 
      data: supplier.toJson(), 
      action: SyncAction.update
    );
  }

  Future<void> deleteSupplier(String tenantId, String supplierId) async {
    await _supplierBox.delete(supplierId);

    if (tenantId == 'local_default') return;

    await LocalDbService.addToSyncQueue(
      collectionPath: 'suppliers/$supplierId', 
      data: {}, 
      action: SyncAction.delete
    );
  }

  Future<SupplierModel?> getSupplier(String tenantId, String supplierId) async {
    final cached = _supplierBox.get(supplierId);
    if (cached != null) return cached;

    if (tenantId == 'local_default') return null;

    try {
      final data = await _restService.getDocument('suppliers/$supplierId');
      if (data == null) return null;
      final supplier = SupplierModel.fromJson(data);
      await _supplierBox.put(supplier.id, supplier);
      return supplier;
    } catch (e) {
      return null;
    }
  }
}

