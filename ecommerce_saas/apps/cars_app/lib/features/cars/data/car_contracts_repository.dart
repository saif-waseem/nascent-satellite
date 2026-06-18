import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/models/sync_queue_item.dart';

final carContractsRepositoryProvider = Provider((ref) => CarContractsRepository(ref));

final carContractsProvider = FutureProvider.family<List<CarContractModel>, String>((ref, tenantId) async {
  final repo = ref.watch(carContractsRepositoryProvider);
  return repo.getContracts(tenantId);
});

class CarContractsRepository {
  final Ref _ref;
  FirestoreRestService get _restService => _ref.read(firestoreRestServiceProvider);

  CarContractsRepository(this._ref);

  Box<CarContractModel> get _carsBox => LocalDbService.getBox<CarContractModel>('car_contracts');

  Future<List<CarContractModel>> getContracts(String tenantId, {int limit = 100}) async {
    final cached = _carsBox.values
        .where((s) => s.tenantId == tenantId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    final result = cached.take(limit).toList();
    
    if (tenantId == 'local_default') return result;

    _fetchContractsRemote(tenantId, limit);
    
    return result;
  }

  Future<void> _fetchContractsRemote(String tenantId, int limit) async {
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
          {'field': {'fieldPath': 'createdAt'}, 'direction': 'DESCENDING'}
        ],
        'limit': limit,
      };
      final results = await _restService.runQuery('car_contracts', query);
      final remoteContracts = results.map((data) => CarContractModel.fromJson(data)).toList();
      for (var contract in remoteContracts) {
        await _carsBox.put(contract.id, contract);
      }
    } catch (e) {
      debugPrint('Error background fetching car contracts: $e');
    }
  }

  Future<void> saveContract(String tenantId, CarContractModel contract) async {
    await _carsBox.put(contract.id, contract);

    if (tenantId == 'local_default') return;

    await LocalDbService.addToSyncQueue(
      collectionPath: 'car_contracts',
      data: contract.toJson(),
      action: SyncAction.create,
    );
  }

  Future<void> deleteContract(String tenantId, String contractId) async {
    await _carsBox.delete(contractId);

    if (tenantId == 'local_default') return;

    await LocalDbService.addToSyncQueue(
      collectionPath: 'car_contracts/$contractId',
      data: {'id': contractId},
      action: SyncAction.delete,
    );
  }
}
