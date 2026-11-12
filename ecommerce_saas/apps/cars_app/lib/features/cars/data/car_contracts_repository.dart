import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import '../../../../core/services/local_db_service.dart';
import '../../../../core/services/cars_supabase_service.dart';

final carsSupabaseServiceProvider = Provider((ref) => CarsSupabaseService());

final carContractsRepositoryProvider = Provider((ref) => CarContractsRepository(ref));

final carContractsStreamProvider = StreamProvider.family<List<CarContractModel>, String>((ref, tenantId) {
  final repo = ref.watch(carContractsRepositoryProvider);
  return repo.watchContracts(tenantId);
});

class CarContractsRepository {
  final Ref _ref;
  CarContractsRepository(this._ref);

  Box<CarContractModel> get _box => LocalDbService.getBox<CarContractModel>('car_contracts');
  CarsSupabaseService get _supabase => _ref.read(carsSupabaseServiceProvider);

  Stream<List<CarContractModel>> watchContracts(String tenantId) async* {
    // 1. Instant local display (0ms load time - Offline first)
    yield getLocalContracts(tenantId);

    // 2. Background sync from Supabase SQL table (New Architecture)
    if (tenantId.isNotEmpty && tenantId != 'local_default') {
      _syncFromSupabase(tenantId);
      _syncFromFirestore(tenantId);
    }

    // 3. Emit on any local database change
    await for (final _ in _box.watch()) {
      yield getLocalContracts(tenantId);
    }
  }

  Future<void> _syncFromSupabase(String tenantId) async {
    try {
      final contracts = await _supabase.getContracts(tenantId);
      if (contracts.isNotEmpty) {
        for (final contract in contracts) {
          _box.put(contract.id, contract);
        }
      }
    } catch (e) {
      debugPrint('Supabase background sync note: $e');
    }
  }

  void _syncFromFirestore(String tenantId) {
    try {
      FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('car_contracts')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) {
        for (final doc in snapshot.docs) {
          final data = {'id': doc.id, ...doc.data()};
          final contract = CarContractModel.fromJson(data);
          _box.put(contract.id, contract);
        }
      }, onError: (e) => debugPrint('Firestore fallback sync note: $e'));
    } catch (_) {}
  }

  /// Save contract locally first, then sync to cloud
  Future<void> saveContract(String tenantId, CarContractModel contract) async {
    // 1. Local first
    await _box.put(contract.id, contract);

    if (tenantId.isEmpty || tenantId == 'local_default') return;

    // 2. Sync to Supabase SQL Database (New Architecture)
    try {
      await _supabase.upsertContract(contract);
    } catch (e) {
      debugPrint('Supabase save contract error: $e');
    }

    // 3. Sync to Firestore (Fallback)
    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('car_contracts')
          .doc(contract.id)
          .set(contract.toJson());
    } catch (e) {
      debugPrint('Firestore save contract error: $e');
    }
  }

  /// Bulk save contracts (used in Excel import)
  Future<int> batchSaveContracts(String tenantId, List<CarContractModel> contracts) async {
    if (contracts.isEmpty) return 0;

    // Save locally
    for (final c in contracts) {
      await _box.put(c.id, c);
    }

    if (tenantId.isNotEmpty && tenantId != 'local_default') {
      // Sync to Supabase
      try {
        await _supabase.batchUpsertContracts(contracts);
      } catch (e) {
        debugPrint('Supabase batch save error: $e');
      }

      // Sync to Firestore fallback
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final c in contracts) {
          final docRef = FirebaseFirestore.instance
              .collection('tenants')
              .doc(tenantId)
              .collection('car_contracts')
              .doc(c.id);
          batch.set(docRef, c.toJson());
        }
        await batch.commit();
      } catch (e) {
        debugPrint('Firestore batch save error: $e');
      }
    }

    return contracts.length;
  }

  /// Delete contract
  Future<void> deleteContract(String tenantId, String contractId) async {
    await _box.delete(contractId);

    if (tenantId.isEmpty || tenantId == 'local_default') return;

    // Supabase
    try {
      await _supabase.deleteContract(contractId);
    } catch (e) {
      debugPrint('Supabase delete contract error: $e');
    }

    // Firestore
    try {
      await FirebaseFirestore.instance
          .collection('tenants')
          .doc(tenantId)
          .collection('car_contracts')
          .doc(contractId)
          .delete();
    } catch (e) {
      debugPrint('Firestore delete contract error: $e');
    }
  }

  List<CarContractModel> getLocalContracts(String tenantId) {
    return _box.values.where((c) => c.tenantId == tenantId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
