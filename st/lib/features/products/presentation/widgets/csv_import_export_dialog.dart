import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:uuid/uuid.dart';
import 'dart:io' show File, Platform;
import 'dart:typed_data' show Uint8List;
import 'package:path_provider/path_provider.dart';

class CsvImportExportDialog extends HookConsumerWidget {
  const CsvImportExportDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final isArabic = lang == 'ar';

    return Dialog(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'استيراد وتصدير المنتجات (Excel / CSV)' : 'Import & Export Products (Excel / CSV)',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isArabic 
                            ? 'يدعم تفاصيل المخزن (الرف، الصندوق، الكميات) ومتوافق مع العربية'
                            : 'Supports warehouse info (shelf, box, qty) and multilingual columns',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // How it works info card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isArabic
                          ? '• عند التصدير: ستحصل على ملف إكسل بكافة المنتجات ومخازنها.\n• عند الاستيراد: يمكنك إضافة منتجات جديدة أو تحديث الأسعار والمخزون دفعة واحدة.'
                          : '• Export: Downloads an Excel file with all products & warehouse bins.\n• Import: Add new products or bulk update prices & inventory.',
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Export Button
            FilledButton.icon(
              onPressed: () => _exportProducts(context, ref, lang),
              icon: const Icon(Icons.file_download_outlined),
              label: Text(isArabic ? 'تصدير المنتجات إلى ملف إكسل' : 'Export Products to Excel'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 12),

            // Import Button
            OutlinedButton.icon(
              onPressed: () => _importProducts(context, ref),
              icon: const Icon(Icons.file_upload_outlined),
              label: Text(isArabic ? 'استيراد منتجات من ملف إكسل' : 'Import Products from Excel'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isArabic ? 'إغلاق' : 'Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportProducts(BuildContext context, WidgetRef ref, String lang) async {
    try {
      final products = await ref.read(adminProductsProvider.future);
      final csvData = UniversalExcelService.exportProductsToCsv(products, lang: lang);
      
      // Save file cross-platform
      final bytes = utf8.encode(csvData);
      final fileName = 'products_inventory_${DateTime.now().millisecondsSinceEpoch}.csv';

      if (kIsWeb) {
        // Web: not supported in this build
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('التصدير غير مدعوم على الويب'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

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
        final tenantId = ref.read(currentTenantIdProvider);
        final parsed = UniversalExcelService.parseProductsFromCsv(csvString, tenantId);

        if (parsed.isEmpty) {
          throw Exception('لم يتم العثور على صفوف صالحة في الملف');
        }

        int count = 0;
        final supabaseService = ref.read(adminSupabaseServiceProvider);

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

          // Save to Supabase SQL directly
          await supabaseService.addProduct(newProduct, tenantId);
          // And dual-sync to Firestore during transition
          await ref.read(adminFirestoreServiceProvider).addProduct(newProduct, tenantId);
          count++;
        }

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم استيراد $count منتج مع تفاصيل المخازن بنجاح! ✅'),
              backgroundColor: Colors.green,
            ),
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
