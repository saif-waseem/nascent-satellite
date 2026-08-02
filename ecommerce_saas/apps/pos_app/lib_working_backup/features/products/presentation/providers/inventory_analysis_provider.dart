import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../common/data/app_settings_repository.dart';
import '../../../reports/data/report_repository.dart';
import 'product_providers.dart';

class InventoryInsight {
  final ProductModel product;
  final int soldInPeriod;
  final double velocityRate; // sales per month
  final bool isSlowMoving;
  final bool isOverstocked;
  final int suggestedOrder;

  InventoryInsight({
    required this.product,
    required this.soldInPeriod,
    required this.velocityRate,
    this.isSlowMoving = false,
    this.isOverstocked = false,
    this.suggestedOrder = 0,
  });
}

final inventoryAnalysisProvider = FutureProvider<List<InventoryInsight>>((ref) async {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    await Future.delayed(const Duration(seconds: 5));
  }

  final tenantId = ref.watch(tenantIdProvider);
  final products = ref.watch(productsFutureProvider).value ?? [];
  final settings = ref.watch(appSettingsProvider).value ?? AppSettings();
  
  if (products.isEmpty) return [];

  // Calculate period for analysis
  final now = DateTime.now();
  final startDate = now.subtract(Duration(days: settings.inventoryDeadStockDays));
  
  final reportParams = ReportParams(
    tenantId: tenantId,
    start: startDate,
    end: now,
  );

  // Fetch sales report for the period
  final report = await ref.read(reportRepositoryProvider).getFinancialReport(
    tenantId, 
    start: startDate, 
    end: now
  );

  final insights = products.map((product) {
    final sold = report.salesByProduct[product.name] ?? 0;
    
    // Monthly velocity (approximate)
    final velocity = (sold / settings.inventoryDeadStockDays) * 30;
    
    // Logic for Slow Moving: 
    // High stock but very low sales over the defined period
    final isSlow = product.stockQuantity > 10 && sold <= 1;

    // Logic for Overstocked:
    // Have more than 3 months of supply based on recent velocity
    final isOver = velocity > 0 && product.stockQuantity > (velocity * 3);

    // Suggested Order:
    // If low stock, suggest up to 2 months of supply or minStockLevel
    final minLevel = product.minStockLevel ?? 5;
    int suggested = 0;
    if (product.stockQuantity <= minLevel) {
       suggested = ((velocity > 0 ? velocity * 2 : minLevel * 2) - product.stockQuantity).round();
       if (suggested < 0) suggested = 0;
    }

    return InventoryInsight(
      product: product,
      soldInPeriod: sold,
      velocityRate: velocity,
      isSlowMoving: isSlow,
      isOverstocked: isOver,
      suggestedOrder: suggested,
    );
  }).toList();

  return insights;
});
