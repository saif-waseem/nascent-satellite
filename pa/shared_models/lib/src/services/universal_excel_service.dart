import 'dart:convert';
import 'package:csv/csv.dart';
import '../models/product_model.dart';
import '../models/product_storage_location.dart';
import '../models/car_contract_model.dart';

/// Multilingual Universal Excel / CSV Service
/// Handles import/export for Products (with warehouse/shelf/box info) and Car Contracts
class UniversalExcelService {
  static const String langArabic = 'ar';
  static const String langEnglish = 'en';

  // =========================================================================
  // 1. PRODUCTS IMPORT / EXPORT (with Warehouse / Shelf / Box locations)
  // =========================================================================

  static List<String> getProductHeaders(String lang) {
    if (lang == langArabic) {
      return [
        'الاسم',
        'الباركود',
        'سعر البيع',
        'سعر الشراء',
        'الكمية الإجمالية',
        'اسم المخزن',
        'الرف',
        'الصندوق',
        'كمية المخزن',
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
        'Warehouse Name',
        'Shelf',
        'Box',
        'Warehouse Quantity',
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
        lang == langArabic ? 'المخزن الرئيسي' : 'Main Warehouse',
        '',
        '',
        p.stockQuantity,
        p.category,
        p.unit ?? '',
        p.minStockLevel ?? 5,
        p.description,
      ]);
    }

