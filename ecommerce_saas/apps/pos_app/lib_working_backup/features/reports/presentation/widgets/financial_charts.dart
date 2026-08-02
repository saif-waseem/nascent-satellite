import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../data/report_repository.dart';

class FinancialCharts extends StatelessWidget {
  final BusinessReport report;
  const FinancialCharts({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSectionHeader('اتجاه المبيعات (Sales Trend)', Icons.trending_up, Colors.green),
        const SizedBox(height: 12),
        HeightLimitedChart(child: _LineChartWidget(data: report.salesTrend, color: Colors.green)),
        
        const SizedBox(height: 32),
        _buildSectionHeader('صافي الأرباح (Net Profit)', Icons.account_balance_wallet, Colors.teal),
        const SizedBox(height: 12),
        HeightLimitedChart(child: _LineChartWidget(data: report.profitTrend, color: Colors.teal)),
        
        const SizedBox(height: 32),
        _buildSectionHeader('المقارنة (المبيعات vs الأرباح)', Icons.compare_arrows, Colors.blue),
        const SizedBox(height: 12),
        HeightLimitedChart(child: _ComparisonChartWidget(sales: report.salesTrend, profit: report.profitTrend)),
        
        const SizedBox(height: 32),
        _buildSectionHeader('توزيع المبيعات حسب الصنف', Icons.pie_chart, Colors.purple),
        const SizedBox(height: 12),
        _PieChartWidget(data: report.salesByCategory, titleSuffix: 'مبيعات'),

        const SizedBox(height: 32),
        _buildSectionHeader('توزيع الأرباح حسب الصنف', Icons.pie_chart_outline, Colors.teal),
        const SizedBox(height: 12),
        _PieChartWidget(data: report.profitByCategory, titleSuffix: 'أرباح'),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class HeightLimitedChart extends StatelessWidget {
  final Widget child;
  const HeightLimitedChart({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: child,
    );
  }
}

class _LineChartWidget extends StatelessWidget {
  final Map<String, double> data;
  final Color color;
  const _LineChartWidget({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const Center(child: Text('لا توجد بيانات كافية'));

    final sortedKeys = data.keys.toList()..sort();
    final spots = sortedKeys.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), data[e.value]!);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedKeys.length) return const SizedBox.shrink();
                // Show every Nth label or first/last to avoid overlap
                if (sortedKeys.length > 7 && index % (sortedKeys.length ~/ 4) != 0) return const SizedBox.shrink();
                final dateStr = sortedKeys[index];
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(dateStr.substring(5), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
          ),
        ],
      ),
    );
  }
}

class _ComparisonChartWidget extends StatelessWidget {
  final Map<String, double> sales;
  final Map<String, double> profit;
  const _ComparisonChartWidget({required this.sales, required this.profit});

  @override
  Widget build(BuildContext context) {
    final allKeys = {...sales.keys, ...profit.keys}.toList()..sort();
    if (allKeys.isEmpty) return const Center(child: Text('لا توجد بيانات كافية'));

    final salesSpots = allKeys.asMap().entries.map((e) => FlSpot(e.key.toDouble(), sales[e.value] ?? 0)).toList();
    final profitSpots = allKeys.asMap().entries.map((e) => FlSpot(e.key.toDouble(), profit[e.value] ?? 0)).toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= allKeys.length) return const SizedBox.shrink();
                if (allKeys.length > 7 && index % (allKeys.length ~/ 4) != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(allKeys[index].substring(5), style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(spots: salesSpots, isCurved: true, color: Colors.green, barWidth: 3),
          LineChartBarData(spots: profitSpots, isCurved: true, color: Colors.blue, barWidth: 3),
        ],
      ),
    );
  }
}

class _PieChartWidget extends StatelessWidget {
  final Map<String, double> data;
  final String titleSuffix;
  const _PieChartWidget({required this.data, this.titleSuffix = ''});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final colors = [
      Colors.blue, Colors.green, Colors.orange, Colors.purple, 
      Colors.teal, Colors.pink, Colors.amber, Colors.cyan
    ];

    int colorIdx = 0;
    final sections = data.entries.map((e) {
      final color = colors[colorIdx % colors.length];
      colorIdx++;
      return PieChartSectionData(
        value: e.value,
        title: '${e.key}\n${(e.value).toStringAsFixed(0)} $titleSuffix',
        radius: 60,
        titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
        color: color.withOpacity(0.7),
      );
    }).toList();

    return Container(
      height: 250,
      child: PieChart(
        PieChartData(
          sections: sections,
          centerSpaceRadius: 40,
          sectionsSpace: 2,
        ),
      ),
    );
  }
}
