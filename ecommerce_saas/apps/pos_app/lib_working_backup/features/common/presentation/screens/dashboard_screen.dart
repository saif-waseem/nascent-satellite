import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
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
import '../../../sales/presentation/screens/online_orders_screen.dart';
import '../../../products/presentation/screens/category_management_screen.dart';
import '../../../suppliers/presentation/screens/purchase_history_screen.dart';
import '../../../staff/presentation/screens/attendance_screen.dart';
import '../../../products/presentation/screens/barcode_printing_screen.dart';
import '../../../sales/presentation/screens/return_exchange_screen.dart';
import '../../../staff/data/attendance_repository.dart';
import '../../../staff/data/shift_repository.dart';
import '../../../staff/presentation/widgets/shift_management_dialog.dart';
import '../../data/notification_repository.dart';
import 'notifications_screen.dart';
import '../../../../core/providers/sync_status_provider.dart';
import '../widgets/connectivity_status_bar.dart';
import 'package:intl/intl.dart' as intl;

class DashboardScreen extends HookConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final tenantAsync = ref.watch(tenantProvider);
    final staffAsync = ref.watch(staffListProvider(tenantId));
    final currentStaff = ref.watch(currentStaffProvider);
    final syncStatus = ref.watch(syncStatusProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 800;

        final mainContent = Column(
          children: [
            // Top Header
            _buildHeader(context, ref, tenantAsync, syncStatus, isMobile),
            
            // Content Scroll View
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AttendanceBanner(),
                    const SizedBox(height: 16),
                    if (currentStaff != null && (currentStaff.roleName.toLowerCase() == 'admin' || currentStaff.roleName.toLowerCase() == 'manager')) ...[
                      const _FinancialSummaryBanner(),
                      const SizedBox(height: 24),
                    ],
                    
                    if (currentStaff == null)
                      _buildStaffSelectionPrompt(context, ref, staffAsync)
                    else
                      _buildFeatureGrid(context, ref, tenantId, isMobile),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            
            const ConnectivityStatusBar(),
          ],
        );

        if (isMobile) {
          return Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            drawer: Drawer(
              child: _buildSidebar(context, ref, tenantId, tenantAsync, currentStaff, staffAsync, isMobile),
            ),
            body: SafeArea(child: mainContent),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: SafeArea(
            child: Row(
              children: [
                // Left Sidebar (Navigation & Info)
                _buildSidebar(context, ref, tenantId, tenantAsync, currentStaff, staffAsync, isMobile),
                
                // Main Content Area
                Expanded(child: mainContent),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, WidgetRef ref, String tenantId, AsyncValue<TenantModel?> tenantAsync, StaffMemberModel? currentStaff, AsyncValue<List<StaffMemberModel>> staffAsync, bool isMobile) {
    return Container(
      width: isMobile ? double.infinity : 280,
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // Store Info
          tenantAsync.when(
            data: (tenant) => Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.blue.shade100,
                  child: tenant?.logoUrl != null 
                    ? ClipOval(child: Image.network(tenant!.logoUrl!, width: 80, height: 80, fit: BoxFit.cover))
                    : const Icon(Icons.store, size: 40, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 16),
                Text(
                  tenant?.name ?? 'متجر غير معروف',
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'ID: $tenantId',
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
                ),
              ],
            ),
            loading: () => const CircularProgressIndicator(),
            error: (_, __) => const Icon(Icons.error, color: Colors.red),
          ),
          
          const SizedBox(height: 32),
          const Divider(color: Colors.blueGrey, indent: 24, endIndent: 24),
          const SizedBox(height: 16),
          
          // Staff Selector (Sidebar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الموظف الحالي', style: TextStyle(color: Colors.blueGrey, fontSize: 11)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: staffAsync.when(
                    data: (list) => DropdownButton<StaffMemberModel>(
                      value: currentStaff,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF334155),
                      hint: const Text('اختر الموظف', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      underline: const SizedBox(),
                      items: list.map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                      )).toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          if (currentStaff != null) {
                            final activeShift = await ref.read(shiftRepositoryProvider).getActiveShift(tenantId, currentStaff.id);
                            if (activeShift != null) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إغلاق شفت الموظف الحالي أولاً.')));
                              return;
                            }
                          }
                          final success = await _showPinDialog(context, val);
                          if (success) {
                            ref.read(currentStaffProvider.notifier).set(val);
                          }
                        }
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const Text('خطأ في التحميل', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Bottom Actions
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.blueGrey),
            title: const Text('الإعدادات', style: TextStyle(color: Colors.white70)),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('تبديل المتجر', style: TextStyle(color: Colors.redAccent)),
            onTap: () => ref.read(tenantIdProvider.notifier).clearTenantId(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, AsyncValue<TenantModel?> tenantAsync, SyncStatus syncStatus, bool isMobile) {
    final now = DateTime.now();
    final timeStr = intl.DateFormat('hh:mm a').format(now);
    final dateStr = intl.DateFormat('yyyy/MM/dd').format(now);

    return Container(
      height: 80,
      padding: EdgeInsets.fromLTRB(isMobile ? 8 : 24, 0, isMobile ? 8 : 24, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, color: Color(0xFF1E293B), size: 28),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          if (isMobile) const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(timeStr, style: TextStyle(fontSize: isMobile ? 16 : 16, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B))),
              Text(dateStr, style: TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.blueGrey)),
            ],
          ),
          const Spacer(),
          if (!isMobile) ...[
            _SyncStatusBadge(syncStatus: syncStatus),
            const SizedBox(width: 16),
          ],
          _NotificationBell(),
        ],
      ),
    );
  }

  Widget _buildStaffSelectionPrompt(BuildContext context, WidgetRef ref, AsyncValue<List<StaffMemberModel>> staffAsync) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
            const Text(
              'أهلاً بك في نظام المبيعات',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'يرجى تسجيل الدخول باختيار اسمك من القائمة للبدء بالعمل',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blueGrey, fontSize: 16),
            ),
            const SizedBox(height: 32),
            staffAsync.when(
              data: (list) => Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: list.map((s) => InkWell(
                  onTap: () async {
                    final success = await _showPinDialog(context, s);
                    if (success) {
                      ref.read(currentStaffProvider.notifier).set(s);
                    }
                  },
                  child: Container(
                    width: 140,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.person, color: Colors.blue, size: 32),
                        const SizedBox(height: 8),
                        Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                        Text(s.roleName, style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
                      ],
                    ),
                  ),
                )).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const Text('فشل تحميل قائمة الموظفين'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureGrid(BuildContext context, WidgetRef ref, String tenantId, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الأقسام الرئيسية',
          style: TextStyle(fontSize: isMobile ? 18 : 20, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
        ),
        SizedBox(height: isMobile ? 16 : 24),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: isMobile ? 12 : 20,
          mainAxisSpacing: isMobile ? 12 : 20,
          childAspectRatio: isMobile ? 0.9 : 1.1,
          children: [
            _DashboardCard(
              title: 'قاعدة العملاء',
              subtitle: 'إدارة الزبائن ونقاط الولاء',
              icon: Icons.people_alt_rounded,
              color: Colors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen())),
            ),
            if (ref.hasPermission(PosPermission.manageSales))
              _DashboardCard(
                title: 'نقطة البيع (POS)',
                subtitle: 'إتمام عمليات البيع والفواتير',
                icon: Icons.point_of_sale_rounded,
                color: Colors.indigo,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesManagementScreen())),
              ),
            if (ref.hasPermission(PosPermission.viewProductStock))
              Consumer(
                builder: (context, ref, child) {
                  final lowStockAsync = ref.watch(lowStockProductsProvider);
                  final expiringAsync = ref.watch(nearExpiryProductsProvider);
                  final lowCount = lowStockAsync.value?.length ?? 0;
                  final expireCount = expiringAsync.value?.length ?? 0;
                  
                  return _DashboardCard(
                    title: 'إدارة المخزون',
                    subtitle: expireCount > 0 ? 'تنبيه: $expireCount منتج قريب الاكسباير' : 'تتبع المنتجات والكميات',
                    icon: Icons.inventory_2_rounded,
                    color: Colors.teal,
                    badgeCount: (lowCount + expireCount) > 0 ? (lowCount + expireCount) : null,
                    badgeColor: expireCount > 0 ? Colors.orange : Colors.red,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryManagementScreen())),
                  );
                },
              ),
            if (ref.hasPermission(PosPermission.viewReports))
              _DashboardCard(
                title: 'التقارير المالية',
                subtitle: 'ملخص المبيعات والأرباح',
                icon: Icons.analytics_rounded,
                color: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen())),
              ),
            if (ref.hasPermission(PosPermission.manageOnlineOrders))
              _DashboardCard(
                title: 'طلبات الأونلاين',
                subtitle: 'إدارة طلبات المتجر الإلكتروني',
                icon: Icons.shopping_bag_rounded,
                color: Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnlineOrdersScreen())),
              ),
            if (ref.hasPermission(PosPermission.viewDebts))
              _DashboardCard(
                title: 'الديون والحسابات',
                subtitle: 'ديون الزبائن والموردين',
                icon: Icons.account_balance_wallet_rounded,
                color: Colors.red,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtManagementScreen())),
              ),
            if (ref.hasPermission(PosPermission.viewExpenses))
              _DashboardCard(
                title: 'المصاريف العامة',
                subtitle: 'تسجيل المصاريف اليومية',
                icon: Icons.money_off_rounded,
                color: Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseListScreen())),
              ),
            if (ref.hasPermission(PosPermission.viewSuppliers))
              _DashboardCard(
                title: 'الموردين',
                subtitle: 'بيانات الموردين والمشتريات',
                icon: Icons.local_shipping_rounded,
                color: Colors.cyan,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupplierListScreen())),
              ),
            if (ref.hasPermission(PosPermission.viewSuppliers))
              _DashboardCard(
                title: 'إضافة مشتريات',
                subtitle: 'تسجيل فاتورة شراء جديدة',
                icon: Icons.add_shopping_cart_rounded,
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseInvoiceScreen())),
              ),
            _DashboardCard(
              title: 'حضور الموظفين',
              subtitle: 'سجل الحضور والانصراف',
              icon: Icons.fingerprint_rounded,
              color: Colors.deepPurple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
            ),
            _DashboardCard(
              title: 'الراجع و الاستبدال',
              subtitle: 'إدارة مرتجعات المبيعات',
              icon: Icons.replay_rounded,
              color: Colors.deepOrange,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReturnExchangeScreen())),
            ),
            _DashboardCard(
              title: 'طباعة الباركود',
              subtitle: 'توليد ملصقات الأسعار',
              icon: Icons.qr_code_scanner_rounded,
              color: Colors.blueGrey,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BarcodePrintingScreen())),
            ),
            _DashboardCard(
              title: 'إدارة الشفتات',
              subtitle: 'فتح وإغلاق وردية العمل',
              icon: Icons.lock_clock_rounded,
              color: Colors.blueGrey,
              onTap: () => showDialog(context: context, builder: (_) => const ShiftManagementDialog()),
            ),
            if (ref.hasPermission(PosPermission.manageProducts))
              _DashboardCard(
                title: 'إدارة المنتجات',
                subtitle: 'إضافة وتعديل الأصناف',
                icon: Icons.edit_note_rounded,
                color: Colors.blueAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductListScreen())),
              ),
            if (ref.hasPermission(PosPermission.viewReports))
              _DashboardCard(
                title: 'سجل المشتريات',
                subtitle: 'عرض فواتير المشتريات السابقة',
                icon: Icons.history_rounded,
                color: Colors.brown,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PurchaseHistoryScreen())),
              ),
            if (ref.hasPermission(PosPermission.manageProducts))
              _DashboardCard(
                title: 'الأصناف والتصنيفات',
                subtitle: 'إدارة أقسام المتجر',
                icon: Icons.grid_view_rounded,
                color: Colors.indigoAccent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryManagementScreen())),
              ),
          ],
        ),
      ],
    );
  }

  Future<bool> _showPinDialog(BuildContext context, StaffMemberModel staff) async {
    // If staff has no PIN, allow access (or you could require one to be set)
    if (staff.pinCode == null || staff.pinCode!.isEmpty) return true;

    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('تأكيد الهوية: ${staff.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('يرجى إدخال رمز التحقق (PIN) الخاص بك للاستمرار'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'رمز PIN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              onSubmitted: (val) {
                if (val == staff.pinCode) {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('رمز PIN غير صحيح')),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text == staff.pinCode) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('رمز PIN غير صحيح')),
                );
              }
            },
            child: const Text('دخول'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;
  final Color? badgeColor;

  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 16),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.blueGrey, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (badgeCount != null)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.red,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: (badgeColor ?? Colors.red).withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SyncStatusBadge extends StatelessWidget {
  final SyncStatus syncStatus;
  const _SyncStatusBadge({required this.syncStatus});

  @override
  Widget build(BuildContext context) {
    final isSynced = syncStatus.syncState == SyncState.synced;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isSynced ? Colors.green : Colors.orange).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isSynced ? Icons.check_circle : Icons.sync, color: isSynced ? Colors.green : Colors.orange, size: 16),
          const SizedBox(width: 8),
          Text(
            isSynced ? 'متزامن' : 'جاري المزامنة',
            style: TextStyle(color: isSynced ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final notificationsAsync = ref.watch(notificationsFutureProvider(tenantId));
    
    final hasUnread = notificationsAsync.when(
      data: (list) => list.any((n) => !n.isRead),
      loading: () => false,
      error: (_, __) => false,
    );

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
        ),
        if (hasUnread)
          Positioned(
            right: 12,
            top: 12,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            ),
          ),
      ],
    );
  }
}

