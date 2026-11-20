import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/report_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../staff/data/shift_repository.dart';
import '../../../../core/providers/permissions_provider.dart';
import 'package:shared_models/shared_models.dart';

class TreasuryDashboardScreen extends HookConsumerWidget {
  const TreasuryDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final params = ReportParams(
      tenantId: tenantId,
      start: todayStart,
      end: todayEnd,
    );

    final reportAsync = ref.watch(financialReportProvider(params));
    final shiftsAsync = ref.watch(shiftHistoryFutureProvider(tenantId));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('إدارة الصندوق (Treasury)'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(financialReportProvider(params));
              ref.invalidate(shiftHistoryFutureProvider(tenantId));
            },
          ),
        ],
      ),
      body: reportAsync.when(
        data: (report) {
          // Calculate total opening balance for shifts that started today
          double totalOpeningToday = 0;
          if (shiftsAsync.hasValue) {
             for (var s in shiftsAsync.value!) {
                if (s.startTime.year == now.year && s.startTime.month == now.month && s.startTime.day == now.day) {
                   totalOpeningToday += s.openingBalance;
                }
             }
          }
          final estimatedCash = totalOpeningToday + report.totalSales - report.totalExpenses - report.totalPurchases;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final horizontalPadding = isMobile ? 16.0 : (constraints.maxWidth - 900).clamp(16.0, 500.0);

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMainTreasuryCard(context, report, estimatedCash),
                    const SizedBox(height: 24),
                    _buildSectionHeader('توزيع السيولة حسب الأقسام (الشفتات)', Icons.account_tree_outlined),
                    const SizedBox(height: 12),
                    _buildShiftsBreakdown(context, shiftsAsync),
                    const SizedBox(height: 24),
                    _buildSectionHeader('ملخص حركة الصندوق اليوم', Icons.history),
                    const SizedBox(height: 12),
                    _buildTransactionSummary(report),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildMainTreasuryCard(BuildContext context, BusinessReport report, double estimatedCash) {
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'صافي حركة الصندوق (اليوم)',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          FittedBox(
            child: Text(
              '${currencyFormat.format(estimatedCash)} IQD',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(spacing: 12,runSpacing: 8,
            alignment: WrapAlignment.spaceAround,
            children: [
              _buildSimpleStat('المبيعات', report.totalSales, Colors.green.shade300),
              _buildSimpleStat('المصاريف', report.totalExpenses, Colors.red.shade300),
              _buildSimpleStat('المشتريات', report.totalPurchases, Colors.orange.shade300),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(String label, double amount, Color color) {
    final fmt = NumberFormat.compact();
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          fmt.format(amount),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildShiftsBreakdown(BuildContext context, AsyncValue<List<ShiftSessionModel>> shiftsAsync) {
    return shiftsAsync.when(
      data: (shifts) {
        final activeShifts = shifts.where((s) => s.status == 'open').toList();
        if (activeShifts.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('لا توجد شفتات نشطة حالياً')),
            ),
          );
        }
        return Column(
          children: activeShifts.map((s) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: const Icon(Icons.person, color: Colors.blue),
              ),
              title: Text(s.staffName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('بدأ: ${DateFormat('HH:mm').format(s.startTime)}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('المتوقع بالدرج:', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(
                    '${(s.closingBalanceExpected ?? 0).toStringAsFixed(0)} IQD',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            ),
          )).toList(),
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error loading shifts: $e'),
    );
  }

  Widget _buildTransactionSummary(BusinessReport report) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          _buildSummaryRow('إجمالي الداخل (Sales)', report.totalSales, Colors.green),
          const Divider(height: 1),
          _buildSummaryRow('إجمالي الخارج (Expenses)', report.totalExpenses, Colors.red),
          const Divider(height: 1),
          _buildSummaryRow('إجمالي الخارج (Purchases)', report.totalPurchases, Colors.orange),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(child: Text('صافي الربح اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                Text(
                  '${report.netProfit.toStringAsFixed(0)} IQD',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: report.netProfit >= 0 ? Colors.teal : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(
            '${amount.toStringAsFixed(0)} IQD',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
        )),
      ],
    );
  }
}
