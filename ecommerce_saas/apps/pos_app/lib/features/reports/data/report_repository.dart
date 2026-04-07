import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';

class BusinessReport {
  final double totalSales;
  final double totalExpenses;
  final double totalPurchases;
  final double grossProfit;
  final double netProfit;
  final int salesCount;
  final double onlineSales;           // revenue from online store orders
  final Map<String, double> salesByCategory;
  final Map<String, double> salesByStaff;
  final Map<String, double> returnsByStaff;
  final Map<String, int> salesByProduct;  // product name -> quantity sold

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
  });
}

class ReportParams {
  final String tenantId;
  final DateTime start;
  final DateTime end;
  final String? filterByStaffId;  // null = all staff

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
  final FirebaseFirestore _firestore;

  ReportRepository(this._firestore);

  Future<BusinessReport> getFinancialReport(String tenantId,
      {DateTime? start, DateTime? end, String? filterByStaffId}) async {
    try {
      final now = DateTime.now();
      final startDate = start ?? DateTime(now.year, now.month, 1);
      final endDate = end != null
          ? DateTime(end.year, end.month, end.day, 23, 59, 59)
          : DateTime(now.year, now.month, now.day, 23, 59, 59);

      final startIso = startDate.toIso8601String();
      final endIso = endDate.toIso8601String();

      // Fetch Sales
      final salesQuery = await _firestore
          .collection('sales_invoices')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      final filteredSales = salesQuery.docs.where((doc) {
        final date = doc.data()['date'] as String?;
        if (date == null) return false;
        return date.compareTo(startIso) >= 0 && date.compareTo(endIso) <= 0;
      });

      double totalSales = 0;
      double onlineSales = 0;
      int salesCount = 0;
      final Map<String, double> salesByCategory = {};
      final Map<String, double> salesByStaff = {};
      final Map<String, double> returnsByStaff = {};
      final Map<String, int> salesByProduct = {};

      // Fetch Categories for mapping IDs to Names
      final catsQuery = await _firestore.collection('categories').where('tenantId', isEqualTo: tenantId).get();
      final categoryNames = {for (var doc in catsQuery.docs) doc.id: doc.data()['name'] as String? ?? 'غير مصنف'};

      for (var doc in filteredSales) {
        final data = doc.data();
        final invoice = SalesInvoiceModel.fromJson(data..['id'] = doc.id);
        final staffName = (invoice.addedBy?.isNotEmpty ?? false) ? invoice.addedBy! : 'موظف غير معروف';
        final staffId = invoice.addedById ?? '';

        // Apply staff filter
        if (filterByStaffId != null && filterByStaffId.isNotEmpty && staffId != filterByStaffId) continue;
        
        if (invoice.isReturned) {
          totalSales -= invoice.totalAmount;
          returnsByStaff[staffName] = (returnsByStaff[staffName] ?? 0) + invoice.totalAmount;
        } else {
          totalSales += invoice.totalAmount;
          salesCount++;
          
          // Track online store sales (sessionName == 'online' or source flag)
          final isOnline = invoice.sessionName?.toLowerCase() == 'online' ||
              invoice.addedById?.startsWith('store_') == true;
          if (isOnline) onlineSales += invoice.totalAmount;
          
          salesByStaff[staffName] = (salesByStaff[staffName] ?? 0) + invoice.totalAmount;

          for (final item in invoice.items) {
            final cName = categoryNames[item.category];
            final categoryKey = (cName != null && cName.isNotEmpty) ? cName : 'غير مصنف';
            salesByCategory[categoryKey] = (salesByCategory[categoryKey] ?? 0) + item.totalPrice;
            // Track product quantity sold
            final productKey = item.productName;
            salesByProduct[productKey] = (salesByProduct[productKey] ?? 0) + item.quantity;
          }
        }
      }

      // Fetch Expenses
      final expensesQuery = await _firestore
          .collection('expenses')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      final filteredExpenses = expensesQuery.docs.where((doc) {
        final date = doc.data()['date'] as String?;
        if (date == null) return false;
        return date.compareTo(startIso) >= 0 && date.compareTo(endIso) <= 0;
      });

      double totalExpenses = 0;
      for (var doc in filteredExpenses) {
        totalExpenses += (doc.data()['amount'] as num? ?? 0).toDouble();
      }

      // Fetch Purchases
      final purchasesQuery = await _firestore
          .collection('purchase_invoices')
          .where('tenantId', isEqualTo: tenantId)
          .get();

      final filteredPurchases = purchasesQuery.docs.where((doc) {
        final date = doc.data()['date'] as String?;
        if (date == null) return false;
        return date.compareTo(startIso) >= 0 && date.compareTo(endIso) <= 0;
      });

      double totalPurchases = 0;
      for (var doc in filteredPurchases) {
        final invoice = PurchaseInvoiceModel.fromJson(doc.data()..['id'] = doc.id);
        totalPurchases += invoice.totalAmount;
      }

      return BusinessReport(
        totalSales: totalSales,
        totalExpenses: totalExpenses,
        totalPurchases: totalPurchases,
        grossProfit: totalSales - totalPurchases,
        netProfit: totalSales - totalExpenses - totalPurchases,
        salesCount: salesCount,
        onlineSales: onlineSales,
        salesByCategory: salesByCategory,
        salesByStaff: salesByStaff,
        returnsByStaff: returnsByStaff,
        salesByProduct: salesByProduct,
      );
    } catch (e) {
      debugPrint('REPORT DATA ERROR: $e');
      throw 'فشل تحميل التقرير: $e';
    }
  }
}

final reportRepositoryProvider =
    Provider((ref) => ReportRepository(FirebaseFirestore.instance));

final financialReportProvider =
    FutureProvider.family<BusinessReport, ReportParams>((ref, params) async {
  return ref
      .watch(reportRepositoryProvider)
      .getFinancialReport(params.tenantId, start: params.start, end: params.end, filterByStaffId: params.filterByStaffId);
});
