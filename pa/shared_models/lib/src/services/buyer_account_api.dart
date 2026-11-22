import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_catalog.dart';

class BuyerAccountApi {
  static Future<Map<String, dynamic>> call(
    String token,
    String action,
    String tenant,
    Map<String, dynamic> data,
  ) async {
    final r = await http
        .post(
          Uri.parse('${ProductCatalog.url}/functions/v1/buyer-account'),
          headers: {
            'apikey': ProductCatalog.key,
            'Content-Type': 'application/json',
            'x-buyer-token': token,
          },
          body: jsonEncode({...data, 'action': action, 'tenant': tenant}),
        )
        .timeout(const Duration(seconds: 30));
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    if (r.statusCode != 200)
      throw StateError(body['error']?.toString() ?? 'تعذرت خدمة الحسابات');
    return body;
  }
}
