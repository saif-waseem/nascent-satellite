import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:uuid/uuid.dart';
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import '../../../../core/providers/tenant_provider.dart';
import '../../data/product_repository.dart';

class PosExcelDialog extends HookConsumerWidget {
  const PosExcelDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantAsync = ref.watch(tenantProvider);
    final tenant = tenantAsync.value;
    final isExcelAllowed = tenant?.isPosExcelAllowed ?? true;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 480,
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
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.table_view_rounded, size: 32, color: Colors.green),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'استيراد وتصدير المنتجات (Excel / CSV)',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'تصدير المخزون بالكامل أو إضافة منتجات جديدة دفعة واحدة',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (!isExcelAllowed)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, color: Colors.amber, size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ميزة الإكسل متاحة للباقات المتقدمة (C و D). قم بالترقية من لوحة الإدارة.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '• التصدير: تنزيل ملف إكسل يحتوي على جميع المنتجات والأسعار والكميات.\n• الاستيراد: إضافة منتجات جديدة أو تحديث الأسعار والمخزون دفعة واحدة.',
                          style: TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Export Button
              FilledButton.icon(
                onPressed: isExcelAllowed ? () => _exportProducts(context, ref) : null,
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('تصدير المنتجات إلى ملف إكسل (CSV)'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 12),

              // Import Button
              OutlinedButton.icon(
                onPressed: isExcelAllowed ? () => _importProducts(context, ref) : null,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('استيراد منتجات من ملف إكسل (CSV)'),
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
      ),
    );
  }

  Future<void> _exportProducts(BuildContext context, WidgetRef ref) async {
    try {
      final tenantId = ref.read(tenantIdProvider);
      final repo = ref.read(productRepositoryProvider);
      final products = await repo.getProducts(tenantId);

      if (products.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد منتجات لتصديرها!')),
          );
        }
        return;
      }

      final csvData = UniversalExcelService.exportProductsToCsv(products, lang: 'ar');
      final bytes = utf8.encode(csvData);
      final fileName = 'pos_products_${DateTime.now().millisecondsSinceEpoch}.csv';

      final savedUri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
      );
      if (savedUri == null) return;

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تنزيل ملف الإكسل بنجاح! 🎉'), backgroundColor: Colors.green),
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
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);
        if (bytes == null) throw Exception('الملف فارغ');

        final csvString = utf8.decode(bytes);
        final tenantId = ref.read(tenantIdProvider);
        final parsed = UniversalExcelService.parseProductsFromCsv(csvString, tenantId);

        if (parsed.isEmpty) {
          throw Exception('لم يتم العثور على صفوف صالحة في الملف');
        }

        final repo = ref.read(productRepositoryProvider);
        int count = 0;

        for (var p in parsed) {
          final newProduct = ProductModel(
            id: const Uuid().v4(),
            tenantId: tenantId,
            name: p['name'] as String,
            barcode: p['barcode'] as String?,
            price: (p['price'] as num).toDouble(),
            purchasePrice: (p['purchasePrice'] as num).toDouble(),
            stockQuantity: (p['stockQuantity'] as num).toInt(),
            wholesalePrice: (p['wholesalePrice'] as num).toDouble(),
            category: p['category'] as String,
            unit: p['unit'] as String?,
            minStockLevel: (p['minStockLevel'] as num).toInt(),
            description: p['description'] as String,
            inStock: ((p['stockQuantity'] as num).toInt()) > 0,
            images: const [],
            sizes: const [],
            colors: const [],
            variants: const [],
          );
          await repo.saveProduct(tenantId, newProduct);
          count++;
        }

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم استيراد $count منتج بنجاح إلى قاعدة البيانات! 🚀'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الاستيراد: $e')));
      }
    }
  }
}
