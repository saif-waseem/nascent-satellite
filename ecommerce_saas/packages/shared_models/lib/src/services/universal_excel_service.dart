import 'dart:convert';
import 'package:csv/csv.dart';
import '../models/product_model.dart';

/// Multilingual Universal Excel / CSV Service for POS System
/// Handles import/export for Products and Sales Invoices
class UniversalExcelService {
  static const String langArabic = 'ar';
  static const String langEnglish = 'en';

  // =========================================================================
  // 1. PRODUCTS IMPORT / EXPORT
  // =========================================================================

  static List<String> getProductHeaders(String lang) {
    if (lang == langArabic) {
      return [
        'الاسم',
        'الباركود',
        'سعر البيع',
        'سعر الشراء',
        'الكمية الإجمالية',
        'سعر الجملة',
        'القسم',
        'الوحدة',
        'الحد الأدنى للمخزون',
        'الوصف',
      ];
    } else {
      return [
        'Name',
        'Barcode',
        'Price',
        'Purchase Price',
        'Total Stock',
        'Wholesale Price',
        'Category',
        'Unit',
        'Min Stock Level',
        'Description',
      ];
    }
  }

  /// Exports products list to CSV string with UTF-8 BOM for perfect Excel Arabic support
  static String exportProductsToCsv(List<ProductModel> products, {String lang = langArabic}) {
    List<List<dynamic>> rows = [];
    rows.add(getProductHeaders(lang));

    for (var p in products) {
      rows.add([
        p.name,
        p.barcode ?? '',
        p.price,
        p.purchasePrice ?? 0,
        p.stockQuantity,
        p.wholesalePrice ?? 0,
        p.category,
        p.unit ?? 'قطعة',
        p.minStockLevel ?? 5,
        p.description,
      ]);
    }

    // Prepend UTF-8 BOM (\uFEFF) so Excel displays Arabic correctly without garbled text
    return '\uFEFF' + const ListToCsvConverter().convert(rows);
  }

  /// Parses CSV string into a list of parsed product maps ready to save
  static List<Map<String, dynamic>> parseProductsFromCsv(String csvString, String tenantId) {
    // Strip BOM if present
    String cleanStr = csvString;
    if (cleanStr.startsWith('\uFEFF')) {
      cleanStr = cleanStr.substring(1);
    }

    final rows = const CsvToListConverter().convert(cleanStr);
    if (rows.length <= 1) return [];

    final List<Map<String, dynamic>> result = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row[0] == null || row[0].toString().trim().isEmpty) continue;

      final name = row[0].toString().trim();
      final barcode = row.length > 1 && row[1] != null && row[1].toString().trim().isNotEmpty
          ? row[1].toString().trim()
          : null;

      final price = row.length > 2 && row[2] != null
          ? double.tryParse(row[2].toString().replaceAll(',', '').trim()) ?? 0.0
          : 0.0;

      final purchasePrice = row.length > 3 && row[3] != null
          ? double.tryParse(row[3].toString().replaceAll(',', '').trim()) ?? 0.0
          : 0.0;

      final stockQuantity = row.length > 4 && row[4] != null
          ? int.tryParse(row[4].toString().replaceAll(',', '').trim()) ?? 0
          : 0;

      final wholesalePrice = row.length > 5 && row[5] != null
          ? double.tryParse(row[5].toString().replaceAll(',', '').trim()) ?? 0.0
          : 0.0;

      final category = row.length > 6 && row[6] != null && row[6].toString().trim().isNotEmpty
          ? row[6].toString().trim()
          : 'عام';

      final unit = row.length > 7 && row[7] != null && row[7].toString().trim().isNotEmpty
          ? row[7].toString().trim()
          : 'قطعة';

      final minStockLevel = row.length > 8 && row[8] != null
          ? int.tryParse(row[8].toString().replaceAll(',', '').trim()) ?? 5
          : 5;

      final description = row.length > 9 && row[9] != null
          ? row[9].toString().trim()
          : '';

      result.add({
        'name': name,
        'barcode': barcode,
        'price': price,
        'purchasePrice': purchasePrice,
        'stockQuantity': stockQuantity,
        'wholesalePrice': wholesalePrice,
        'category': category,
        'unit': unit,
        'minStockLevel': minStockLevel,
        'description': description,
        'tenantId': tenantId,
      });
    }

    return result;
  }
}
