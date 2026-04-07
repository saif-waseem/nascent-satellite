import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';

final staffRepositoryProvider = Provider((ref) => StaffRepository());

class StaffRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<StaffMemberModel>> watchStaff(String tenantId) {
    return _firestore
        .collection('staff')
        .where('tenantId', isEqualTo: tenantId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StaffMemberModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> saveStaff(StaffMemberModel staff) async {
    final docRef = _firestore
        .collection('staff')
        .doc(staff.id.isEmpty ? null : staff.id);

    final data = staff.toJson();
    if (staff.id.isEmpty) {
      data.remove('id');
      await docRef.set(data);
    } else {
      await docRef.update(data);
    }
  }

  Future<void> deleteStaff(String tenantId, String staffId) async {
    await _firestore
        .collection('staff')
        .doc(staffId)
        .delete();
  }

  // --- Role Management ---

  Stream<List<PosRoleModel>> watchRoles(String tenantId) {
    return _firestore
        .collection('roles')
        .where('tenantId', isEqualTo: tenantId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PosRoleModel.fromJson({...doc.data(), 'id': doc.id}))
            .toList());
  }

  Future<void> saveRole(String tenantId, PosRoleModel role) async {
    final docRef = _firestore
        .collection('roles')
        .doc(role.id.isEmpty ? null : role.id);

    final data = role.toJson();
    if (role.id.isEmpty) {
      data.remove('id');
      await docRef.set(data);
    } else {
      await docRef.update(data);
    }
  }

  Future<void> deleteRole(String tenantId, String roleId) async {
    await _firestore
        .collection('roles')
        .doc(roleId)
        .delete();
  }
}

final roleListProvider = StreamProvider.family<List<PosRoleModel>, String>((ref, tenantId) {
  return ref.watch(staffRepositoryProvider).watchRoles(tenantId);
});

final staffListProvider = StreamProvider.family<List<StaffMemberModel>, String>((ref, tenantId) {
  return ref.watch(staffRepositoryProvider).watchStaff(tenantId);
});
