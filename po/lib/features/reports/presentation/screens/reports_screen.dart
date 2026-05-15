import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/report_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/providers/permissions_provider.dart';
import '../../../settings/data/staff_repository.dart';
import '../../data/audit_repository.dart';
import '../../../staff/data/shift_repository.dart';
import '../widgets/financial_charts.dart';
import 'treasury_dashboard_screen.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/utils/printing_service.dart';

enum ReportPeriod { today, thisMonth, custom }

class ReportsScreen extends HookConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final currentStaff = ref.watch(currentStaffProvider);
    final canViewShifts = ref.hasPermission(PosPermission.viewShifts);
    final canViewAudit = ref.hasPermission(PosPermission.viewAuditLogs);
    final isAdmin = currentStaff?.roleName.toLowerCase() == 'admin' ||
        currentStaff?.roleName.toLowerCase() == 'manager';

    final period = useState<ReportPeriod>(ReportPeriod.thisMonth);
    final now = DateTime.now();
    // Normalize to start and end of day for stable provider keys and caching
    final startDate = useState<DateTime>(DateTime(now.year, now.month, 1, 0, 0, 0));
    final endDate = useState<DateTime>(DateTime(now.year, now.month, now.day, 23, 59, 59));
    final selectedStaffId = useState<String?>( null); // null = all staff

    // Section visibility toggles
    final showSales = useState(true);
    final showStaff = useState(true);
    final showCategory = useState(true);
    final showOnline = useState(true);
    final showProducts = useState(true);

    void updatePeriod(ReportPeriod p) {
      period.value = p;
      final today = DateTime(now.year, now.month, now.day);
      if (p == ReportPeriod.today) {
        startDate.value = today;
        endDate.value = today.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      } else if (p == ReportPeriod.thisMonth) {
        startDate.value = DateTime(now.year, now.month, 1);
        endDate.value = today.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      }
    }

    final params = ReportParams(
      tenantId: tenantId,
      start: startDate.value,
      end: endDate.value,
      filterByStaffId: selectedStaffId.value,
    );
    final reportAsync = ref.watch(financialReportProvider(params));

    // Load all staff list for the dropdown
    final staffAsync = ref.watch(staffListProvider(tenantId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات'),
        actions: [
          reportAsync.when(
            data: (report) => IconButton(
              icon: const Icon(Icons.print),
              onPressed: () {
                final staff = selectedStaffId.value != null 
                  ? staffAsync.asData?.value.firstWhere((s) => s.id == selectedStaffId.value).name 
                  : null;
                ref.read(printingServiceProvider).printFinancialReport(
                  report: report,
                  start: startDate.value,
                  end: endDate.value,
                  staffName: staff,
                );
              },
              tooltip: 'طباعة التقرير الحالي',
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          if (canViewAudit)
            IconButton(
              icon: const Icon(Icons.history_edu),
              onPressed: () => _showAuditLogs(context, ref),
              tooltip: 'سجل العمليات (Audit Logs)',
            ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showSectionToggles(context, showSales, showStaff, showCategory, showOnline, showProducts),
            tooltip: 'تخصيص الأقسام',
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: Colors.blue),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TreasuryDashboardScreen())),
            tooltip: 'الصندوق (Treasury)',
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Period Selector ---
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<ReportPeriod>(
                  segments: const [
                    ButtonSegment(value: ReportPeriod.today, label: Text('اليوم'), icon: Icon(Icons.today, size: 16)),
                    ButtonSegment(value: ReportPeriod.thisMonth, label: Text('الشهر'), icon: Icon(Icons.calendar_month, size: 16)),
                    ButtonSegment(value: ReportPeriod.custom, label: Text('مخصص'), icon: Icon(Icons.date_range, size: 16)),
                  ],
                  selected: {period.value},
                  onSelectionChanged: (s) => updatePeriod(s.first),
                ),
                if (period.value == ReportPeriod.custom) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: Text('من: ${DateFormat('dd/MM').format(startDate.value)}'),
                          onPressed: () async {
                            final d = await showDatePicker(context: context, initialDate: startDate.value, firstDate: DateTime(2020), lastDate: endDate.value);
                            if (d != null) startDate.value = DateTime(d.year, d.month, d.day, 0, 0, 0);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today, size: 14),
                          label: Text('إلى: ${DateFormat('dd/MM').format(endDate.value)}'),
                          onPressed: () async {
                            final d = await showDatePicker(context: context, initialDate: endDate.value, firstDate: startDate.value, lastDate: DateTime.now());
                            if (d != null) endDate.value = DateTime(d.year, d.month, d.day, 23, 59, 59);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                // --- Staff Filter Dropdown ---
                const SizedBox(height: 8),
                staffAsync.when(
                  data: (staffList) {
                    final items = [
                      const DropdownMenuItem<String?>(value: null, child: Text('جميع الموظفين', style: TextStyle(color: Colors.grey))),
                      ...staffList.map((s) => DropdownMenuItem<String?>(value: s.id, child: Text(s.name))),
                    ];
                    return DropdownButtonFormField<String?>(
                      value: selectedStaffId.value,
                      items: items,
                      onChanged: (v) => selectedStaffId.value = v,
                      decoration: InputDecoration(
                        labelText: 'تصفية حسب الموظف',
                        prefixIcon: const Icon(Icons.person_search, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                    );
                  },
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          Expanded(
            child: reportAsync.when(
              data: (report) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(financialReportProvider(params)),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;
                    final horizontalPadding = isMobile ? 16.0 : (constraints.maxWidth - 1000).clamp(16.0, 500.0);
                    
                    return SingleChildScrollView(
                      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showSales.value) ...[
                            _buildTreasuryQuickAccess(context, report),
                            const SizedBox(height: 16),
                            _buildSummaryGrid(report, isAdmin),
                            const SizedBox(height: 24),
                            if (isAdmin) ...[
                              FinancialCharts(report: report),
                              const SizedBox(height: 32),
                            ],
                          ],

                          // --- Online Store Section ---
                          if (showOnline.value && report.onlineSales > 0) ...[
                            _buildSectionHeader('أرباح المتجر الإلكتروني', Icons.store, Colors.purple),
                            const SizedBox(height: 8),
                            _buildOnlineStoreCard(report),
                            const SizedBox(height: 24),
                          ],

                          // --- Staff Performance Section ---
                          if (showStaff.value && report.salesByStaff.isNotEmpty) ...[
                            _buildSectionHeader('أداء الموظفين', Icons.people, Colors.blueGrey),
                            const SizedBox(height: 12),
                            ..._buildStaffList(report),
                            const SizedBox(height: 24),
                          ],

                          // --- Category Sales Section ---
                          if (showCategory.value && report.salesByCategory.isNotEmpty) ...[
                            _buildSectionHeader('المبيعات حسب التصنيف', Icons.category, Colors.blueGrey),
                            const SizedBox(height: 12),
                            ..._buildCategoryList(report, isAdmin),
                            const SizedBox(height: 24),
                          ],

                          // --- Product Performance Section ---
                          if (showProducts.value && report.salesByProduct.isNotEmpty) ...[
                            _buildSectionHeader('أداء المنتجات', Icons.inventory_2_outlined, Colors.teal),
                            ..._buildProductList(report, isAdmin),
                            const SizedBox(height: 24),
                          ],

                          const SizedBox(height: 32),
                          if (showSales.value) ...[
                            _buildDetailTile('إجمالي المبيعات', report.totalSales, Icons.trending_up, Colors.green),
                            if (isAdmin) ...[
                              _buildDetailTile('إجمالي المشتريات', report.totalPurchases, Icons.shopping_cart, Colors.orange),
                              _buildDetailTile('إجمالي المصاريف', report.totalExpenses, Icons.money_off, Colors.red),
                              const Divider(height: 32),
                              _buildDetailTile('صافي الربح', report.netProfit, Icons.account_balance_wallet, report.netProfit >= 0 ? Colors.teal : Colors.red, isBold: true),
                            ],
                          ],
                          const SizedBox(height: 100),
                        ],
                      ),
                    );
                  },
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: canViewShifts ? FloatingActionButton.extended(
        onPressed: () => _showShiftHistory(context, ref),
        icon: const Icon(Icons.list_alt),
        label: const Text('تاريخ الشفتات'),
      ) : null,
    );
  }

  void _showAuditLogs(BuildContext context, WidgetRef ref) {
    if (!ref.read(permissionsProvider).contains(PosPermission.viewAuditLogs)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ليس لديك صلاحية لرؤية سجل العمليات')));
      return;
    }

    final tenantId = ref.read(tenantIdProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('سجل العمليات الإداري (Audit Logs)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) => ref.watch(auditLogsFutureProvider(tenantId)).when(
                  data: (logs) => ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (ctx, i) {
                      final log = logs[i];
                      return ListTile(
                        leading: Icon(
                          log.action == 'delete_item' ? Icons.delete_forever : Icons.local_offer,
                          color: log.action == 'delete_item' ? Colors.red : Colors.orange,
                        ),
                        title: Text(log.description),
                        subtitle: Text('${log.staffName} • ${DateFormat('HH:mm dd/MM').format(log.timestamp)}'),
                        trailing: log.metadata.containsKey('amount') ? Text('${log.metadata['amount']} IQD') : null,
                      );
                    },
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShiftHistory(BuildContext context, WidgetRef ref) {
     final tenantId = ref.read(tenantIdProvider);
     showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('تاريخ الشفتات والمطابقة الممالية', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: Consumer(
                builder: (context, ref, _) => ref.watch(shiftHistoryFutureProvider(tenantId)).when(
                  data: (shifts) => ListView.builder(
                    itemCount: shifts.length,
                    itemBuilder: (ctx, i) {
                      final s = shifts[i];
                      final diff = (s.closingBalanceActual ?? 0) - (s.closingBalanceExpected ?? 0);
                      final isClosed = s.status == 'closed';
                      
                      return Card(
                        child: ListTile(
                          onTap: () => _showShiftDetailDialog(context, s),
                          title: Text('موظف: ${s.staffName}'),
                          subtitle: Text('بدأت: ${DateFormat('dd/MM HH:mm').format(s.startTime)}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (isClosed) ...[
                                Text('الفارق: ${diff.toStringAsFixed(0)} IQD', 
                                  style: TextStyle(color: diff == 0 ? Colors.green : (diff > 0 ? Colors.blue : Colors.red), fontWeight: FontWeight.bold)),
                                Text('الدرج: ${s.closingBalanceActual} IQD', style: const TextStyle(fontSize: 10)),
                              ] else
                                const Text('نشطة الآن', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  error: (e, _) => Text('Error: $e'),
                  loading: () => const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showShiftDetailDialog(BuildContext context, ShiftSessionModel s) {
    final diff = (s.closingBalanceActual ?? 0) - (s.closingBalanceExpected ?? 0);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تفاصيل الشفت: ${s.staffName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تاريخ البدء: ${DateFormat('dd/MM HH:mm').format(s.startTime)}'),
              if (s.endTime != null) Text('تاريخ الانتهاء: ${DateFormat('dd/MM HH:mm').format(s.endTime!)}'),
              const Divider(),
              _detailRow('الرصيد الافتتاحي:', '${s.openingBalance} IQD'),
              _detailRow('المتوقع في الصندوق:', '${s.closingBalanceExpected ?? 0} IQD'),
              _detailRow('الفعلي في الصندوق:', '${s.closingBalanceActual ?? 0} IQD'),
              const Divider(),
              _detailRow('الفارق:', '$diff IQD', color: diff == 0 ? Colors.green : Colors.red, isBold: true),
              if (s.salesSummary.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('ملخص المبيعات:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...s.salesSummary.entries.map((e) {
                   String label = e.key;
                   String suffix = 'IQD';
                   if (e.key == 'sales_count' || e.key == 'total_sales_count') {
                      label = 'عدد المبيعات';
                      suffix = 'فواتير';
                   } else if (e.key == 'cash_sales') {
                      label = 'المبيعات النقدية';
                   } else if (e.key == 'card_sales') {
                      label = 'مبيعات الشبكة';
                   } else if (e.key == 'total_revenue') {
                      label = 'إجمالي المبيعات (صافي)';
                   } else if (e.key == 'returns_count') {
                      label = 'عدد المرتجعات';
                      suffix = 'عمليات';
                   }
                   return _detailRow('$label:', '${e.value.toStringAsFixed(0)} $suffix');
                }),
              ],
            ],
          ),
        ),
        actions: [
          Consumer(builder: (context, ref, _) => TextButton.icon(
            icon: const Icon(Icons.print),
            label: const Text('طباعة'),
            onPressed: () {
              ref.read(printingServiceProvider).printShiftReport(
                shift: s,
                actualCash: s.closingBalanceActual ?? 0,
                expectedCash: s.closingBalanceExpected ?? 0,
              );
            },
          )),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, 
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(value, 
            style: TextStyle(
              color: color, 
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildOnlineStoreCard(BusinessReport report) {
    final fmt = NumberFormat.currency(symbol: 'IQD', decimalDigits: 0);
    final onlinePercent = report.totalSales > 0 ? (report.onlineSales / report.totalSales * 100).toStringAsFixed(1) : '0';
    return Card(
      color: Colors.purple.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.purple.shade100)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('مبيعات المتجر الإلكتروني', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Chip(
                  label: Text('$onlinePercent% من الكل', style: const TextStyle(fontSize: 11, color: Colors.purple)),
                  backgroundColor: Colors.purple.shade100,
                  side: BorderSide.none,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(fmt.format(report.onlineSales), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: report.totalSales > 0 ? report.onlineSales / report.totalSales : 0,
              backgroundColor: Colors.purple.shade100,
              color: Colors.purple,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      ),
    );
  }

  void _showSectionToggles(
    BuildContext context,
    ValueNotifier<bool> showSales,
    ValueNotifier<bool> showStaff,
    ValueNotifier<bool> showCategory,
    ValueNotifier<bool> showOnline,
    ValueNotifier<bool> showProducts,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تخصيص الأقسام المعروضة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              SwitchListTile(title: const Text('ملخص المبيعات'), value: showSales.value, onChanged: (v) { setState(() => showSales.value = v); }),
              SwitchListTile(title: const Text('المتجر الإلكتروني'), value: showOnline.value, onChanged: (v) { setState(() => showOnline.value = v); }),
              SwitchListTile(title: const Text('أداء الموظفين'), value: showStaff.value, onChanged: (v) { setState(() => showStaff.value = v); }),
              SwitchListTile(title: const Text('التصنيفات'), value: showCategory.value, onChanged: (v) { setState(() => showCategory.value = v); }),
              SwitchListTile(title: const Text('أداء المنتجات'), value: showProducts.value, onChanged: (v) { setState(() => showProducts.value = v); }),
              const SizedBox(height: 16),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSummaryGrid(BusinessReport report, bool isAdmin) {
    final fmt = NumberFormat.compact();
    final items = [
      _StatItem('المبيعات', '${fmt.format(report.totalSales)}', Colors.green, Icons.point_of_sale),
      _StatItem('الفواتير', '${report.salesCount}', Colors.blue, Icons.receipt),
      if (isAdmin) ...[
        _StatItem('المصاريف', '${fmt.format(report.totalExpenses)}', Colors.red, Icons.money_off),
        _StatItem('الربح', '${fmt.format(report.netProfit)}', report.netProfit >= 0 ? Colors.teal : Colors.red, Icons.trending_up),
      ],
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 80,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _StatCard(item: items[index]),
    );
  }

  List<Widget> _buildStaffList(BusinessReport report) {
    final sorted = report.salesByStaff.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((entry) {
      final returns = report.returnsByStaff[entry.key] ?? 0;
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${entry.value.toStringAsFixed(0)} IQD', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
              if (returns > 0) ...[
                const SizedBox(height: 4),
                Text('الراجع: ${returns.toStringAsFixed(0)} IQD', style: const TextStyle(fontSize: 11, color: Colors.red)),
              ],
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: report.totalSales > 0 ? entry.value / (report.totalSales + returns) : 0,
                backgroundColor: Colors.grey.shade100,
                color: Colors.blue,
                minHeight: 4,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildCategoryList(BusinessReport report, bool isAdmin) {
    final sorted = report.salesByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((entry) {
      final profit = report.profitByCategory[entry.key] ?? 0;
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          title: Text(entry.key),
          subtitle: isAdmin ? Text('صافي الربح: ${profit.toStringAsFixed(0)} IQD', style: TextStyle(fontSize: 12, color: Colors.teal.shade700)) : null,
          trailing: Text('${entry.value.toStringAsFixed(0)} IQD', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    }).toList();
  }

  List<Widget> _buildProductList(BusinessReport report, bool isAdmin) {
    final sorted = report.salesByProduct.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxQty = sorted.isNotEmpty ? sorted.first.value.toDouble() : 1.0;
    final top5 = sorted.take(5).toList();
    final bottom5 = sorted.length > 5 ? sorted.reversed.take(5).toList() : <MapEntry<String,int>>[];

    return [
      const Text('⭐ الأكثر طلباً (Top 5)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.teal)),
      const SizedBox(height: 8),
      ...top5.map((entry) {
        final profit = report.profitByProduct[entry.key] ?? 0;
        return Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                    Chip(
                      label: Text('${entry.value} وحدة', style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.teal.shade50,
                      side: BorderSide.none, padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ],
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 4),
                  Text('صافي الربح: ${profit.toStringAsFixed(0)} IQD', style: TextStyle(fontSize: 12, color: Colors.teal.shade700)),
                ],
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: maxQty > 0 ? entry.value / maxQty : 0,
                  backgroundColor: Colors.teal.shade50,
                  color: Colors.teal,
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
          ),
        );
      }),
      if (bottom5.isNotEmpty) ...[
        const SizedBox(height: 12),
        const Text('⚠️ الأقل طلباً (Bottom 5)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange)),
        const SizedBox(height: 8),
        ...bottom5.map((entry) => Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            title: Text(entry.key, overflow: TextOverflow.ellipsis),
            subtitle: isAdmin ? Text('صافي الربح: ${(report.profitByProduct[entry.key] ?? 0).toStringAsFixed(0)} IQD', style: const TextStyle(fontSize: 11)) : null,
            trailing: Chip(
              label: Text('${entry.value} وحدة', style: const TextStyle(fontSize: 11)),
              backgroundColor: Colors.orange.shade50,
              side: BorderSide.none, padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        )),
      ],
    ];
  }

  Widget _buildDetailTile(String title, double amount, IconData icon, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          const Spacer(),
          Text('${amount.toStringAsFixed(0)} IQD', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: isBold ? 16 : 14)),
        ],
      ),
    );
  }

  Widget _buildTreasuryQuickAccess(BuildContext context, BusinessReport report) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TreasuryDashboardScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade600,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('الصندوق (Treasury)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text('انقر لمشاهدة تفاصيل الأرباح والمصاريف اليومية', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  _StatItem(this.title, this.value, this.color, this.icon);
}

class _StatCard extends StatelessWidget {
  final _StatItem item;
  const _StatCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: item.color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: item.color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(item.icon, size: 14, color: item.color),
              const SizedBox(width: 6),
              Expanded(child: Text(item.title, style: TextStyle(fontSize: 11, color: Colors.grey.shade700, overflow: TextOverflow.ellipsis))),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              item.value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: item.color),
            ),
          ),
        ],
      ),
    );
  }

}