    // Prepend UTF-8 BOM (\uFEFF) so Excel displays Arabic correctly without garbled text
    return '\uFEFF' + csv.encode(rows);
  }

  /// Parses CSV string into a list of parsed product maps ready to save
  static List<Map<String, dynamic>> parseProductsFromCsv(String csvString, String tenantId) {
    // Strip BOM if present
    String cleanStr = csvString;
    if (cleanStr.startsWith('\uFEFF')) {
      cleanStr = cleanStr.substring(1);
    }

    final rows = csv.decode(cleanStr);
    if (rows.length <= 1) return [];

    final Map<String, Map<String, dynamic>> aggregatedProducts = {};

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row[0] == null || row[0].toString().trim().isEmpty) continue;

      final name = row[0].toString().trim();
      final barcode = row.length > 1 && row[1] != null && row[1].toString().trim().isNotEmpty
          ? row[1].toString().trim()
          : null;
      final price = row.length > 2 ? (double.tryParse(row[2].toString()) ?? 0.0) : 0.0;
      final purchasePrice = row.length > 3 ? (double.tryParse(row[3].toString()) ?? 0.0) : 0.0;
      final totalStock = row.length > 4 ? (int.tryParse(row[4].toString()) ?? 0) : 0;
      
      final warehouse = row.length > 5 && row[5] != null && row[5].toString().trim().isNotEmpty
          ? row[5].toString().trim()
          : 'المخزن الرئيسي';
      final shelf = row.length > 6 && row[6] != null ? row[6].toString().trim() : '';
      final box = row.length > 7 && row[7] != null ? row[7].toString().trim() : '';
      final warehouseQty = row.length > 8 ? (int.tryParse(row[8].toString()) ?? totalStock) : totalStock;

      final category = row.length > 9 && row[9] != null && row[9].toString().trim().isNotEmpty
          ? row[9].toString().trim()
          : 'عام';
      final unit = row.length > 10 && row[10] != null ? row[10].toString().trim() : 'قطعة';
      final minStock = row.length > 11 ? (int.tryParse(row[11].toString()) ?? 5) : 5;
      final description = row.length > 12 && row[12] != null ? row[12].toString().trim() : '';

      final loc = ProductStorageLocation(
        warehouseName: warehouse,
        shelf: shelf.isNotEmpty ? shelf : null,
        box: box.isNotEmpty ? box : null,
        quantity: warehouseQty,
      );

      final key = (barcode != null && barcode.isNotEmpty) ? barcode : name;

      if (aggregatedProducts.containsKey(key)) {
        final existing = aggregatedProducts[key]!;
        final List<ProductStorageLocation> locs = existing['storageLocations'] as List<ProductStorageLocation>;
        locs.add(loc);
        existing['stockQuantity'] = (existing['stockQuantity'] as int) + warehouseQty;
      } else {
        aggregatedProducts[key] = {
          'tenantId': tenantId,
          'name': name,
          'barcode': barcode,
          'price': price,
          'purchasePrice': purchasePrice,
          'stockQuantity': warehouseQty,
          'category': category,
          'unit': unit,
          'minStockLevel': minStock,
          'description': description,
          'storageLocations': [loc],
        };
      }
    }

    return aggregatedProducts.values.toList();
  }

  // =========================================================================
  // 2. CAR CONTRACTS IMPORT / EXPORT (for car_contracts application)
  // =========================================================================

  static List<String> getCarContractHeaders(String lang) {
    if (lang == langArabic) {
      return [
        'اسم البائع',
        'رقم هاتف البائع',
        'عنوان البائع',
        'اسم المشتري',
        'رقم هاتف المشتري',
        'عنوان المشتري',
        'نوع السيارة',
        'موديل السيارة',
        'سنة الصنع',
        'رقم اللوحة',
        'اللون',
        'رقم الشاصي',
        'السعر الإجمالي',
        'الواصل (المدفوع)',
        'المتبقي',
        'ملاحظات',
      ];
    } else {
      return [
        'Seller Name',
        'Seller Phone',
        'Seller Address',
        'Buyer Name',
        'Buyer Phone',
        'Buyer Address',
        'Car Type',
        'Car Model',
        'Car Year',
        'Plate Number',
        'Color',
        'Chassis Number',
        'Total Price',
        'Paid Amount',
        'Remaining Amount',
        'Notes',
      ];
    }
  }

  static String exportCarContractsToCsv(List<CarContractModel> contracts, {String lang = langArabic}) {
    List<List<dynamic>> rows = [];
    rows.add(getCarContractHeaders(lang));

    for (var c in contracts) {
      rows.add([
        c.sellerName,
        c.sellerPhone ?? '',
        c.sellerAddress ?? '',
        c.buyerName,
        c.buyerPhone ?? '',
        c.buyerAddress ?? '',
        c.carType,
        c.carModelName,
        c.carYear ?? '',
        c.carPlate ?? '',
        c.carColor ?? '',
        c.carChassis ?? '',
        c.priceTotal,
        c.pricePaid,
        c.priceRemaining,
        c.notes ?? '',
      ]);
    }

    return '\uFEFF' + csv.encode(rows);
  }

  static List<Map<String, dynamic>> parseCarContractsFromCsv(String csvString, String tenantId) {
    String cleanStr = csvString;
    if (cleanStr.startsWith('\uFEFF')) {
      cleanStr = cleanStr.substring(1);
    }

    final rows = csv.decode(cleanStr);
    if (rows.length <= 1) return [];

    final List<Map<String, dynamic>> contracts = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row[0] == null || row[0].toString().trim().isEmpty) continue;

      final sellerName = row[0].toString().trim();
      final sellerPhone = row.length > 1 && row[1] != null ? row[1].toString().trim() : '';
      final sellerAddress = row.length > 2 && row[2] != null ? row[2].toString().trim() : '';

      final buyerName = row.length > 3 && row[3] != null ? row[3].toString().trim() : '';
      final buyerPhone = row.length > 4 && row[4] != null ? row[4].toString().trim() : '';
      final buyerAddress = row.length > 5 && row[5] != null ? row[5].toString().trim() : '';

      final carType = row.length > 6 && row[6] != null ? row[6].toString().trim() : 'خصوصي';
      final carModel = row.length > 7 && row[7] != null ? row[7].toString().trim() : 'صالون';
      final carYear = row.length > 8 && row[8] != null ? row[8].toString().trim() : '';
      final carPlate = row.length > 9 && row[9] != null ? row[9].toString().trim() : '';
      final carColor = row.length > 10 && row[10] != null ? row[10].toString().trim() : '';
      final carChassis = row.length > 11 && row[11] != null ? row[11].toString().trim() : '';

      final totalPrice = row.length > 12 ? (double.tryParse(row[12].toString()) ?? 0.0) : 0.0;
      final paidPrice = row.length > 13 ? (double.tryParse(row[13].toString()) ?? 0.0) : 0.0;
      final remainingPrice = row.length > 14 ? (double.tryParse(row[14].toString()) ?? 0.0) : (totalPrice - paidPrice);
      final notes = row.length > 15 && row[15] != null ? row[15].toString().trim() : '';

      contracts.add({
        'tenantId': tenantId,
        'sellerName': sellerName,
        'sellerPhone': sellerPhone,
        'sellerAddress': sellerAddress,
        'buyerName': buyerName,
        'buyerPhone': buyerPhone,
        'buyerAddress': buyerAddress,
        'carType': carType,
        'carModelName': carModel,
        'carYear': carYear,
        'carPlate': carPlate,
        'carColor': carColor,
        'carChassis': carChassis,
        'priceTotal': totalPrice,
        'pricePaid': paidPrice,
        'priceRemaining': remainingPrice,
        'notes': notes,
      });
    }

    return contracts;
  }
}
