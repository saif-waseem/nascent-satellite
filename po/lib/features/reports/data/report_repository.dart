import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../../core/services/firestore_rest_service.dart';
import '../../../core/services/local_db_service.dart';

class BusinessReport {
  final double totalSales;
  final double totalExpenses;
  final double totalPurchases;
  final double grossProfit;
  final double netProfit;
  final int salesCount;
  final double onlineSales;
  final Map<String, double> salesByCategory;
  final Map<String, double> salesByStaff;
  final Map<String, double> returnsByStaff;
  final Map<String, int> salesByProduct;
  final Map<String, double> profitByProduct;
  final Map<String, double> profitByCategory;
  final Map<String, double> salesTrend;
  final Map<String, double> profitTrend;

  BusinessReport({
    required this.totalSales,
    required this.totalExpenses,
    required this.totalPurchases,
    required this.grossProfit,
    required this.netProfit,
    required this.salesCount,
    this.onlineSales = 0,
    this.salesByCategory = const {},
    this.salesByStaff = const {},
    this.returnsByStaff = const {},
    this.salesByProduct = const {},
    this.profitByProduct = const {},
    this.profitByCategory = const {},
    this.salesTrend = const {},
    this.profitTrend = const {},
  });
}

class ReportParams {
  final String tenantId;
  final DateTime start;
  final DateTime end;
  final String? filterByStaffId;

  const ReportParams({
    required this.tenantId,
    required this.start,
    required this.end,
    this.filterByStaffId,
  });

  @override
  bool operator ==(Object other) =>
      other is ReportParams &&
      other.tenantId == tenantId &&
      other.start == start &&
      other.end == end &&
      other.filterByStaffId == filterByStaffId;

  @override
  int get hashCode => Object.hash(tenantId, start, end, filterByStaffId);
}

class ReportRepository {
  final FirestoreRestService _restService;

  ReportRepository(this._restService);

