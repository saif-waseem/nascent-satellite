import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:uuid/uuid.dart';

class CsvImportExportDialog extends HookConsumerWidget {
  const CsvImportExportDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.file_copy, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            const Text('استيراد وتصدير المنتجات (CSV)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _exportCsv(context, ref),
                icon: const Icon(Icons.upload),
                label: const Text('تصدير كـ CSV'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _importCsv(context, ref),
                icon: const Icon(Icons.download),
                label: const Text('استيراد من CSV'),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    try {
      final products = await ref.read(adminProductsProvider.future);
      List<List<dynamic>> rows = [];
      // Headers
      rows.add([
        "Name", "Description", "Price", "Purchase Price", "Stock", 
        "Barcode", "Category", "Unit", "Min Stock Level"
      ]);
      
      for (var p in products) {
        rows.add([
          p.name, p.description, p.price, p.purchasePrice, p.stockQuantity, 
          p.barcode, p.category, p.unit, p.minStockLevel
        ]);
      }
      
      String csvString = csv.encode(rows);
      // In web/desktop we could prompt to save. On mobile it's trickier without path_provider.
      // This is a minimal representation for demo:
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحويل البيانات لـ CSV بنجاح!')));
      }
    } catch (e) {
      if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final bytes = result.files.first.bytes;
        if (bytes == null) throw Exception('No bytes found');
        
        final csvStr = utf8.decode(bytes);
        List<List<dynamic>> rows = csv.decode(csvStr);
        
        if (rows.length > 1) {
          final tenantId = ref.read(currentTenantIdProvider);
          int addCount = 0;
          for (int i = 1; i < rows.length; i++) {
            final row = rows[i];
            if (row.length >= 5) {
              final newProduct = ProductModel(
                id: const Uuid().v4(),
                tenantId: tenantId,
                name: row[0].toString(),
                description: row[1]?.toString() ?? '',
                price: double.tryParse(row[2]?.toString() ?? '0') ?? 0,
                purchasePrice: double.tryParse(row[3]?.toString() ?? '0') ?? 0,
                stockQuantity: int.tryParse(row[4]?.toString() ?? '0') ?? 0,
                barcode: row.length > 5 ? row[5]?.toString() : null,
                category: row.length > 6 ? row[6]?.toString() ?? 'All' : 'All',
                unit: row.length > 7 ? row[7]?.toString() : 'pcs',
                minStockLevel: row.length > 8 ? int.tryParse(row[8]?.toString() ?? '5') : 5,
                inStock: (int.tryParse(row[4]?.toString() ?? '0') ?? 0) > 0,
                images: [],
                sizes: [],
                colors: [],
                variants: [],
              );
              // Save to firestore
              await ref.read(adminFirestoreServiceProvider).addProduct(newProduct, tenantId);
              addCount++;
            }
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم استيراد $addCount منتج بنجاح!')));
          }
        }
      }
    } catch (e) {
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
       }
    }
    if (context.mounted) Navigator.pop(context);
  }
}
