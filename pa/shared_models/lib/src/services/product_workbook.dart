import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel_community/excel_community.dart' as x;
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../models/product_variant.dart';
import '../models/product_storage_location.dart';

class ProductWorkbook {
  static const headers = {
    'mode': 'نوع الإدخال',
    'id': 'معرف المنتج',
    'name': 'الاسم',
    'barcode': 'الباركود',
    'price': 'سعر البيع',
    'description': 'الوصف',
    'category': 'القسم',
    'colors': 'الأصناف',
    'sizes': 'الأحجام',
    'cost': 'سعر الشراء',
    'wholesale': 'سعر الجملة',
    'min': 'الحد الأدنى للمخزون',
    'unit': 'الوحدة',
    'total': 'الكمية الإجمالية',
    'color': 'الصنف',
    'size': 'الحجم',
    'variantPrice': 'سعر التنويعة',
    'warehouse': 'اسم المخزن',
    'shelf': 'الرف',
    'box': 'الصندوق',
    'quantity': 'كمية المخزن',
    'locationPrice': 'سعر الموقع',
  };
  static const legacy = {
    'ID': 'id',
    'Product ID': 'id',
    'معرّف المنتج': 'id',
    'Name': 'name',
    'Barcode': 'barcode',
    'Price': 'price',
    'Purchase Price': 'cost',
    'Total Stock': 'total',
    'Warehouse Name': 'warehouse',
    'Shelf': 'shelf',
    'Box': 'box',
    'Warehouse Quantity': 'quantity',
    'Category': 'category',
    'Unit': 'unit',
    'Min Stock Level': 'min',
    'Description': 'description',
  };

  static Uint8List export(List<ProductModel> products) {
    final book = x.Excel.createExcel();
    final sheet = book[book.getDefaultSheet()!];
    sheet.appendRow(headers.values.map(x.TextCellValue.new).toList());
    for (final p in products) {
      final advanced =
          p.variants.any(
            (v) =>
                v.stock != 0 ||
                v.price != null ||
                v.storageLocations.isNotEmpty,
          ) ||
          (p.minStockLevel ?? 5) != 5 ||
          p.stockQuantity != 0 ||
          (p.purchasePrice ?? 0) != 0 ||
          (p.wholesalePrice ?? 0) != 0;
      final base = <String, Object?>{
        'mode': advanced ? 'متقدم' : 'بسيط',
        'id': p.id,
        'name': p.name,
        'barcode': p.barcode,
        'price': p.price,
        'description': p.description,
        'category': p.category,
        'colors': jsonEncode(p.colors),
        'sizes': jsonEncode(p.sizes),
        'unit': p.unit,
        if (advanced) ...{
          'cost': p.purchasePrice,
          'wholesale': p.wholesalePrice,
          'min': p.minStockLevel,
          'total': p.stockQuantity,
        },
      };
      void row(Map<String, Object?> extra) {
        final data = {...base, ...extra};
        sheet.appendRow([
          for (final key in headers.keys)
            switch (data[key]) {
              null => null,
              int n => x.IntCellValue(n),
              double n => x.DoubleCellValue(n),
              final v => x.TextCellValue(v.toString()),
            },
        ]);
      }

      if (!advanced || p.variants.isEmpty) {
        row({});
        continue;
      }
      for (final v in p.variants) {
        final variant = {
          'color': v.color,
          'size': v.size,
          'variantPrice': v.price,
        };
        if (v.storageLocations.isEmpty) {
          row({...variant, 'quantity': v.stock});
        }
        for (final loc in v.storageLocations) {
          row({
            ...variant,
            'warehouse': loc.warehouseName,
            'shelf': loc.shelf,
            'box': loc.box,
            'quantity': loc.quantity,
            'locationPrice': loc.priceOverride,
          });
        }
      }
    }
    return Uint8List.fromList(book.encode()!);
  }

  static List<List<String>> _readWorksheet(Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);
    XmlDocument part(String path) {
      final file = zip.findFile(path);
      if (file == null || file.size > 32 * 1024 * 1024)
        throw FormatException('تعذّرت قراءة ورقة Excel: $path');
      return XmlDocument.parse(utf8.decode(file.content));
    }

    Iterable<XmlElement> nodes(XmlNode node, String name) => node.descendants
        .whereType<XmlElement>()
        .where((e) => e.name.local == name);
    final first = nodes(part('xl/workbook.xml'), 'sheet').first;
    final id = first.attributes.firstWhere((a) => a.name.local == 'id').value;
    final relationships = nodes(
      part('xl/_rels/workbook.xml.rels'),
      'Relationship',
    ).toList();
    String target(XmlElement rel) {
      final path = rel.getAttribute('Target')!;
      return Uri.parse('/xl/workbook.xml').resolve(path).path.substring(1);
    }

