import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../../core/services/firestore_rest_service.dart';

final staffRepositoryProvider = Provider((ref) => StaffRepository(ref.watch(firestoreRestServiceProvider)));

class StaffRepository {
  final FirestoreRestService _restService;

  StaffRepository(this._restService);

  Future<List<StaffMemberModel>> getStaff(String tenantId) async {
    final query = {
      'where': {
        'fieldFilter': {
          'field': {'fieldPath': 'tenantId'},
          'op': 'EQUAL',
          'value': {'stringValue': tenantId}
        }
      }
    };

    final results = await _restService.runQuery('staff', query);
    return results.map((data) => StaffMemberModel.fromJson(data)).toList();
  }

  Future<void> saveStaff(StaffMemberModel staff) async {
    final staffId = staff.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : staff.id;
    await _restService.setDocument('staff/$staffId', staff.toJson(), isUpdate: staff.id.isNotEmpty);
  }

  Future<void> deleteStaff(String tenantId, String staffId) async {
    await _restService.deleteDocument('staff/$staffId');
  }

  // --- Role Management ---

  Future<List<PosRoleModel>> getRoles(String tenantId) async {
    final query = {
      'where': {
        'fieldFilter': {
          'field': {'fieldPath': 'tenantId'},
          'op': 'EQUAL',
          'value': {'stringValue': tenantId}
        }
      }
    };

    final results = await _restService.runQuery('roles', query);
    return results.map((data) => PosRoleModel.fromJson(data)).toList();
  }

  Future<void> saveRole(String tenantId, PosRoleModel role) async {
    final roleId = role.id.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : role.id;
    await _restService.setDocument('roles/$roleId', role.toJson(), isUpdate: role.id.isNotEmpty);
  }

  Future<void> deleteRole(String tenantId, String roleId) async {
    await _restService.deleteDocument('roles/$roleId');
  }
}

// Changing StreamProvider to FutureProvider for REST
final roleListProvider = FutureProvider.family<List<PosRoleModel>, String>((ref, tenantId) {
  return ref.watch(staffRepositoryProvider).getRoles(tenantId);
});

final staffListProvider = FutureProvider.family<List<StaffMemberModel>, String>((ref, tenantId) {
  return ref.watch(staffRepositoryProvider).getStaff(tenantId);
});
