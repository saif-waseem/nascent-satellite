import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/dashboard_stats_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Stats',
            onPressed: () => ref.invalidate(dashboardStatsProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.go('/'),
          ),
        ],
      ),
      body: stats.totalTenants == 0 
        ? const Center(child: Text('No tenants found yet.'))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatOverview(context, stats),
                const SizedBox(height: 24),
                _buildTenantStatusChart(context, stats),
                const SizedBox(height: 24),
                _buildSubscriberDistributionChart(context, stats),
              ],
            ),
          ),
    );
  }

  Widget _buildStatOverview(BuildContext context, DashboardStats stats) {
    return Row(
      children: [
        Expanded(child: _buildSmallStat(context, 'Total Stores', stats.totalTenants.toString(), Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildSmallStat(context, 'Total Users', stats.totalSubscribers.toString(), Colors.green)),
      ],
    );
  }

  Widget _buildSmallStat(BuildContext context, String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTenantStatusChart(BuildContext context, DashboardStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Subscription Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: [
                    PieChartSectionData(
                      value: stats.activeTenants.toDouble(),
                      title: 'Active\n${stats.activeTenants}',
                      color: Colors.green,
                      radius: 60,
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    PieChartSectionData(
                      value: stats.expiredTenants.toDouble(),
                      title: 'Expired\n${stats.expiredTenants}',
                      color: Colors.red,
                      radius: 50,
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriberDistributionChart(BuildContext context, DashboardStats stats) {
    final sortedData = stats.subscribersPerTenant.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final top5 = sortedData.take(5).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('Top Stores by Customers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (top5.map((e) => e.value).fold(0, (p, c) => c > p ? c : p) * 1.2).toDouble(),
                  barGroups: List.generate(top5.length, (index) {
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: top5[index].value.toDouble(),
                          color: Theme.of(context).colorScheme.primary,
                          width: 25,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    );
                  }),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= top5.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              top5[value.toInt()].key.split(' ').first,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
