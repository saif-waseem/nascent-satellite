import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

final supplierRepositoryProvider = Provider((ref) => SupplierRepository(FirebaseFirestore.instance));

class SupplierRepository {
  final FirebaseFirestore _firestore;

  SupplierRepository(this._firestore);

  CollectionReference<SupplierModel> _supplierBase() =>
      _firestore.collection('suppliers').withConverter<SupplierModel>(
            fromFirestore: (snapshot, _) => SupplierModel.fromJson(snapshot.data()!..['id'] = snapshot.id),
            toFirestore: (model, _) => model.toJson(),
          );

  Query<SupplierModel> _suppliers(String tenantId) =>
      _supplierBase().where('tenantId', isEqualTo: tenantId);

  Future<List<SupplierModel>> getSuppliers(String tenantId) async {
    final snapshot = await _suppliers(tenantId).get();
    final list = snapshot.docs.map((doc) => doc.data()).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  Stream<List<SupplierModel>> watchSuppliers(String tenantId) {
    return _suppliers(tenantId).snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => doc.data()).toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    });
  }

  Future<void> addSupplier(String tenantId, SupplierModel supplier) async {
    final ref = _supplierBase().doc();
    final finalSupplier = supplier.copyWith(id: ref.id, tenantId: tenantId);
    await ref.set(finalSupplier);
  }

  Future<void> updateSupplier(String tenantId, SupplierModel supplier) async {
    await _supplierBase().doc(supplier.id).set(supplier);
  }

  Future<void> deleteSupplier(String tenantId, String supplierId) async {
    await _supplierBase().doc(supplierId).delete();
  }

  Future<SupplierModel?> getSupplier(String tenantId, String supplierId) async {
    final doc = await _supplierBase().doc(supplierId).get();
    return doc.data();
  }
}

final suppliersListProvider = StreamProvider.family<List<SupplierModel>, String>((ref, tenantId) {
  return ref.watch(supplierRepositoryProvider).watchSuppliers(tenantId);
});
