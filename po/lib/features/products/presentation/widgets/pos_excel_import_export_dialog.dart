import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:uuid/uuid.dart';
import '../../data/product_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../providers/product_providers.dart';
import 'dart:html' as html;

class PosExcelImportExportDialog extends HookConsumerWidget {
  const PosExcelImportExportDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.table_chart_rounded, size: 30, color: Colors.indigo),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'استيراد وتصدير إكسل (الكاشير والمخازن)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'إدارة الجرد وتفاصيل الرفوف والصناديق لكل التيرات',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.amber, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'الملف يشمل تفاصيل موقع التخزين (المخزن، الرف، الصندوق) والكميات المتوفرة للجرد السريع.',
                      style: TextStyle(fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: () => _exportProducts(context, ref),
              icon: const Icon(Icons.download_rounded),
              label: const Text('تصدير كافّة المنتجات والمخازن إلى إكسل'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () => _importProducts(context, ref),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('استيراد وتحديث المنتجات من إكسل'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportProducts(BuildContext context, WidgetRef ref) async {
    try {
      final tenantId = ref.read(currentTenantIdProvider);
      final repo = ref.read(productRepositoryProvider);
      final products = await repo.getAllProducts(tenantId);

      final csvData = UniversalExcelService.exportProductsToCsv(products, lang: 'ar');

      final bytes = utf8.encode(csvData);
      final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'pos_inventory_${DateTime.now().millisecondsSinceEpoch}.csv')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تنزيل كشف الجرد الإكسل بنجاح! 📊'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء التصدير: $e')));
      }
    }
  }

  Future<void> _importProducts(BuildContext context, WidgetRef ref) async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (files.isNotEmpty) {
        final file = files.first;
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes == null) throw Exception('الملف فارغ');

        final csvString = utf8.decode(bytes);
        final tenantId = ref.read(currentTenantIdProvider);
        final parsed = UniversalExcelService.parseProductsFromCsv(csvString, tenantId);

        if (parsed.isEmpty) {
          throw Exception('لم يتم العثور على سجلات صالحة في الملف');
        }

        final repo = ref.read(productRepositoryProvider);
        int count = 0;

        for (var p in parsed) {
          final newProduct = ProductModel(
            id: const Uuid().v4(),
            tenantId: tenantId,
            name: p['name'],
            barcode: p['barcode'],
            price: p['price'],
            purchasePrice: p['purchasePrice'],
            stockQuantity: p['stockQuantity'],
            category: p['category'],
            unit: p['unit'],
            minStockLevel: p['minStockLevel'],
            description: p['description'],
            inStock: (p['stockQuantity'] as int) > 0,
            images: [],
            sizes: [],
            colors: [],
            variants: [],
          );

          await repo.addProduct(newProduct, tenantId);
          count++;
        }

        // Invalidate product stream
        ref.read(pagedGeneralProductsProvider.notifier).loadInitial();

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم استيراد $count منتج بنجاح في الكاشير! ✅'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الاستيراد: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
