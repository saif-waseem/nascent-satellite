import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  test(
    'reads Excel files with absolute part targets and namespace prefixes',
    () {
      final rows = ProductWorkbook.parse(
        File('test/fixtures/catalog.xlsx').readAsBytesSync(),
        'catalog.xlsx',
        'demo',
        [],
      );
      expect(rows.length, 2);
      expect(rows.first.barcode, '000901');
      expect(rows.last.stockQuantity, 8);
      expect(rows.last.variants.single.storageLocations.length, 2);
    },
  );
  const simple = ProductModel(
    id: 'p',
    tenantId: 'test',
    name: 'قميص',
    category: 'ملابس',
    description: 'قطن',
    price: 120,
    barcode: '0009',
    colors: ['أحمر'],
    sizes: ['M', 'L'],
  );
  final advanced = simple.copyWith(
    id: 'q',
    barcode: '0010',
    stockQuantity: 8,
    variants: const [
      ProductVariant(
        color: 'أحمر',
        size: 'M',
        stock: 8,
        price: 125,
        storageLocations: [
          ProductStorageLocation(warehouseName: 'أ', shelf: '1', quantity: 3),
          ProductStorageLocation(
            warehouseName: 'ب',
            quantity: 5,
            priceOverride: 115,
          ),
        ],
      ),
    ],
  );
  test(
    'Excel preserves barcode, options, description, locations and prices',
    () {
      final bytes = ProductWorkbook.export([simple, advanced]);
      expect(bytes.take(2), [80, 75]);
      final list = ProductWorkbook.parse(bytes, 'products.xlsx', 'test', []);
      expect(list.first.barcode, '0009');
      expect(list.first.sizes, ['M', 'L']);
      expect(list.first.description, 'قطن');
      expect(list.last.variants, advanced.variants);
      expect(list.last.stockQuantity, 8);
    },
  );
  List<ProductModel> parse(String s) => ProductWorkbook.parse(
    Uint8List.fromList(utf8.encode(s)),
    'file.csv',
    'test',
    [simple],
  );
  test('legacy headers match existing barcode and preserve media', () {
    expect(parse('Name,Barcode,Price\nChanged,0009,10').single.id, 'p');
  });
  test('invalid last row rejects file before any items are returned', () {
    expect(
      () => parse('الاسم,سعر البيع\nأول,5\nثان,-2'),
      throwsA(
        isA<FormatException>().having((e) => e.message, 'row', contains('3')),
      ),
    );
  });
  test('rejects inconsistent stock and mixed modes', () {
    expect(
      () => parse(
        'نوع الإدخال,الاسم,سعر البيع,كمية المخزن,الكمية الإجمالية\nمتقدم,أ,1,5,8',
      ),
      throwsFormatException,
    );
    expect(
      () => parse('نوع الإدخال,الاسم,سعر البيع,كمية المخزن\nبسيط,أ,1,5'),
      throwsFormatException,
    );
  });
  test(
    'append a row to an exported XLSX and import twice without duplicate products or bins',
    () {
      final catalog = {
        for (final p in [simple, advanced]) p.id: p,
      };
      final bytes = ProductWorkbook.export([
        simple,
        advanced,
        simple.copyWith(id: '', name: 'قميص جديد', barcode: '0088'),
      ]);
      for (var attempt = 0; attempt < 2; attempt++) {
        final parsed = ProductWorkbook.parse(
          bytes,
          'inventory.xlsx',
          'test',
          catalog.values.toList(),
        );
        final changed = parsed.where((p) => p != catalog[p.id]).toList();
        expect(changed.length, attempt == 0 ? 1 : 0);
        for (final p in changed) {
          catalog[p.id] = p;
        }
        expect(catalog.length, 3);
        expect(catalog['q']!.variants.single.storageLocations.length, 2);
      }
    },
  );
  test(
    'adding a barcode to a uniquely named legacy product preserves its ID',
    () {
      final old = ProductModel(
        id: 'original',
        tenantId: 'test',
        name: 'حقيبة  يد',
        category: 'عام',
        description: '',
        price: 9,
      );
      final result = ProductWorkbook.parse(
        Uint8List.fromList(
          utf8.encode('Name,Barcode,Price\nحقيبة يد,00121,12'),
        ),
        'legacy.csv',
        'test',
        [old],
      );
      expect(result.single.id, old.id);
      expect(result.single.barcode, '00121');
    },
  );
  test('stale supplied ID cannot duplicate an existing barcode', () {
    expect(
      () => parse('id,Name,Barcode,Price\nunknown,shirt,0009,10'),
      throwsFormatException,
    );
  });
}
