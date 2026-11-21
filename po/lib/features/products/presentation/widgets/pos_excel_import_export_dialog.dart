import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../data/product_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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
    try{
      final tenant=ref.read(tenantIdProvider);
      final products=await ref.read(productRepositoryProvider).getProducts(tenant);
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
      final tenant=ref.read(tenantIdProvider);
      final repo=ref.read(productRepositoryProvider);
      final existing=await repo.getProducts(tenant);
      final products=ProductWorkbook.parse(bytes,file.name,tenant,existing);
      if(!context.mounted)return;
      final existingIds={for(final p in existing)p.id:p};
      final updates=products.where((p)=>existingIds.containsKey(p.id)).length;
      final proceed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('مراجعة الاستيراد'),content:Text('إضافة ${products.length-updates} منتج وتحديث $updates. هل تريد الحفظ؟'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('حفظ'))]));
      if(proceed!=true || !context.mounted)return;
      for(final product in products){
        await repo.saveProduct(tenant,product);
        saved++;
      }
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم حفظ $saved منتج')));
    }catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تم حفظ $saved منتج. $e')));}
  }
}