    final sheet = part(
      target(relationships.firstWhere((r) => r.getAttribute('Id') == id)),
    );
    final stringsRel = relationships
        .where(
          (r) => r.getAttribute('Type')?.endsWith('/sharedStrings') == true,
        )
        .firstOrNull;
    final strings = [
      if (stringsRel != null)
        for (final si in nodes(part(target(stringsRel)), 'si'))
          nodes(si, 't').map((t) => t.innerText).join(),
    ];
    final rows = <List<String>>[];
    for (final row in nodes(sheet, 'row')) {
      final cells = <String>[];
      final rowIndex =
          int.tryParse(row.getAttribute('r') ?? '') ?? rows.length + 1;
      if (rowIndex < 1 || rowIndex > 100000)
        throw const FormatException('رقم صف غير صالح أو يتجاوز 100000');
      while (rows.length < rowIndex - 1) rows.add([]);
      for (final c in row.childElements.where((e) => e.name.local == 'c')) {
        final address = c.getAttribute('r') ?? '';
        int index = 0;
        for (final ch
            in RegExp(r'^[A-Z]+').stringMatch(address)?.codeUnits ?? <int>[]) {
          index = index * 26 + ch - 64;
        }
        if (index > 16384)
          throw FormatException('عنوان خلية غير صالح: $address');
        while (cells.length < index - 1) cells.add('');
        if (nodes(c, 'f').isNotEmpty)
          throw FormatException('الصف $rowIndex: استبدل المعادلة بقيمتها');
        final raw = nodes(c, 'v').firstOrNull?.innerText ?? '';
        final type = c.getAttribute('t');
        if (type == 'e')
          throw FormatException('الخلية $address تحتوي خطأ Excel');
        cells.add(
          (type == 's'
                  ? strings[int.parse(raw)]
                  : type == 'inlineStr'
                  ? nodes(c, 't').map((t) => t.innerText).join()
                  : raw)
              .trim(),
        );
      }
      rows.add(cells);
    }
    return rows;
  }

  static List<ProductModel> parse(
    Uint8List bytes,
    String filename,
    String tenant,
    List<ProductModel> existing,
  ) {
    final List<List<String>> rows;
    if (filename.toLowerCase().endsWith('.xlsx')) {
      rows = _readWorksheet(bytes);
    } else {
      rows = csv
          .decode(utf8.decode(bytes).replaceFirst('\uFEFF', ''))
          .map((r) => r.map((v) => v.toString().trim()).toList())
          .toList();
    }
    if (rows.isEmpty) throw const FormatException('ملف فارغ');
    final aliases = {
      for (final e in headers.entries) e.value: e.key,
      for (final k in headers.keys) k: k,
      ...legacy,
    };
    final cols = rows.first.map((v) => aliases[v]).toList();
    if (!cols.contains('name') || !cols.contains('price'))
      throw const FormatException('يلزم عمود الاسم وسعر البيع');
    if (cols.whereType<String>().toSet().length !=
        cols.whereType<String>().length)
      throw const FormatException('اسم عمود مكرر');
    final groups = <String, List<(int, Map<String, String>)>>{};
    final byId = {
      for (final p in existing.where((p) => p.tenantId == tenant)) p.id: p,
    };
    String nameKey(String value) => value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[\u200e\u200f\u061c]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    final names = <String, List<ProductModel>>{};
    final barcodes = <String, List<ProductModel>>{};
    for (final product in byId.values) {
      (names[nameKey(product.name)] ??= []).add(product);
      final barcode = product.barcode?.trim() ?? '';
      if (barcode.isNotEmpty) (barcodes[barcode] ??= []).add(product);
    }
    final barcodeIds = <String, String>{};
    for (final (idx, row) in rows.skip(1).indexed) {
      final n = idx + 2;
      if (row.every((v) => v.isEmpty)) continue;
      final d = {
        for (var j = 0; j < cols.length; j++)
          if (cols[j] != null) cols[j]!: j < row.length ? row[j].trim() : '',
      };
      final name = d['name']!,
          code = d['barcode'] ?? '',
          supplied = d['id'] ?? '';
      if (name.isEmpty) throw FormatException('الصف $n: اسم المنتج فارغ');
      final sameBarcode = barcodes[code] ?? const <ProductModel>[];
      final sameName = names[nameKey(name)] ?? const <ProductModel>[];
      final candidates = sameBarcode.isNotEmpty ? sameBarcode : sameName;
      String id;
      if (supplied.isNotEmpty) {
        if (!byId.containsKey(supplied) &&
            candidates.any(
              (p) =>
                  code.isEmpty ||
                  (p.barcode ?? '').isEmpty ||
                  p.barcode?.trim() == code,
            )) {
          throw FormatException(
            'الصف $n: المعرّف لا يطابق الصنف الموجود. استخدم معرفه من آخر تصدير.',
          );
        }
        id = supplied;
      } else if (candidates.isNotEmpty) {
        if (candidates.length != 1)
          throw FormatException(
            'الصف $n: أكثر من منتج مطابق. استخدم معرف المنتج من التصدير.',
          );
        final match = candidates.single;
        if (sameBarcode.isEmpty &&
            code.isNotEmpty &&
            (match.barcode?.trim() ?? '').isNotEmpty) {
          throw FormatException(
            'الصف $n: الاسم موجود بباركود مختلف. استخدم معرف المنتج لتعديل الباركود.',
          );
        }
        id = match.id;
      } else {
        id = const Uuid().v5(
          Uuid.NAMESPACE_URL,
          jsonEncode([
            tenant,
            code.isEmpty ? 'name' : 'barcode',
            code.isEmpty ? nameKey(name) : code,
          ]),
        );
      }
      if (code.isNotEmpty &&
          (sameBarcode.any((p) => p.id != id) ||
              (barcodeIds[code] != null && barcodeIds[code] != id))) {
        throw FormatException('الصف $n: الباركود يخص منتجاً آخر');
      }
      if (code.isNotEmpty) barcodeIds[code] = id;
      (groups[id] ??= []).add((n, d));
    }
    if (groups.isEmpty) throw const FormatException('الملف يحتوي عناوين فقط');
    return [
      for (final g in groups.entries)
        _product(g.key, tenant, g.value, byId[g.key]),
    ];
  }

  static ProductModel _product(
    String id,
    String tenant,
    List<(int, Map<String, String>)> rows,
    ProductModel? old,
  ) {
    final (first, d) = rows.first;
    Never bad(int n, String message) =>
        throw FormatException('الصف $n: $message');
    double number(String raw, int n, String key) {
      final normalized = raw
          .replaceAllMapped(
            RegExp('[٠-٩]'),
            (m) => (m[0]!.codeUnitAt(0) - 0x660).toString(),
          )
          .replaceAll('٫', '.');
      final v = double.tryParse(normalized);
      if (v == null || !v.isFinite || v < 0)
        bad(n, 'قيمة غير صالحة في ${headers[key]}');
      return v!;
    }

    int whole(String raw, int n, String key) {
      final v = number(raw, n, key);
      if (v != v.truncateToDouble()) bad(n, 'يلزم عدد صحيح في ${headers[key]}');
      return v.toInt();
    }

    double? optional(Map<String, String> r, String k, int n) =>
        (r[k] ?? '').isEmpty ? null : number(r[k]!, n, k);
    bool has(Map<String, String> r, String k) => (r[k] ?? '').isNotEmpty;
    const inventory = [
      'cost',
      'wholesale',
      'min',
      'total',
      'color',
      'size',
      'variantPrice',
      'warehouse',
      'shelf',
      'box',
      'quantity',
      'locationPrice',
    ];
    bool mode(Map<String, String> r, int n) {
      final raw = (r['mode'] ?? '').toLowerCase();
      final stock = inventory.any((k) => has(r, k));
      if (raw == '') return stock;
      if (['متقدم', 'متقدّم', 'advanced'].contains(raw)) return true;
      if (!['بسيط', 'عادي', 'simple'].contains(raw))
        bad(n, 'نوع الإدخال غير معروف');
      if (stock) bad(n, 'بيانات المخزون تتطلب إدخالاً متقدماً');
      return false;
    }

    List<String> options(String key, List<String> fallback) {
      if (!d.containsKey(key)) return List.of(fallback);
      final raw = d[key]!;
      if (raw.isEmpty) return [];
      if (raw.startsWith('[')) {
        try {
          final data = jsonDecode(raw);
          if (data is List && data.every((v) => v is String))
            return data.cast<String>().toSet().toList();
        } catch (_) {}
        bad(first, 'قائمة غير صالحة في ${headers[key]}');
      }
      return raw
          .split('|')
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList();
    }

    final advanced = mode(d, first);
    final colors = options('colors', old?.colors ?? []),
        sizes = options('sizes', old?.sizes ?? []);
    final variants = <(String, String), ProductVariant>{};
    if (rows.length > 1 && !advanced) bad(rows[1].$1, 'تكرر صف المنتج البسيط');
    for (final (n, r) in rows) {
      if (mode(r, n) != advanced) bad(n, 'اختلاف نوع الإدخال للمنتج نفسه');
      for (final k in [
        'name',
        'price',
        'barcode',
        'category',
        'description',
        'total',
        'cost',
        'min',
        'unit',
        'wholesale',
        'colors',
        'sizes',
      ]) {
        if ((r[k] ?? '') != (d[k] ?? ''))
          bad(n, 'اختلاف ${headers[k]} بين صفوف المنتج');
      }
      if (!advanced ||
          ![
            'color',
            'size',
            'warehouse',
            'quantity',
            'variantPrice',
            'shelf',
            'box',
            'locationPrice',
          ].any((k) => has(r, k))) {
        if (rows.length > 1) bad(n, 'صف مخزون بلا تنويعة أو موقع');
        continue;
      }
      final c = has(r, 'color') ? r['color']! : 'Default',
          z = has(r, 'size') ? r['size']! : 'Default';
      if (c != 'Default' && !colors.contains(c)) colors.add(c);
      if (z != 'Default' && !sizes.contains(z)) sizes.add(z);
      final key = (c, z), prior = variants[key];
      final qty = whole(r['quantity'] ?? '', n, 'quantity');
      final price = optional(r, 'variantPrice', n);
      if (prior != null && prior.price != price)
        bad(n, 'أسعار مختلفة للتنويعة نفسها');
      final locs = [...?prior?.storageLocations];
      if (!has(r, 'warehouse')) {
        if (prior != null ||
            ['shelf', 'box', 'locationPrice'].any((k) => has(r, k)))
          bad(n, 'اسم المخزن مطلوب');
      } else {
        if (prior != null && locs.isEmpty)
          bad(n, 'لا تخلط صفاً بلا موقع مع مواقع التنويعة');
        final loc = ProductStorageLocation(
          warehouseName: r['warehouse']!,
          shelf: has(r, 'shelf') ? r['shelf'] : null,
          box: has(r, 'box') ? r['box'] : null,
          quantity: qty,
          priceOverride: optional(r, 'locationPrice', n),
        );
        if (locs.any(
          (v) =>
              v.warehouseName == loc.warehouseName &&
              v.shelf == loc.shelf &&
              v.box == loc.box &&
              v.priceOverride == loc.priceOverride,
        ))
          bad(n, 'موقع مكرر للتنويعة');
        locs.add(loc);
      }
      variants[key] = ProductVariant(
        color: c,
        size: z,
        price: price,
        stock: (prior?.stock ?? 0) + qty,
        storageLocations: locs,
      );
    }
    final count = variants.values.fold<int>(0, (a, b) => a + b.stock);
    final total = has(d, 'total')
        ? whole(d['total']!, first, 'total')
        : variants.isNotEmpty
        ? count
        : old?.stockQuantity ?? 0;
    if (variants.isNotEmpty && count != total)
      bad(first, 'مجموع كميات الصفوف لا يساوي الكمية الإجمالية');
    final kept = advanced
        ? variants.values.toList()
        : old?.variants ?? <ProductVariant>[];
    if (!advanced &&
        kept.any(
          (v) =>
              (v.color != 'Default' && !colors.contains(v.color)) ||
              (v.size != 'Default' && !sizes.contains(v.size)),
        ))
      bad(first, 'عدّل خيارات المنتج المرتبطة بالمخزون في الإدخال المتقدم');
    final base =
        old ??
        ProductModel(
          id: id,
          tenantId: tenant,
          name: '',
          category: 'عام',
          description: '',
          price: 0,
        );
    return base.copyWith(
      name: d['name'],
      price: number(d['price']!, first, 'price'),
      description: d['description'],
      category: d['category'],
      barcode: has(d, 'barcode') ? d['barcode'] : null,
      unit: has(d, 'unit') ? d['unit'] : null,
      colors: colors,
      sizes: sizes,
      purchasePrice: optional(d, 'cost', first),
      wholesalePrice: optional(d, 'wholesale', first),
      minStockLevel: has(d, 'min') ? whole(d['min']!, first, 'min') : null,
      stockQuantity: total,
      inStock: old != null && total == old.stockQuantity
          ? old.inStock
          : total > 0,
      variants: kept,
    );
  }
}
