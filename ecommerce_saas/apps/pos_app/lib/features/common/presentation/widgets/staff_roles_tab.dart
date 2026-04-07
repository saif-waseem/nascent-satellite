import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/providers/permissions_provider.dart';
import '../../../settings/data/staff_repository.dart';

class StaffRolesTab extends HookConsumerWidget {
  const StaffRolesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'الموظفون'),
              Tab(text: 'تعريف الأدوار'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _StaffManagementView(),
                _RoleDefinitionsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StaffManagementView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final staffAsync = ref.watch(staffListProvider(tenantId));

    final currentStaff = ref.watch(currentStaffProvider);
    // Allow seeing all staff if no one is logged in (owner mode) or if managerial
    final isManagerial = currentStaff == null || 
                         currentStaff.roleName.toLowerCase() == 'admin' || 
                         currentStaff.roleName.toLowerCase() == 'manager';

    return Scaffold(
      body: staffAsync.when(
        data: (staffList) {
          // Filter: Admin/Manager see all, others see only themselves
          final visibleStaff = isManagerial 
              ? staffList 
              : staffList.where((s) => s.id == currentStaff.id).toList();

          if (visibleStaff.isEmpty) {
             return const Center(child: Text('لا يوجد موظفون متاحون للعرض'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visibleStaff.length,
            itemBuilder: (context, index) {
              final staff = visibleStaff[index];
              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person),
                  ),
                  title: Text(staff.name),
                  subtitle: Text('الدور: ${staff.roleName} | شفتات: ${staff.dailyShiftCount}'),
                  trailing: isManagerial ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showStaffDialog(context, ref, tenantId, staff: staff),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDeleteStaff(context, ref, tenantId, staff),
                      ),
                    ],
                  ) : null,
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStaffDialog(context, ref, tenantId),
        icon: const Icon(Icons.add),
        label: const Text('إضافة موظف'),
      ),
    );
  }

  void _showStaffDialog(BuildContext context, WidgetRef ref, String tenantId, {StaffMemberModel? staff}) {
    showDialog(
      context: context,
      builder: (context) => _StaffFormDialog(tenantId: tenantId, staff: staff),
    );
  }

  Future<void> _confirmDeleteStaff(BuildContext context, WidgetRef ref, String tenantId, StaffMemberModel staff) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الموظف'),
        content: Text('هل أنت متأكد من حذف الموظف ${staff.name}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(staffRepositoryProvider).deleteStaff(tenantId, staff.id);
      ref.invalidate(staffListProvider(tenantId));
    }
  }
}

