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
}
