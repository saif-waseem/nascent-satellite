import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'tenant_provider.dart';

class CurrentStaff extends Notifier<StaffMemberModel?> {
  @override
  StaffMemberModel? build() => null;
  
  void set(StaffMemberModel? staff) => state = staff;
}

final currentStaffProvider = NotifierProvider<CurrentStaff, StaffMemberModel?>(CurrentStaff.new);

enum PosPermission {
  viewSales,
  manageSales,
  viewProductStock,
  manageProducts,
  viewExpenses,
  manageExpenses,
  viewDebts,
  manageDebts,
  viewSuppliers,
  manageSuppliers,
  viewSettings,
  manageSettings,
  viewReports,
  manageOnlineOrders,
}

// Stream of custom roles defined for the tenant
final rolesProvider = StreamProvider((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  return FirebaseFirestore.instance
      .collection('roles')
      .where('tenantId', isEqualTo: tenantId)
      .snapshots()
      .map((s) => s.docs.map((d) => PosRoleModel.fromJson(d.data()..['id'] = d.id)).toList());
});

final permissionsProvider = Provider<Set<PosPermission>>((ref) {
  final staff = ref.watch(currentStaffProvider);
  if (staff == null) return <PosPermission>{};

  // 1. Try to find the role in custom roles
  final rolesAsync = ref.watch(rolesProvider);
  final customRoles = rolesAsync.value ?? [];
  
  final customRole = customRoles.where((r) => r.name.toLowerCase() == staff.roleName.toLowerCase()).firstOrNull;
  if (customRole != null) {
    return customRole.permissions
        .map((p) => PosPermission.values.firstWhere((e) => e.name == p))
        .toSet();
  }

  // 2. Fallback to hardcoded defaults (admin, manager, cashier)
  switch (staff.roleName.toLowerCase()) {
    case 'admin':
      return PosPermission.values.toSet();
    case 'manager':
      return {
        PosPermission.viewSales,
        PosPermission.manageSales,
        PosPermission.viewProductStock,
        PosPermission.manageProducts,
        PosPermission.viewExpenses,
        PosPermission.manageExpenses,
        PosPermission.viewDebts,
        PosPermission.manageDebts,
        PosPermission.viewSuppliers,
        PosPermission.manageSuppliers,
        PosPermission.viewReports,
      };
    case 'cashier':
    default:
      return {
        PosPermission.viewSales,
        PosPermission.manageSales,
        PosPermission.viewProductStock,
        PosPermission.viewSuppliers,
        PosPermission.viewReports,
      };
  }
});

extension PermissionX on WidgetRef {
  bool hasPermission(PosPermission permission) {
    final perms = watch(permissionsProvider);
    return perms.contains(permission);
  }
}