  Future<BusinessReport> getFinancialReport(String tenantId,
      {DateTime? start, DateTime? end, String? filterByStaffId}) async {
    try {
      final now = DateTime.now();
      final startDate = start ?? DateTime(now.year, now.month, 1);
      final endDate = end != null
          ? DateTime(end.year, end.month, end.day, 23, 59, 59)
          : DateTime(now.year, now.month, now.day, 23, 59, 59);

      // --- 1. Load Data from Local Hive Boxes ---
      final salesBox = LocalDbService.getBox<SalesInvoiceModel>('sales');
      final expensesBox = LocalDbService.getBox<ExpenseModel>('expenses');
      final purchasesBox = LocalDbService.getBox<PurchaseInvoiceModel>('purchases');
      final productsBox = LocalDbService.getBox<ProductModel>('products');
      final categoriesBox = LocalDbService.getBox<CategoryModel>('categories');

      final salesList = salesBox.values.where((s) => s.tenantId == tenantId).toList();
      final expensesList = expensesBox.values.where((e) => e.tenantId == tenantId).toList();
      final purchasesList = purchasesBox.values.where((p) => p.tenantId == tenantId).toList();

      final categoryNames = {for (var c in categoriesBox.values) c.id: c.name};
      final productCosts = {for (var p in productsBox.values) p.id: p.purchasePrice};

      double totalSales = 0;
      double onlineSales = 0;
      int salesCount = 0;
      final Map<String, double> salesByCategory = {};
      final Map<String, double> profitByCategory = {};
      final Map<String, double> salesByStaff = {};
      final Map<String, double> returnsByStaff = {};
      final Map<String, int> salesByProduct = {};
      final Map<String, double> profitByProduct = {};
      final Map<String, double> salesTrend = {};
      final Map<String, double> profitTrend = {};
      double totalCOGS = 0;

      // Process Sales
      for (var invoice in salesList) {
        if (invoice.date.isBefore(startDate) || invoice.date.isAfter(endDate)) continue;

        final staffName = (invoice.addedBy?.isNotEmpty ?? false) ? invoice.addedBy! : 'موظف غير معروف';
        final staffId = invoice.addedById ?? '';

        if (filterByStaffId != null && filterByStaffId.isNotEmpty && staffId != filterByStaffId) continue;
        
        if (invoice.isReturned) {
          totalSales -= invoice.totalAmount;
          returnsByStaff[staffName] = (returnsByStaff[staffName] ?? 0) + invoice.totalAmount;
        } else {
          totalSales += invoice.totalAmount;
          salesCount++;
          
          final isOnline = invoice.sessionName?.toLowerCase() == 'online' || invoice.addedById?.startsWith('store_') == true;
          if (isOnline) onlineSales += invoice.totalAmount;
          
          salesByStaff[staffName] = (salesByStaff[staffName] ?? 0) + invoice.totalAmount;

          final dateKey = invoice.date.toString().substring(0, 10);
          salesTrend[dateKey] = (salesTrend[dateKey] ?? 0) + invoice.totalAmount;
          
          double invoiceProfit = 0;
          for (final item in invoice.items) {
            // Robust category name resolution: Check if item.category is an ID or already a name
            final cName = categoryNames[item.category];
            final categoryKey = (cName != null && cName.isNotEmpty) 
                ? cName 
                : ((item.category != null && item.category!.isNotEmpty) ? item.category! : 'غير مصنف');
            
            salesByCategory[categoryKey] = (salesByCategory[categoryKey] ?? 0) + item.totalPrice;
            salesByProduct[item.productName] = (salesByProduct[item.productName] ?? 0) + item.quantity.toInt();
            
            final double unitCost = productCosts[item.productId] ?? 0.0;
            final double itemProfit = item.totalPrice - (unitCost * item.quantity);
            totalCOGS += (unitCost * item.quantity);
            
            profitByProduct[item.productName] = (profitByProduct[item.productName] ?? 0) + itemProfit;
            profitByCategory[categoryKey] = (profitByCategory[categoryKey] ?? 0) + itemProfit;
            invoiceProfit += itemProfit;
          }
          profitTrend[dateKey] = (profitTrend[dateKey] ?? 0) + invoiceProfit;
        }
      }

      // Process Expenses
      double totalExpenses = 0;
      for (var expense in expensesList) {
        if (expense.date.isBefore(startDate) || expense.date.isAfter(endDate)) continue;
        totalExpenses += expense.amount;
        final date = expense.date.toString().substring(0, 10);
        profitTrend[date] = (profitTrend[date] ?? 0) - expense.amount;
      }

      // Process Purchases
      double totalPurchases = 0;
      for (var invoice in purchasesList) {
        if (invoice.date.isBefore(startDate) || invoice.date.isAfter(endDate)) continue;
        totalPurchases += invoice.totalAmount;
        final date = invoice.date.toString().substring(0, 10);
        profitTrend[date] = (profitTrend[date] ?? 0) - invoice.totalAmount;
      }

      // Background Sync from remote (optional, to keep local cache updated)
      _syncRemoteDataInBackground(tenantId);

      return BusinessReport(
        totalSales: totalSales,
        totalExpenses: totalExpenses,
        totalPurchases: totalPurchases,
        grossProfit: totalSales - totalCOGS,
        netProfit: totalSales - totalCOGS - totalExpenses,
        salesCount: salesCount,
        onlineSales: onlineSales,
        salesByCategory: salesByCategory,
        profitByCategory: profitByCategory,
        salesByStaff: salesByStaff,
        returnsByStaff: returnsByStaff,
        salesByProduct: salesByProduct,
        profitByProduct: profitByProduct,
        salesTrend: salesTrend,
        profitTrend: profitTrend,
      );
    } catch (e) {
      debugPrint('REPORT DATA ERROR: $e');
      throw 'فشل تحميل التقرير: $e';
    }
  }

  Future<void> _syncRemoteDataInBackground(String tenantId) async {
    // This could trigger a fetch from Firestore to update Hive boxes if online
    // For now, the existing repositories (SalesRepository, etc.) already handle background fetching
  }
}

final reportRepositoryProvider = Provider((ref) => ReportRepository(ref.watch(firestoreRestServiceProvider)));

final financialReportProvider = FutureProvider.family<BusinessReport, ReportParams>((ref, params) async {
  return ref.watch(reportRepositoryProvider).getFinancialReport(params.tenantId, start: params.start, end: params.end, filterByStaffId: params.filterByStaffId);
});
