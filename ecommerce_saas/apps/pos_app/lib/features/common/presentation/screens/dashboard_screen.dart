import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../../suppliers/presentation/screens/supplier_list_screen.dart';
import '../../../suppliers/presentation/screens/purchase_invoice_screen.dart';
import '../../../sales/presentation/screens/sales_management_screen.dart';
import '../../../products/presentation/screens/product_list_screen.dart';
import '../../../debts/presentation/screens/debt_management_screen.dart';
import '../../../expenses/presentation/screens/expense_list_screen.dart';
import '../../../customers/presentation/screens/customer_list_screen.dart';
import '../../../products/presentation/screens/inventory_management_screen.dart';
import '../../../../core/providers/permissions_provider.dart';
import '../../../settings/data/staff_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import 'settings_screen.dart';
import '../../../reports/presentation/screens/reports_screen.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../../products/presentation/screens/inventory_management_screen.dart' show InventoryFilter;
import '../../../sales/presentation/screens/online_orders_screen.dart';
import '../../../products/presentation/screens/category_management_screen.dart';
import '../../../suppliers/presentation/screens/purchase_history_screen.dart';
import '../../../staff/presentation/screens/attendance_screen.dart';
import '../../../staff/providers/salary_providers.dart';
import '../../../../core/services/media_sync_service.dart';
import '../../../sales/presentation/screens/return_exchange_screen.dart';
import '../../../staff/data/attendance_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final staffAsync = ref.watch(staffListProvider(tenantId));
    final currentStaff = ref.watch(currentStaffProvider);
    
    // Initialize Media Sync Service
    ref.watch(mediaSyncProvider);

    // Custom listener for new online orders
    ref.listen(onlineOrdersProvider(tenantId), (previous, next) {
      if (previous == null || previous.isLoading) return;
      final nextList = next.value ?? [];
      final previousList = previous.value ?? [];
      if (nextList.length > previousList.length) {
        final newOrder = nextList.first;
        if (newOrder.status == OrderStatus.active) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔔 يوجد طلب أونلاين جديد! رقم: #${newOrder.id.substring(0, 5).toUpperCase()}'),
              duration: const Duration(seconds: 5),
              backgroundColor: Colors.indigo,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('نظام المبيعات POS'),
        actions: [
          staffAsync.when(
            data: (list) => DropdownButton<String>(
              hint: const Text('اختر الموظف'),
              value: currentStaff?.id,
              items: list.map((s) => DropdownMenuItem(
                value: s.id,
                child: Text('${s.name} (${s.roleName})'),
              )).toList(),
              onChanged: (id) async {
                final staff = list.where((element) => element.id == id).firstOrNull;
                if (staff == null) return;
                if (staff.pinCode != null && staff.pinCode!.isNotEmpty) {
                  final verified = await _showPinDialog(context, staff.pinCode!);
                  if (!verified) return;
                }
                ref.read(currentStaffProvider.notifier).set(staff);
              },
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          if (currentStaff != null)
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              onPressed: () => ref.read(currentStaffProvider.notifier).set(null),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: _StandardDashboard(currentStaff: currentStaff, staffAsync: staffAsync),
    );
  }

  Future<bool> _showPinDialog(BuildContext context, String correctPin) async {
    final pinController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('أدخل كود PIN'),
        content: TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (pinController.text == correctPin) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كود PIN خاطئ')));
              }
            },
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _StandardDashboard extends ConsumerWidget {
  final StaffMemberModel? currentStaff;
  final AsyncValue<List<StaffMemberModel>> staffAsync;

  const _StandardDashboard({required this.currentStaff, required this.staffAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (currentStaff == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.touch_app_outlined, size: 64, color: Colors.blueGrey),
            const SizedBox(height: 24),
            const Text('يرجى اختيار موظف للبدء', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 5 : (constraints.maxWidth > 500 ? 4 : 3);
        return GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            if (ref.hasPermission(PosPermission.manageSales))
              _DashboardItem(
                title: 'نقطة البيع (POS)',
                icon: Icons.point_of_sale,
                color: Colors.purple,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesManagementScreen())),
              ),
            if (ref.hasPermission(PosPermission.viewProductStock))
              _DashboardItem(
                title: 'المنتجات',
                icon: Icons.inventory_2_outlined,
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen())),
              ),
            if (ref.hasPermission(PosPermission.viewSuppliers))
              _DashboardItem(
                title: 'الموردين',
                icon: Icons.people_outline,
                color: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierListScreen())),
              ),
            if (ref.hasPermission(PosPermission.viewDebts))
              _DashboardItem(
                title: 'إدارة الديون',
                icon: Icons.account_balance_wallet_outlined,
                color: Colors.red,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtManagementScreen())),
              ),
            if (ref.hasPermission(PosPermission.viewProductStock))
              _DashboardItem(
                title: 'إدارة المخزون',
                icon: Icons.inventory_outlined,
                color: Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryManagementScreen())),
              ),
            if (ref.hasPermission(PosPermission.viewSuppliers))
              _DashboardItem(
                title: 'المشتريات',
                icon: Icons.shopping_cart_checkout,
                color: Colors.brown,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseHistoryScreen())),
              ),
            if (ref.hasPermission(PosPermission.viewExpenses))
               _DashboardItem(
                title: 'المصاريف',
                icon: Icons.money_off_csred_outlined,
                color: Colors.redAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseListScreen())),
              ),
            if (ref.hasPermission(PosPermission.manageProducts))
               _DashboardItem(
                title: 'إدارة الأصناف',
                icon: Icons.category_outlined,
                color: Colors.indigo,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagementScreen())),
              ),
             _DashboardItem(
                title: 'المرتجعات',
                icon: Icons.assignment_return_outlined,
                color: Colors.deepOrange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnExchangeScreen())),
              ),
            if (ref.hasPermission(PosPermission.manageOnlineOrders))
               _DashboardItem(
                title: 'طلبات الأونلاين',
                icon: Icons.online_prediction_outlined,
                color: Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnlineOrdersScreen())),
              ),
            if (ref.hasPermission(PosPermission.manageProducts))
              _DashboardItem(
                title: 'الأرشيف',
                icon: Icons.archive_outlined,
                color: Colors.blueGrey,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen())),
              ),
             _DashboardItem(
              title: 'حضور الموظفين',
              icon: Icons.fingerprint,
              color: Colors.blueAccent,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
            ),
            if (ref.hasPermission(PosPermission.viewReports))
              _DashboardItem(
                title: 'التقارير',
                icon: Icons.analytics_outlined,
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
              ),
             _DashboardItem(
              title: 'الإعدادات',
              icon: Icons.settings_outlined,
              color: Colors.grey,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
            ),
          ],
        );
      },
    );
  }
}

class _DashboardItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardItem({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 2,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
