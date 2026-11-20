import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:pos_app/core/providers/tenant_provider.dart';
import 'package:pos_app/core/providers/permissions_provider.dart';
import 'package:pos_app/features/products/presentation/providers/category_provider.dart';
import 'package:pos_app/features/products/presentation/screens/product_form_screen.dart';
import 'package:pos_app/features/suppliers/presentation/providers/suppliers_provider.dart';
import 'package:pos_app/features/reports/data/report_repository.dart';
import 'package:pos_app/features/reports/presentation/screens/reports_screen.dart';
import 'package:pos_app/features/reports/presentation/screens/treasury_dashboard_screen.dart';
import 'package:pos_app/features/settings/data/staff_repository.dart';
import 'package:pos_app/features/staff/data/shift_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final width in [320.0, 1024.0]) {
    for (final screen in [
      const ReportsScreen(),
      const TreasuryDashboardScreen(),
      const ProductFormScreen(),
    ]) {
      testWidgets('${screen.runtimeType} at $width pixels', (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({'tenant_id': 'test'});
        final prefs = await SharedPreferences.getInstance();
        final day = DateTime.now();
        final report = BusinessReport(
          totalSales: 95,
          totalPurchases: 10,
          totalExpenses: 5,
          grossProfit: 55,
          netProfit: 50,
          salesCount: 1,
          onlineSales: 45,
          salesByStaff: {'كاشير': 95},
          salesByProduct: {'قميص': 1},
          salesByCategory: {'ملابس': 95},
          salesTrend: {'2026-11-20': 95},
          profitTrend: {'2026-11-20': 50},
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              permissionsProvider.overrideWithValue({}),
              categoriesProvider.overrideWith((ref) => Stream.value([])),
              suppliersFutureProvider.overrideWith((ref) async => []),
              staffListProvider('test').overrideWith((ref) async => []),
              shiftHistoryFutureProvider(
                'test',
              ).overrideWith((ref) async => []),
              for (final start in {1, day.day})
                financialReportProvider(
                  ReportParams(
                    tenantId: 'test',
                    start: DateTime(day.year, day.month, start),
                    end: DateTime(day.year, day.month, day.day, 23, 59, 59),
                  ),
                ).overrideWith((ref) async => report),
            ],
            child: MaterialApp(
              home: Directionality(
                textDirection: TextDirection.rtl,
                child: screen,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (screen is ProductFormScreen) {
          await tester.ensureVisible(find.text('إدخال متقدّم'));
          await tester.tap(find.text('إدخال متقدّم'));
          await tester.pumpAndSettle();
          expect(find.text('الكمية الإجمالية'), findsOneWidget);
        } else if (screen is TreasuryDashboardScreen) {
          expect(find.text('صافي الربح اليوم'), findsOneWidget);
        } else {
          expect(find.text('أداء الموظفين'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