class _RoleDefinitionsView extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final rolesAsync = ref.watch(roleListProvider(tenantId));

    return Scaffold(
      body: rolesAsync.when(
        data: (roles) => ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: roles.length,
          itemBuilder: (context, index) {
            final role = roles[index];
            return Card(
              child: ListTile(
                title: Text(role.name),
                subtitle: Text('عدد الصلاحيات: ${role.permissions.length}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showRoleDialog(context, ref, tenantId, role: role),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDeleteRole(context, ref, tenantId, role),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRoleDialog(context, ref, tenantId),
        icon: const Icon(Icons.security),
        label: const Text('إضافة دور جديد'),
      ),
    );
  }

  void _showRoleDialog(BuildContext context, WidgetRef ref, String tenantId, {PosRoleModel? role}) {
    showDialog(
      context: context,
      builder: (context) => _RoleFormDialog(tenantId: tenantId, role: role),
    );
  }

  Future<void> _confirmDeleteRole(BuildContext context, WidgetRef ref, String tenantId, PosRoleModel role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الدور'),
        content: Text('هل أنت متأكد من حذف الدور "${role.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(staffRepositoryProvider).deleteRole(tenantId, role.id);
      ref.invalidate(roleListProvider(tenantId));
    }
  }
}

class _StaffFormDialog extends HookConsumerWidget {
  final String tenantId;
  final StaffMemberModel? staff;
  const _StaffFormDialog({required this.tenantId, this.staff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController(text: staff?.name);
    final pinController = useTextEditingController(text: staff?.pinCode);
    final emailController = useTextEditingController(text: staff?.email);
    final salaryController = useTextEditingController(text: staff?.salaryAmount.toString() ?? '0');
    // Mode: true for Days, false for Shifts
    final isDaysMode = useState(staff != null ? (staff!.salaryCycleDays > 0) : true);
    final reqUnitsController = useTextEditingController(
      text: (isDaysMode.value ? staff?.requiredDaysForSalary : staff?.requiredDaysForSalary)?.toString() ?? '20'
    );
    final cycleDaysController = useTextEditingController(text: staff?.salaryCycleDays.toString() ?? '30');
    
    final selectedRole = useState(staff?.roleName ?? 'cashier');
    final isLoading = useState(false);
    final rolesAsync = ref.watch(roleListProvider(tenantId));

    return AlertDialog(
      title: Text(staff == null ? 'إضافة موظف جديد' : 'تعديل بيانات الموظف'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            rolesAsync.when(
              data: (roles) {
                // Ensure default roles are available if not in DB
                final allRoleNames = {'admin', 'manager', 'cashier', ...roles.map((r) => r.name)};
                return DropdownButtonFormField<String>(
                  value: allRoleNames.contains(selectedRole.value) ? selectedRole.value : 'cashier',
                  decoration: const InputDecoration(labelText: 'الصلاحية / الدور', border: OutlineInputBorder()),
                  items: allRoleNames.map((roleName) {
                    return DropdownMenuItem(
                      value: roleName,
                      child: Text(roleName.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) => selectedRole.value = val!,
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('خطأ في تحميل الأدوار'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              decoration: const InputDecoration(labelText: 'كود PIN (اختياري)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            const Text('نظام الراتب:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('أيام'), icon: Icon(Icons.calendar_today_outlined)),
                ButtonSegment(value: false, label: Text('شفتات'), icon: Icon(Icons.timer_outlined)),
              ],
              selected: {isDaysMode.value},
              onSelectionChanged: (val) => isDaysMode.value = val.first,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: salaryController,
              decoration: const InputDecoration(labelText: 'الراتب الأساسي', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            if (isDaysMode.value) ...[
              const SizedBox(height: 16),
              TextField(
                controller: cycleDaysController,
                decoration: const InputDecoration(
                  labelText: 'دورة الراتب (مثلاً 30 يوم)', 
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: reqUnitsController,
              decoration: InputDecoration(
                labelText: isDaysMode.value ? 'أيام الحضور المطلوبة' : 'عدد الشفتات المطلوبة للراتب', 
                helperText: isDaysMode.value ? 'عدد الأيام التي يجب حضورها لاستحقاق الراتب' : 'عدد الشفتات الإجمالي لاستحقاق الراتب',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: isLoading.value ? null : () async {
            if (nameController.text.isEmpty) return;
            isLoading.value = true;
            try {
              final newStaff = (staff ?? StaffMemberModel(
                id: '',
                tenantId: tenantId,
                name: '',
                roleName: 'cashier',
                createdAt: DateTime.now(),
              )).copyWith(
                name: nameController.text,
                roleName: selectedRole.value,
                pinCode: pinController.text,
                email: emailController.text,
                salaryAmount: double.tryParse(salaryController.text) ?? 0.0,
                salaryCycleDays: isDaysMode.value ? (int.tryParse(cycleDaysController.text) ?? 30) : 0,
                requiredDaysForSalary: int.tryParse(reqUnitsController.text) ?? 20,
                dailyShiftCount: 1, // Fixed to 1 as requested to simplify
              );
              await ref.read(staffRepositoryProvider).saveStaff(newStaff);
              ref.invalidate(staffListProvider(tenantId));
              if (context.mounted) Navigator.pop(context);
            } finally {
              isLoading.value = false;
            }
          },
          child: isLoading.value ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('حفظ'),
        ),
      ],
    );
  }
}

class _RoleFormDialog extends HookConsumerWidget {
  final String tenantId;
  final PosRoleModel? role;
  const _RoleFormDialog({required this.tenantId, this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController(text: role?.name);
    final selectedPermissions = useState<Set<String>>(role?.permissions.toSet() ?? {});
    final isLoading = useState(false);

    return AlertDialog(
      title: Text(role == null ? 'إضافة دور جديد' : 'تعديل الدور'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم الدور', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text('الصلاحيات:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              ...PosPermission.values.map((p) {
                return CheckboxListTile(
                  title: Text(_getPermissionLabel(p)),
                  value: selectedPermissions.value.contains(p.name),
                  onChanged: (val) {
                    final newSet = Set<String>.from(selectedPermissions.value);
                    if (val == true) {
                      newSet.add(p.name);
                    } else {
                      newSet.remove(p.name);
                    }
                    selectedPermissions.value = newSet;
                  },
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          onPressed: isLoading.value ? null : () async {
            if (nameController.text.isEmpty) return;
            isLoading.value = true;
            try {
              final newRole = PosRoleModel(
                id: role?.id ?? '',
                tenantId: tenantId,
                name: nameController.text,
                permissions: selectedPermissions.value.toList(),
              );
              await ref.read(staffRepositoryProvider).saveRole(tenantId, newRole);
              if (context.mounted) Navigator.pop(context);
            } finally {
              isLoading.value = false;
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }

  String _getPermissionLabel(PosPermission p) {
    switch (p) {
      case PosPermission.viewSales: return 'عرض المبيعات';
      case PosPermission.manageSales: return 'إدارة المبيعات (إضافة/حذف)';
      case PosPermission.viewProductStock: return 'عرض المخزون';
      case PosPermission.manageProducts: return 'إدارة المنتجات';
      case PosPermission.viewExpenses: return 'عرض المصروفات';
      case PosPermission.manageExpenses: return 'إدارة المصروفات';
      case PosPermission.viewDebts: return 'عرض الديون';
      case PosPermission.manageDebts: return 'إدارة الديون';
      case PosPermission.viewSuppliers: return 'عرض الموردين';
      case PosPermission.manageSuppliers: return 'إدارة الموردين';
      case PosPermission.viewSettings: return 'عرض الإعدادات';
      case PosPermission.manageSettings: return 'تعديل الإعدادات';
      case PosPermission.viewReports: return 'عرض التقارير المالية';
      case PosPermission.manageOnlineOrders: return 'إدارة الطلبات أونلاين';
    }
  }
}
