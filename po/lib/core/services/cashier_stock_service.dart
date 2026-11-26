import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_models/shared_models.dart';
import 'package:uuid/uuid.dart';

final cashierStockProvider = Provider((ref) => CashierStockService());

class CashierStockService {
  static const _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://axcdhxubqzbzjpbhyvvf.supabase.co',
  );
  static const _publicKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_wVnAoc2K3TewY6Wpb0-D4Q_fX94VBMH',
  );
  static const _vault = FlutterSecureStorage();

  String get url => _url;
  String get publishableKey => _publicKey;
  Future<String?> deviceKey(String tenant) => _vault.read(key: 'stock_key_$tenant');

  Future<bool> linked(String tenant) async =>
      (await SharedPreferences.getInstance()).getBool('stock_linked_$tenant') ??
      false;

  Future<void> pair(String tenant, String key) async {
    if (tenant.isEmpty || tenant == 'local_default')
      throw StateError('اختر متجراً سحابياً');
    await _send(tenant, key, []);
    await _vault.write(key: 'stock_key_$tenant', value: key);
    await (await SharedPreferences.getInstance()).setBool(
      'stock_linked_$tenant',
      true,
    );
  }

  static List<Map<String, dynamic>> movements(
    SalesInvoiceModel invoice,
    ProductModel? Function(String) lookup,
  ) {
    final quantities = <String, int>{};
    for (final line in invoice.items) {
      final product = lookup(line.productId);
      if (product == null ||
          product.tenantId != invoice.tenantId ||
          product.variants.isNotEmpty)
        continue;
      quantities.update(
        line.productId,
        (v) => v + line.quantity,
        ifAbsent: () => line.quantity,
      );
    }
    return [
      for (final e in quantities.entries)
        if (e.value != 0)
          {
            'operation': const Uuid().v5(
              Namespace.url.value,
              jsonEncode([
                invoice.tenantId,
                invoice.id,
                e.key,
                invoice.isReturned,
              ]),
            ),
            'product': e.key,
            'delta': invoice.isReturned ? e.value : -e.value,
          },
    ];
  }

  Future<Map<String, int>> balances(String tenant, Iterable<String> ids) async {
    final result = <String, int>{};
    final unique = ids.toSet().toList();
    for (var offset = 0; offset < unique.length; offset += 50) {
      final chunk = unique.skip(offset).take(50).map(jsonEncode).join(',');
      final uri = Uri.parse('$_url/rest/v1/products').replace(queryParameters: {
        'tenant_id': 'eq.$tenant', 'id': 'in.($chunk)', 'select': 'id,stock_quantity',
      });
      final response = await http.get(uri, headers: {'apikey': _publicKey})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw StateError('تعذرت قراءة رصيد المخزون');
      for (final row in jsonDecode(response.body) as List) {
        result[row['id'] as String] = row['stock_quantity'] as int;
      }
    }
    return result;
  }

  Future<void> writeProduct(String id, Map<String,dynamic> job) async {
    final tenant=job['tenantId'] as String;
    final key=await deviceKey(tenant);
    if(key!=null && key.isNotEmpty){
      try {
        final response=await http.post(Uri.parse('$_url/rest/v1/rpc/write_cashier_catalog'),
          headers:{'apikey':_publicKey,'Content-Type':'application/json'},
          body:jsonEncode({'p_tenant':tenant,'p_device_key':key,'p_id':id,'p_operation':job['operation'],
            'p_action':job['action'],'p_before':job['before'],'p_patch':job['patch']})).timeout(const Duration(seconds:15));
        if(response.statusCode>=200 && response.statusCode<300) return;
      } catch (e) {
        // Fall back to direct REST write
      }
    }
    if (job['action'] == 'delete') {
      final uri = Uri.parse('$_url/rest/v1/products').replace(queryParameters: {
        'id': 'eq.$id',
        'tenant_id': 'eq.$tenant',
      });
      final response = await http.delete(uri, headers: {'apikey': _publicKey}).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('تعذر حذف المنتج من السحابة (${response.statusCode}): ${response.body}');
      }
      return;
    }
    // Direct REST upsert to Supabase
    final backup = job['backup'];
    if(backup != null && backup is Map) {
      final product = ProductModel.fromJson(Map<String, dynamic>.from(backup));
      final row = ProductCatalog.encode(product);
      row['tenant_id'] = tenant;
      final response = await http.post(
        Uri.parse('$_url/rest/v1/products'),
        headers: {
          'apikey': _publicKey,
          'Content-Type': 'application/json',
          'Prefer': 'resolution=merge-duplicates',
        },
        body: jsonEncode(row),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('تعذر حفظ المنتج في السحابة (${response.statusCode}): ${response.body}');
      }
    }
  }

  Future<void> submit(String tenant, List<dynamic> movements) async {
    final key = await _vault.read(key: 'stock_key_$tenant');
    if (key == null) throw StateError('أعد ربط جهاز الكاشير بالمخزون');
    await _send(tenant, key, movements);
  }

  Future<void> _send(String tenant, String key, List<dynamic> movements) async {
    final response = await http
        .post(
          Uri.parse('$_url/rest/v1/rpc/submit_cashier_stock'),
          headers: {'apikey': _publicKey, 'Content-Type': 'application/json'},
          body: jsonEncode({
            'p_tenant': tenant,
            'p_device_key': key,
            'p_movements': movements,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'تعذرت مزامنة المخزون (${response.statusCode}): ${response.body}',
      );
    }
  }
}
