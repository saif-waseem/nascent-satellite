import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';

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
              onPressed: () => _exportProducts(context, ref),
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

  Future<void> _exportProducts(BuildContext context, WidgetRef ref) async {
    try{
      final tenant=ref.read(currentTenantIdProvider);
      final products=await ref.read(adminSupabaseServiceProvider).getProducts(tenant);
      final bytes=ProductWorkbook.export(products.where((p)=>!p.isArchived).toList());
      final path=await FilePicker.saveFile(fileName:'products.xlsx',bytes:bytes,type:FileType.custom,allowedExtensions:['xlsx']);
      if(context.mounted && (kIsWeb || path!=null)) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تم تصدير ملف المنتجات')));
    }catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذّر التصدير: $e')));}
  }

  Future<void> _importProducts(BuildContext context,WidgetRef ref) async {
    var saved=0;
    try{
      final result=await FilePicker.pickFiles(type:FileType.custom,allowedExtensions:['xlsx','csv'],withData:true);
      if(result==null || !context.mounted)return;
      final file=result.files.single;
      final bytes=file.bytes;
      if(bytes==null)throw const FormatException('تعذّرت قراءة الملف');
      final tenant=ref.read(currentTenantIdProvider);
      final repo=ref.read(adminSupabaseServiceProvider);
      final existing=await repo.getProducts(tenant);
      final products=ProductWorkbook.parse(bytes,file.name,tenant,existing);
      if(!context.mounted)return;
      final existingIds={for(final p in existing)p.id:p};
      final updates=products.where((p)=>existingIds.containsKey(p.id)).length;
      final proceed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('مراجعة الاستيراد'),content:Text('إضافة ${products.length-updates} منتج وتحديث $updates. هل تريد الحفظ؟'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))]));
      if(proceed!=true || !context.mounted)return;
      for(final product in products){
        await repo.saveProduct(product,tenant,previousStock:existingIds[product.id]?.stockQuantity);

        saved++;
      }
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم حفظ $saved منتج')));
    }catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم حفظ $saved منتج. $e')));}
  }
}
