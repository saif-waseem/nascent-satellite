import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/features/products/presentation/screens/product_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_models/src/widgets/product_entry_options.dart';

void main() {
  testWidgets(
    'mobile product form shares description and confines stock to advanced entry',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentTenantIdProvider.overrideWithValue('test'),
            adminCategoriesProvider.overrideWith((ref) => Stream.value([])),
            tenantProvider.overrideWith((ref) => Stream.value(null)),
          ],
          child: const MaterialApp(
            home: ProductFormScreen(
              product: ProductModel(
                id: 'p',
                tenantId: 'test',
                name: 'قميص',
                description: 'قطن',
                category: 'ملابس',
                price: 100,
                stockQuantity: 8,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('الكمية الإجمالية'), findsNothing);
      final description = find.widgetWithText(TextField, 'قطن');
      await tester.ensureVisible(description);
      await tester.enterText(description, 'قطن خالص');
      final advanced = find.text('إدخال متقدّم');
      await tester.ensureVisible(advanced);
      await tester.tap(advanced);
      await tester.pumpAndSettle();
      expect(find.text('الكمية الإجمالية'), findsOneWidget);
      expect(find.text('قطن خالص'), findsOneWidget);
      expect(find.byType(EntryInventoryTable), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('locking either or both dimensions preserves total inventory', () {
    final rows = [
      for (final c in ['أحمر', 'أزرق'])
        for (final s in ['S', 'M'])
          ProductVariant(
            color: c,
            size: s,
            stock: 2,
            storageLocations: [
              const ProductStorageLocation(warehouseName: 'فرع', quantity: 2),
            ],
          ),
    ];
    for (final flags in [
      (true, true),
      (true, false),
      (false, true),
      (false, false),
    ]) {
      final result = entryVariants(rows, flags.$1, flags.$2);
      expect(result.fold<int>(0, (n, v) => n + entryStock(v)), 8);
      expect(result.length, (flags.$1 ? 2 : 1) * (flags.$2 ? 2 : 1));
    }
  });
  test('legacy stock without assigned location is preserved', () {
    expect(
      entryStock(const ProductVariant(color: 'X', size: 'L', stock: 9)),
      9,
    );
  });
  testWidgets(
    'option values survive disabling and enabling on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool enabled = true;
      List<String> values = [];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => ProductOptionValues(
                label: 'الأحجام',
                values: values,
                enabled: enabled,
                onToggle: (v) => setState(() => enabled = v),
                onChange: (v) => setState(() => values = v),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'XL');
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.byType(Switch));
        await tester.pumpAndSettle();
      }
      expect(find.text('XL'), findsOneWidget);
    },
  );
}