class _AttendanceBanner extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final currentStaff = ref.watch(currentStaffProvider);
    
    if (currentStaff == null) return const SizedBox();

    final activeAttendance = ref.watch(activeAttendanceProvider((tenantId: tenantId, staffId: currentStaff.id)));

    return activeAttendance.when(
      data: (attendance) {
        if (attendance != null) return const SizedBox();
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.amber),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'تنبيه: لم يتم تسجيل الحضور لهذا اليوم. يرجى تسجيل الحضور قبل البدء بالعمل.',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                child: const Text('تسجيل الحضور الآن'),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(),
      error: (_, __) => const SizedBox(),
    );
  }
}

class _FinancialSummaryBanner extends ConsumerWidget {
  const _FinancialSummaryBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valuationAsync = ref.watch(inventoryValuationProvider);
    final profitAsync = ref.watch(totalProfitPotentialProvider);
    final fmt = intl.NumberFormat.currency(symbol: 'IQD', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade800, Colors.blue.shade600]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('قيمة البضاعة الكلية', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                valuationAsync.when(
                  data: (val) => Text(fmt.format(val), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  error: (_, __) => const Text('Error', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 40, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الربح المتوقع للمخزون', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                profitAsync.when(
                  data: (val) => Text(fmt.format(val), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  loading: () => const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  error: (_, __) => const Text('Error', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
