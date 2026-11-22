import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';

class StockRecordScreen extends StatefulWidget {
  final ProductModel product;
  final String url, publishableKey;
  final Future<String?> Function()? readDeviceKey;
  final bool allowCount;
  const StockRecordScreen({
    super.key,
    required this.product,
    required this.url,
    required this.publishableKey,
    this.readDeviceKey,
    required this.allowCount,
  });
  @override
  State<StockRecordScreen> createState() => _StockRecordState();
}

class _StockRecordState extends State<StockRecordScreen> {
  final keyInput = TextEditingController(),
      quantity = TextEditingController(),
      reason = TextEditingController();
  List<dynamic> history = [];
  late int expected = widget.product.stockQuantity;
  String? message, variantFilter;
  bool busy = false, loaded = false, changed = false;
  String operation = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    if (widget.readDeviceKey != null) loadSavedKey();
  }

  Future<void> loadSavedKey() async {
    try {
      final key = await widget.readDeviceKey!();
      if (!mounted || key == null || keyInput.text.isNotEmpty) return;
      keyInput.text = key;
      await run(refresh);
    } catch (_) {
      if (mounted) setState(() => message = 'تعذرت قراءة مفتاح الجهاز');
    }
  }

  Future<dynamic> request(String name, Map<String, dynamic> args) async {
    final response = await http
        .post(
          Uri.parse('${widget.url}/rest/v1/rpc/$name'),
          headers: {
            'apikey': widget.publishableKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'p_device_key': keyInput.text.trim(),
            'p_tenant': widget.product.tenantId,
            'p_product': widget.product.id,
            ...args,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode >= 300) {
      if (response.body.contains('Stock changed'))
        throw StateError('تغيّر الرصيد. حدّث السجل وأعد مراجعة العدد.');
      if (response.body.contains('Device not authorized'))
        throw StateError('تحقق من مفتاح جهاز هذا المتجر.');
      throw StateError('تعذر تنفيذ العملية (${response.statusCode})');
    }
    return jsonDecode(response.body);
  }

  Future<void> refresh() async {
    final data = await request('cashier_product_snapshot', {});
    if (!mounted) return;
    expected = data['stock_quantity'] as int;
    history = data['history'] as List;
    loaded = true;
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) message = e.toString();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final counted = int.tryParse(quantity.text.trim());
    if (counted == null || counted < 0 || reason.text.trim().isEmpty)
      throw StateError('أدخل العدد الفعلي وسبب الجرد');
    await request('count_cashier_product', {
      'p_operation': operation,
      'p_expected': expected,
      'p_counted': counted,
      'p_reason': reason.text.trim(),
    });
    if (!mounted) return;
    changed = true;
    expected = counted;
    operation = const Uuid().v4();
    quantity.clear();
    reason.clear();
    message = 'تم تسجيل الجرد';
    await refresh();
  }

  @override
  void dispose() {
    keyInput.dispose();
    quantity.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.product.name)),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: keyInput,
          obscureText: true,
          enabled: !busy,
          onChanged: (_) => setState(() {
            loaded = false;
            history = [];
          }),
          decoration: const InputDecoration(labelText: 'مفتاح جهاز المتجر'),
        ),
        TextButton.icon(
          onPressed: busy ? null : () => run(refresh),
          icon: const Icon(Icons.refresh),
          label: const Text('تحديث سجل المخزون'),
        ),
        if (busy) const LinearProgressIndicator(),
        if (message != null) Text(message!),
        if (loaded) ...[
          Text('الرصيد المسجل: $expected'),
          if (widget.allowCount && widget.product.variants.isEmpty) ...[
            TextField(
              enabled: !busy,
              controller: quantity,
              keyboardType: TextInputType.number,
              onChanged: (_) => operation = const Uuid().v4(),
              decoration: const InputDecoration(labelText: 'العدد الفعلي'),
            ),
            TextField(
              enabled: !busy,
              controller: reason,
              maxLength: 250,
              onChanged: (_) => operation = const Uuid().v4(),
              decoration: const InputDecoration(
                labelText: 'سبب الجرد أو التسوية',
              ),
            ),
            FilledButton(
              onPressed: busy ? null : () => run(save),
              child: const Text('اعتماد الجرد'),
            ),
          ],
          const Divider(),
          const Text('آخر 100 حركة'),
          if (history.any((row) => (row['variants'] as List? ?? []).isNotEmpty))
            DropdownButton<String>(
              isExpanded: true,
              value: variantFilter,
              hint: const Text('كل الأصناف والأحجام'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('كل الأصناف والأحجام'),
                ),
                for (final option in {
                  for (final row in history)
                    for (final line in row['variants'] ?? [])
                      jsonEncode([line['color'], line['size']]),
                })
                  DropdownMenuItem<String>(
                    value: option,
                    child: Text((jsonDecode(option) as List).join(' / ')),
                  ),
              ],
              onChanged: (v) => setState(() => variantFilter = v),
            ),
          if (history.isEmpty) const Text('لا توجد حركات مسجلة لهذا الصنف'),
          for (final row in history.where(
            (r) =>
                variantFilter == null ||
                (r['variants'] as List? ?? []).any(
                  (v) => jsonEncode([v['color'], v['size']]) == variantFilter,
                ),
          ))
            ListTile(
              title: Text(row['note'] as String),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateTime.parse(
                      row['recorded_at'],
                    ).toLocal().toString().split('.').first,
                  ),
                  Text(
                    'قبل: ${row['opening'] ?? (row['balance'] - row['delta'])}  •  بعد: ${row['balance']}',
                  ),
                  for (final line in row['variants'] ?? [])
                    Text(
                      "${line['color']} / ${line['size']}  •  ${line['opening']} ← ${line['balance']}",
                    ),
                ],
              ),
              trailing: Text("${row['delta'] > 0 ? '+' : ''}${row['delta']}"),
            ),
        ],
      ],
    ),
  );
}
