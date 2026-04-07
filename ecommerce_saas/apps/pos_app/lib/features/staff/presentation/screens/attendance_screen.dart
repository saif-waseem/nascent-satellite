import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../settings/data/staff_repository.dart';
import '../../data/attendance_repository.dart';
import '../../../../core/providers/permissions_provider.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final staffAsync = ref.watch(staffListProvider(tenantId));
    final currentStaff = ref.watch(currentStaffProvider);
    final isManagerial = currentStaff?.roleName.toLowerCase() == 'admin' || currentStaff?.roleName.toLowerCase() == 'manager';

    return Scaffold(
      appBar: AppBar(
        title: const Text('حضور وانصراف الموظفين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: isManagerial ? FloatingActionButton.extended(
        onPressed: () => _showAddStaffDialog(context, ref, tenantId),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة موظف'),
      ) : null,
      body: staffAsync.when(
        data: (staffList) {
          final visibleStaff = isManagerial 
            ? staffList 
            : staffList.where((s) => s.id == currentStaff?.id).toList();

          if (visibleStaff.isEmpty) {
            return const Center(child: Text('لا يوجد موظفون متاحون'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visibleStaff.length,
            itemBuilder: (context, index) {
              final staff = visibleStaff[index];
              return _StaffAttendanceCard(staff: staff);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _showAddStaffDialog(BuildContext context, WidgetRef ref, String tenantId) async {
    final nameController = TextEditingController();
    final roleController = TextEditingController(text: 'كاشير');
    final pinController = TextEditingController();
    final salaryController = TextEditingController(text: '500000');
    final cycleController = TextEditingController(text: '30');
    final requiredDaysController = TextEditingController(text: '20');

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة موظف جديد'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: roleController, decoration: const InputDecoration(labelText: 'الوظيفة', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: pinController, decoration: const InputDecoration(labelText: 'كود PIN (أرقام)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Divider()),
              TextField(controller: salaryController, decoration: const InputDecoration(labelText: 'الراتب المستحق', border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              TextField(
                controller: cycleController, 
                decoration: const InputDecoration(
                  labelText: 'دورة الراتب (أيام)', 
                  helperText: 'عدد أيام الشهر (مثلاً 30). ضع 0 إذا كان العمل باليومية فقط.', 
                  border: OutlineInputBorder()
                ), 
                keyboardType: TextInputType.number
              ),
              const SizedBox(height: 16),
              TextField(
                controller: requiredDaysController, 
                decoration: const InputDecoration(
                  labelText: 'أيام الحضور المطلوبة', 
                  helperText: 'عدد الأيام/الشفتات الواجب إكمالها في الدورة للحصول على الراتب الكامل',
                  border: OutlineInputBorder()
                ), 
                keyboardType: TextInputType.number
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              if (nameController.text.isEmpty || pinController.text.isEmpty) return;
              
              final newStaff = StaffMemberModel(
                id: '',
                tenantId: tenantId,
                name: nameController.text,
                roleName: roleController.text,
                pinCode: pinController.text,
                createdAt: DateTime.now(),
                salaryAmount: double.tryParse(salaryController.text) ?? 500000,
                salaryCycleDays: int.tryParse(cycleController.text) ?? 30,
                requiredDaysForSalary: int.tryParse(requiredDaysController.text) ?? 20,
              );

              await ref.read(staffRepositoryProvider).saveStaff(newStaff);
              if (context.mounted) {
                Navigator.pop(context);
                ref.invalidate(staffListProvider(tenantId));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
}

class _StaffAttendanceCard extends ConsumerWidget {
  final StaffMemberModel staff;
  const _StaffAttendanceCard({required this.staff});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final activeAttendanceAsync = ref.watch(activeAttendanceProvider((tenantId: tenantId, staffId: staff.id)));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(staff.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(staff.roleName),
        leading: IconButton(
          icon: const Icon(Icons.history, color: Colors.blue),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttendanceHistoryScreen(staffId: staff.id, staffName: staff.name),
            ),
          ),
        ),
        trailing: activeAttendanceAsync.when(
          data: (active) => _buildActionButton(context, ref, active, tenantId),
          loading: () => const CircularProgressIndicator(),
          error: (_, __) => const Icon(Icons.error, color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref, AttendanceModel? active, String tenantId) {
    if (active == null) {
      return ElevatedButton.icon(
        onPressed: () => _handleCheckIn(context, ref, tenantId),
        icon: const Icon(Icons.login),
        label: const Text('تسجيل حضور'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: () => _handleCheckOut(context, ref, active, tenantId),
        icon: const Icon(Icons.logout),
        label: const Text('تسجيل انصراف'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
      );
    }
  }

  Future<void> _handleCheckIn(BuildContext context, WidgetRef ref, String tenantId) async {
    final pin = await _showPinDialog(context);
    if (pin != staff.pinCode) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كود PIN خاطئ'), backgroundColor: Colors.red));
      }
      return;
    }

    await ref.read(attendanceRepositoryProvider).checkIn(AttendanceModel(
      id: '',
      staffId: staff.id,
      staffName: staff.name,
      tenantId: tenantId,
      checkIn: DateTime.now(),
    ));

    ref.invalidate(activeAttendanceProvider((tenantId: tenantId, staffId: staff.id)));
  }

  Future<void> _handleCheckOut(BuildContext context, WidgetRef ref, AttendanceModel active, String tenantId) async {
    final pin = await _showPinDialog(context);
    if (pin != staff.pinCode) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كود PIN خاطئ'), backgroundColor: Colors.red));
      }
      return;
    }

    await ref.read(attendanceRepositoryProvider).checkOut(tenantId, active.id, DateTime.now());
    ref.invalidate(activeAttendanceProvider((tenantId: tenantId, staffId: staff.id)));
  }

  Future<String?> _showPinDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الهوية: ${staff.name}'),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'كود PIN'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('تأكيد')),
        ],
      ),
    );
  }
}

class AttendanceHistoryScreen extends ConsumerWidget {
  final String? staffId;
  final String? staffName;
  const AttendanceHistoryScreen({super.key, this.staffId, this.staffName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final historyAsync = ref.watch(attendanceHistoryProvider((tenantId: tenantId, staffId: staffId)));

    return Scaffold(
      appBar: AppBar(
        title: Text(staffName != null ? 'سجل حضور: $staffName' : 'سجل الحضور العام'),
      ),
      body: historyAsync.when(
        data: (history) => ListView.builder(
          itemCount: history.length,
          itemBuilder: (context, index) {
            final record = history[index];
            final checkInDate = record.checkIn.toString().substring(0, 10);
            final checkInTime = record.checkIn.toString().substring(11, 16);
            final checkOutTime = record.checkOut != null ? record.checkOut.toString().substring(11, 16) : '--:--';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                title: Text(record.staffName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('التاريخ: $checkInDate | الحضور: $checkInTime | الانصراف: $checkOutTime'),
                leading: const Icon(Icons.event_note, color: Colors.blue),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}
