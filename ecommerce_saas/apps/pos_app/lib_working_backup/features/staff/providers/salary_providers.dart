import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../data/attendance_repository.dart';
import '../../settings/data/staff_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import 'package:shared_models/shared_models.dart';

final dueSalariesProvider = FutureProvider<List<StaffMemberModel>>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final staffAsync = ref.watch(staffListProvider(tenantId));
  
  return staffAsync.when(
    data: (staffList) async {
      final List<StaffMemberModel> dueStaff = [];
      final repo = ref.read(attendanceRepositoryProvider);

      for (final staff in staffList) {
        if (staff.salaryAmount <= 0) continue;

        final startDate = staff.lastSalaryPaidDate ?? staff.createdAt;
        final daysSinceLastPayment = DateTime.now().difference(startDate).inDays;

        // Fetch attendance history to count days worked
        final history = await ref.read(attendanceHistoryProvider((tenantId: tenantId, staffId: staff.id)).future);
        
        // Count unique days since startDate
        final uniqueDays = history
            .where((a) => a.checkIn.isAfter(startDate))
            .map((a) => a.checkIn.toString().substring(0, 10))
            .toSet()
            .length;

        bool isDue = false;
        if (staff.salaryCycleDays > 0) {
          // Time-based but also requires minimum days
          if (daysSinceLastPayment >= staff.salaryCycleDays && uniqueDays >= staff.requiredDaysForSalary) {
            isDue = true;
          }
        } else {
          // Purely shift-based
          if (uniqueDays >= staff.requiredDaysForSalary && staff.requiredDaysForSalary > 0) {
            isDue = true;
          }
        }

        if (isDue) {
          dueStaff.add(staff);
        }
      }
      return dueStaff;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});
