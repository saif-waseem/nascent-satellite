import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/product_catalog.dart';

/// Firestore persists the pending flag across app restarts. The trusted server
/// reads the confirmed order and clears the flag only for the same revision.
class OrderStockSync {
  final Future<String?> Function() getToken;
  final _pending = <String>{};
  bool _running = false;

  OrderStockSync(this.getToken);

  void enqueue(String order) {
    _pending.add(order);
    if (!_running) unawaited(_drain());
  }

  Future<void> _drain() async {
    _running = true;
    try {
      final token = await getToken();
      if (token == null) return;
      for (final order in _pending.toList()) {
        final response = await http
            .post(
              Uri.parse(
                '${ProductCatalog.url}/functions/v1/confirm-order-stock',
              ),
              headers: {
                'apikey': ProductCatalog.key,
                'Content-Type': 'application/json',
                'x-firebase-token': token,
              },
              body: jsonEncode({'order': order}),
            )
            .timeout(const Duration(seconds: 12));
        if (response.statusCode == 204) _pending.remove(order);
      }
    } catch (_) {
      // A transient network or session failure leaves the persisted flag set.
    } finally {
      if (_pending.isEmpty) {
        _running = false;
      } else {
        Timer(const Duration(minutes: 2), _drain);
      }
    }
  }
}
