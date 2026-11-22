import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';

class ProductCatalog {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://axcdhxubqzbzjpbhyvvf.supabase.co',
  );
  static const key = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_wVnAoc2K3TewY6Wpb0-D4Q_fX94VBMH',
  );
  static const columns = {
    'id': 'id',
    'tenantId': 'tenant_id',
    'name': 'name',
    'category': 'category',
    'description': 'description',
    'price': 'price',
    'oldPrice': 'old_price',
    'purchasePrice': 'purchase_price',
    'wholesalePrice': 'wholesale_price',
    'stockQuantity': 'stock_quantity',
    'minStockLevel': 'min_stock_level',
    'unit': 'unit',
    'barcode': 'barcode',
    'images': 'images',
    'videoUrl': 'video_url',
    'rating': 'rating',
    'salesCount': 'sales_count',
    'inStock': 'in_stock',
    'isOffer': 'is_offer',
    'isFeaturedDeal': 'is_featured_deal',
    'isDailyStarred': 'is_daily_starred',
    'colors': 'colors',
    'sizes': 'sizes',
    'variants': 'variants',
    'isArchived': 'is_archived',
    'lastSupplierId': 'last_supplier_id',
    'expiryDate': 'expiry_date',
    'discountPercentage': 'discount_percentage',
  };
  static ProductModel decode(Map<String, dynamic> row) => ProductModel.fromJson(
    {for (final e in columns.entries) e.key: row[e.value]},
  );
  static Map<String, dynamic> encode(ProductModel p) {
    final json = p.toJson();
    return {for (final e in columns.entries) e.value: json[e.key]};
  }

  static Future<List<ProductModel>> read(
    String tenant, {
    String? barcode,
  }) async {
    if (tenant.isEmpty) return [];
    final result = <ProductModel>[];
    String? after;
    while (true) {
      final uri = Uri.parse('$url/rest/v1/products').replace(
        queryParameters: {
          'select': columns.values.join(','),
          'tenant_id': 'eq.$tenant',
          'order': 'id.asc',
          'limit': '250',
          if (barcode != null) 'barcode': 'eq.$barcode',
          if (after != null) 'id': 'gt.$after',
        },
      );
      final response = await http
          .get(uri, headers: {'apikey': key})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200)
        throw StateError(
          'تعذرت قراءة المنتجات من Supabase (${response.statusCode})',
        );
      final rows = jsonDecode(response.body) as List;
      result.addAll(rows.map((r) => decode(r as Map<String, dynamic>)));
      if (rows.length < 250) return result;
      after = result.last.id;
    }
  }

  static Stream<List<ProductModel>> watch(
    String tenant,
    Future<List<ProductModel>> Function() backup,
  ) {
    late StreamController<List<ProductModel>> controller;
    Timer? timer;
    bool active = true;
    Future<void> refresh() async {
      try {
        List<ProductModel> products;
        try {
          products = await read(tenant);
        } catch (_) {
          products = await backup().timeout(const Duration(seconds: 10));
        }
        if (active)
          controller.add(
            products
                .where((p) => p.tenantId == tenant && !p.isArchived)
                .toList(),
          );
      } catch (e, st) {
        if (active) controller.addError(e, st);
      } finally {
        if (active) timer = Timer(const Duration(seconds: 30), refresh);
      }
    }

    controller = StreamController(
      onListen: refresh,
      onCancel: () {
        active = false;
        timer?.cancel();
      },
    );
    return controller.stream;
  }
}
