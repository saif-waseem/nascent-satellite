import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../../../core/services/local_db_service.dart';

final carContractsRepositoryProvider = Provider((ref) => CarContractsRepository(ref));

final carContractsStreamProvider = StreamProvider.family<List<CarContractModel>, String>((ref, tenantId) {
  final repo = ref.watch(carContractsRepositoryProvider);
  return repo.watchContracts(tenantId);
});

class CarContractsRepository {
  final Ref _ref;
  CarContractsRepository(this._ref);

  Box<CarContractModel> get _box => LocalDbService.getBox<CarContractModel>('car_contracts');

  /// Local-first stream
  Stream<List<CarContractModel>> watchContracts(String tenantId) async* {
    // Yield local immediately
    final local = _box.values.where((c) => c.tenantId == tenantId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    yield local;

    // Then sync from Firestore
    if (tenantId.isEmpty || tenantId == 'local_default') return;
    try {
      await for (final snapshot in FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('car_contracts')
          .orderBy('createdAt', descending: true)
          .snapshots()) {
        for (final doc in snapshot.docs) {
          final data = {'id': doc.id, ...doc.data()};
          final contract = CarContractModel.fromJson(data);
          await _box.put(contract.id, contract);
        }
        final updated = _box.values.where((c) => c.tenantId == tenantId).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        yield updated;
      }
    } catch (e) {
      debugPrint('Error watching contracts: $e');
    }
  }

  Future<void> saveContract(String tenantId, CarContractModel contract) async {
    // Save locally first
    await _box.put(contract.id, contract);

    // Sync to Firestore
    if (tenantId.isEmpty || tenantId == 'local_default') return;
    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('car_contracts')
          .doc(contract.id)
          .set(contract.toJson());
    } catch (e) {
      debugPrint('Error saving contract to Firestore: $e');
    }
  }

  Future<void> deleteContract(String tenantId, String contractId) async {
    await _box.delete(contractId);
    if (tenantId.isEmpty || tenantId == 'local_default') return;
    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('car_contracts')
          .doc(contractId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting contract from Firestore: $e');
    }
  }

  List<CarContractModel> getLocalContracts(String tenantId) {
    return _box.values.where((c) => c.tenantId == tenantId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
