import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import '../../data/shift_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/providers/permissions_provider.dart';
import '../../data/attendance_repository.dart';
import '../../../reports/data/audit_repository.dart';
import '../../../sales/data/sales_repository.dart';
import '../../../../core/utils/printing_service.dart';

class ShiftManagementDialog extends HookConsumerWidget {
  const ShiftManagementDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final staff = ref.watch(currentStaffProvider);
    
    if (staff == null) {
      return const AlertDialog(
        title: Text('خطأ'),
        content: Text('يجب تسجيل الدخول كموظف أولاً.'),
      );
    }

    final activeShiftAsync = ref.watch(activeShiftFutureProvider((tenantId: tenantId, staffId: staff.id)));

    return activeShiftAsync.when(
      data: (shift) {
        return shift == null 
            ? _StartShiftDialog(tenantId: tenantId, staff: staff, onStarted: () {
                // Refresh the provider
                ref.invalidate(activeShiftFutureProvider((tenantId: tenantId, staffId: staff.id)));
              }) 
            : _CloseShiftDialog(shift: shift);
      },
      loading: () => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري التحقق من حالة الشفت...'),
          ],
        ),
      ),
      error: (e, _) => AlertDialog(
        title: const Text('خطأ'), 
        content: Text(e.toString()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}

class _StartShiftDialog extends HookConsumerWidget {
  final String tenantId;
  final StaffMemberModel staff;
  final VoidCallback onStarted;
  const _StartShiftDialog({required this.tenantId, required this.staff, required this.onStarted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountController = useTextEditingController(text: '0');

    return AlertDialog(
      title: const Text('بدء شفت جديد (Open Shift)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('يرجى إدخال المبلغ الافتتاحي في الصندوق:'),
          const SizedBox(height: 16),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'المبلغ الافتتاحي',
              border: OutlineInputBorder(),
              suffixText: 'IQD',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
            onPressed: () async {
              final openingBalance = double.tryParse(amountController.text) ?? 0.0;
              final shift = ShiftSessionModel(
                id: '',
                tenantId: tenantId,
                staffId: staff.id,
                staffName: staff.name,
                startTime: DateTime.now(),
                openingBalance: openingBalance,
                status: 'open',
              );
              await ref.read(shiftRepositoryProvider).startShift(shift);
              ref.invalidate(activeShiftFutureProvider((tenantId: tenantId, staffId: staff.id)));

              // Log the action
              ref.read(auditRepositoryProvider).log(
                tenantId: tenantId,
                staffId: staff.id,
                staffName: staff.name,
                action: 'start_shift',
                description: 'بدء شفت جديد للموظف: ${staff.name} بمبلغ افتتاحي: $openingBalance',
                metadata: {'openingBalance': openingBalance},
              );

              onStarted();
              if (context.mounted) Navigator.pop(context);
            },
          child: const Text('بدء الشفت'),
        ),
      ],
    );
  }
}

class _CloseShiftDialog extends HookConsumerWidget {
  final ShiftSessionModel shift;
  const _CloseShiftDialog({required this.shift});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountController = useTextEditingController();
    final isClosing = useState(false);
    final showSummary = useState(false);
    final calculatedExpected = useState(0.0);
    final salesSummaryData = useState<Map<String, double>>({});

    if (showSummary.value) {
      final actual = double.tryParse(amountController.text) ?? 0.0;
      final expected = calculatedExpected.value;
      final diff = actual - expected;
      
      Color diffColor = Colors.blue; // Surplus
      String diffText = 'زيادة: +${diff.toStringAsFixed(0)} IQD';
      if (diff == 0) {
        diffColor = Colors.green;
        diffText = 'مطابق (صحيح)';
      } else if (diff < 0) {
        diffColor = Colors.red;
        diffText = 'نقص: ${diff.toStringAsFixed(0)} IQD';
      }

      return AlertDialog(
        title: const Text('ملخص إغلاق الشفت (Manager View)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow('الدخل السابق (الافتتاحي):', '${shift.openingBalance.toStringAsFixed(0)} IQD'),
            _SummaryRow('إجمالي المبيعات:', '${(expected - shift.openingBalance).toStringAsFixed(0)} IQD'),
            const Divider(),
            _SummaryRow('المتوقع في الصندوق:', '${expected.toStringAsFixed(0)} IQD'),
            _SummaryRow('الفعلي في الصندوق:', '${actual.toStringAsFixed(0)} IQD'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(color: diffColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: diffColor)),
              child: Text(
                diffText,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: diffColor),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => showSummary.value = false, child: const Text('تعديل المبلغ')),
          TextButton.icon(
            onPressed: () {
              ref.read(printingServiceProvider).printShiftReport(
                shift: shift,
                actualCash: actual,
                expectedCash: expected,
              );
            },
            icon: const Icon(Icons.print),
            label: const Text('طباعة التقرير'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: isClosing.value ? null : () async {
              isClosing.value = true;
              await ref.read(shiftRepositoryProvider).closeShift(
                tenantId: shift.tenantId,
                shiftId: shift.id,
                actualCash: actual,
                expectedCash: expected, 
                salesSummary: salesSummaryData.value,
              );
              ref.invalidate(activeShiftFutureProvider((tenantId: shift.tenantId, staffId: shift.staffId)));
              ref.invalidate(shiftHistoryFutureProvider(shift.tenantId));

              // Auto Clock-out staff
              try {
                 final attendanceRepo = ref.read(attendanceRepositoryProvider);
                 final activeAtt = await attendanceRepo.getActiveAttendance(shift.tenantId, shift.staffId);
                 if (activeAtt != null) {
                    await attendanceRepo.checkOut(shift.tenantId, activeAtt.id, DateTime.now());
                 }
              } catch (e) {
                 debugPrint('Auto clock-out failed: $e');
              }

              // Log the action
              ref.read(auditRepositoryProvider).log(
                tenantId: shift.tenantId,
                staffId: shift.staffId,
                staffName: shift.staffName,
                action: 'close_shift',
                description: 'إغلاق شفت الموظف: ${shift.staffName} بمبلغ: $actual',
                metadata: {'shiftId': shift.id, 'actualCash': actual},
              );

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إغلاق الشفت بنجاح.')));
              }
            },
            child: const Text('تأكيد وإغلاق نهائي'),
          ),
        ],
      );
    }

    return AlertDialog(
      title: const Text('إغلاق الشفت (Blind Close)'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('يرجى إدخال المبلغ النقدي (الكاش) الموجود فعلياً في الصندوق الآن:'),
          const SizedBox(height: 8),
          const Text(
            '(ملاحظة: الموظف لا يرى المبالغ المسجلة في النظام لضمان الدقة)',
            style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'المبلغ الموجود في الدرج',
              border: OutlineInputBorder(),
              suffixText: 'IQD',
            ),
          ),
        ],
      ),
      actions: [
        if (!isClosing.value) ...[
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('رجوع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              final actual = double.tryParse(amountController.text);
              if (actual == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال مبلغ صحيح')));
                return;
              }

              // Calculate expected
              double expectedCash = shift.openingBalance;
              final salesRepo = ref.read(salesRepositoryProvider);
              final shiftSales = await salesRepo.getSalesByShift(shift.tenantId, shift.id);
              
              for (var sale in shiftSales) {
                 if (!sale.isReturned) {
                    expectedCash += sale.paidAmount;
                 } else {
                    expectedCash -= sale.paidAmount; 
                 }
              }
              
              calculatedExpected.value = expectedCash;
              salesSummaryData.value = {
                'sales_count': shiftSales.length.toDouble(),
                'total_revenue': expectedCash - shift.openingBalance,
              };

              // Check permission before showing summary
              final perms = ref.read(permissionsProvider);
              final hasReportPermission = perms.contains(PosPermission.viewReports);

              if (hasReportPermission) {
                showSummary.value = true;
              } else {
                // Regular staff: Just close directly (Blind Close)
                isClosing.value = true;
                await ref.read(shiftRepositoryProvider).closeShift(
                  tenantId: shift.tenantId,
                  shiftId: shift.id,
                  actualCash: actual,
                  expectedCash: expectedCash, 
                  salesSummary: salesSummaryData.value,
                );
                ref.invalidate(activeShiftFutureProvider((tenantId: shift.tenantId, staffId: shift.staffId)));
                ref.invalidate(shiftHistoryFutureProvider(shift.tenantId));
                
                // Auto Clock-out
                try {
                  final attendanceRepo = ref.read(attendanceRepositoryProvider);
                  final activeAtt = await attendanceRepo.getActiveAttendance(shift.tenantId, shift.staffId);
                  if (activeAtt != null) {
                    await attendanceRepo.checkOut(shift.tenantId, activeAtt.id, DateTime.now());
                  }
                } catch (e) {
                  debugPrint('Auto clock-out failed: $e');
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إغلاق الشفت بنجاح.')));
                }
              }
            },
            child: Text(ref.read(permissionsProvider).contains(PosPermission.viewReports) 
              ? 'عرض الملخص والمطابقة' 
              : 'تأكيد وإغلاق الشفت'),
          ),
        ] else
          const CircularProgressIndicator(),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
