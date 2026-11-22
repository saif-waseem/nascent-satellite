import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/product_catalog.dart';
import '../models/product_model.dart';

class CatalogUndo {
  final String app;
  const CatalogUndo(this.app);
  static String batch() => const Uuid().v4();
  String _prefix(String tenant) =>
      'catalog_undo/$app/${Uri.encodeComponent(tenant)}/';

  Future<void> record(
    String tenant,
    ProductModel? previous,
    ProductModel next,
    String? batchId,
  ) async {
    final before = previous == null ? null : ProductCatalog.encode(previous);
    final after = ProductCatalog.encode(next);
    final fields = after.keys
        .where(
          (key) =>
              key != 'id' &&
              key != 'tenant_id' &&
              (before == null ||
                  jsonEncode(before[key]) != jsonEncode(after[key])),
        )
        .toList();
    if (fields.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final entry = {
      'id': next.id,
      'name': next.name,
      'batch': batchId ?? batch(),
      'expected': {for (final k in fields) k: after[k]},
      'restore': before == null
          ? {'is_archived': true}
          : {for (final k in fields) k: before[k]},
    };
    final key =
        '${_prefix(tenant)}${DateTime.now().microsecondsSinceEpoch}/${batch()}';
    if (!await prefs.setString(key, jsonEncode(entry)))
      throw StateError('تم الحفظ وتعذّر تسجيل التراجع');
  }

  static Map<String, dynamic> restore(
    Map<String, dynamic> current,
    Map<String, dynamic> entry,
  ) {
    final expected = entry['expected'] as Map;
    for (final k in expected.keys) {
      if (jsonEncode(current[k]) != jsonEncode(expected[k])) {
        throw StateError(
          'تغيّرت بيانات «${entry['name']}» بعد الحفظ. راجعها قبل التراجع.',
        );
      }
    }
    return {...current, ...Map<String, dynamic>.from(entry['restore'] as Map)};
  }

  Future<void> show(
    BuildContext context,
    String tenant,
    Future<void> Function(Map<String, dynamic>) apply,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final keys =
        prefs.getKeys().where((k) => k.startsWith(_prefix(tenant))).toList()
          ..sort((a, b) => b.compareTo(a));
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (keys.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'لا توجد تعديلات منتجات مسجلة على هذا الجهاز للتراجع عنها',
          ),
        ),
      );
      return;
    }
    Map<String, dynamic> read(String key) =>
        jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
    final last = read(keys.first);
    final group = keys.where((k) => read(k)['batch'] == last['batch']).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('التراجع عن آخر حفظ'),
        content: Text(
          'عدد التعديلات: ${group.length}. ستعود الحقول المعدلة إلى قيمها السابقة، ويُنقل المنتج المضاف إلى الأرشيف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تراجع'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    var done = 0;
    try {
      for (final key in group) {
        if (!prefs.containsKey(key)) continue;
        await apply(read(key));
        await prefs.remove(key);
        done++;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('تم التراجع عن $done تعديل')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('تم التراجع عن $done. تعذّر إكمال التراجع: $e')),
      );
    }
  }
}
