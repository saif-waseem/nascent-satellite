import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_admin/core/services/notification_service.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/features/analytics/presentation/screens/admin_dashboard_screen.dart';

class TestNotifications extends Fake implements NotificationService {
  @override
  Future<void> initialize(String tenantId) async {}
}

void main() {
  for (final width in [320.0, 1024.0]) {
    testWidgets('dashboard excludes cancelled revenue and fits $width pixels', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final orders = [
        for (final status in [OrderStatus.completed, OrderStatus.cancelled])
          OrderModel(
            id: status.name,
            userId: 'u',
            tenantId: 'test',
            total: 750,
            items: [],
            status: status,
            userName: 'عميل',
            userPhone: '',
            date: DateTime.now(),
            address: '',
          ),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentTenantIdProvider.overrideWithValue('test'),
            notificationServiceProvider.overrideWithValue(TestNotifications()),
            adminOrdersProvider.overrideWith((ref) => Stream.value(orders)),
            adminProductsProvider.overrideWith((ref) => Stream.value([])),
            customerListProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: AdminDashboardScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.textContaining('750'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
