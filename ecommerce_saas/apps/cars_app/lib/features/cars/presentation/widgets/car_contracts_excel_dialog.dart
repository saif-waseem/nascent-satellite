import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../data/car_contracts_repository.dart';

class CarContractsExcelDialog extends HookConsumerWidget {
  const CarContractsExcelDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF107C41).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.table_chart, color: Color(0xFF107C41), size: 28),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إكسل عقود السيارات',
                            style: GoogleFonts.amiri(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.lapis),
                          ),
                          Text(
                            'استيراد وتصدير العقود بسرعة وسهولة',
                            style: GoogleFonts.cairo(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.black38),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: AppColors.clayDark, height: 32),

              // Export Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.clay.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.clayDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.file_download_outlined, color: Color(0xFF107C41)),
                        const SizedBox(width: 8),
                        Text(
                          'تصدير العقود إلى إكسل (CSV)',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.lapis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'تصدير كافة العقود المسجلة بترميز UTF-8 متوافق 100% مع Microsoft Excel واللغة العربية.',
                      style: GoogleFonts.cairo(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _exportContracts(context, ref, tenantId, 'ar'),
                            icon: const Icon(Icons.download, size: 18),
                            label: Text('تصدير بالعربية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 13)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF107C41),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _exportContracts(context, ref, tenantId, 'en'),
                            icon: const Icon(Icons.download, size: 18),
                            label: Text('Export (English)', style: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 13)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF107C41),
                              side: const BorderSide(color: Color(0xFF107C41)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Import Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.clay.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.clayDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.file_upload_outlined, color: AppColors.lapis),
                        const SizedBox(width: 8),
                        Text(
                          'استيراد العقود من ملف إكسل (CSV)',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.lapis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'اختر ملف إكسل أو CSV يحتوي على بيانات العقود لإضافتها مباشرة إلى البرنامج وقاعدة البيانات.',
                      style: GoogleFonts.cairo(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _importContracts(context, ref, tenantId),
                        icon: const Icon(Icons.upload_file, size: 18),
                        label: Text('اختيار ملف واستيراد', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.lapis,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportContracts(BuildContext context, WidgetRef ref, String tenantId, String lang) async {
    try {
      final repo = ref.read(carContractsRepositoryProvider);
      final contracts = repo.getLocalContracts(tenantId);

      if (contracts.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد عقود مسجلة للتصدير'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final csvData = UniversalExcelService.exportCarContractsToCsv(contracts, lang: lang);
      final bytes = utf8.encode(csvData);
      final fileName = 'car_contracts_${DateTime.now().millisecondsSinceEpoch}.csv';

      // 1. Try file picker save
      try {
        final savedUri = await FilePicker.saveFile(
          fileName: fileName,
          bytes: Uint8List.fromList(bytes),
        );
        if (savedUri != null) {
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ تم حفظ ملف الإكسل بنجاح!'), backgroundColor: Colors.green),
            );
          }
          return;
        }
      } catch (_) {}

      // 2. Fallback: Save to Documents/Downloads
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم حفظ الملف في: ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء التصدير: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importContracts(BuildContext context, WidgetRef ref, String tenantId) async {
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
        final parsed = UniversalExcelService.parseCarContractsFromCsv(csvString, tenantId);

        if (parsed.isEmpty) {
          throw Exception('لم يتم العثور على عقود صالحة في الملف المختار');
        }

        // Convert parsed maps to CarContractModel instances
        final List<CarContractModel> newContracts = [];
        for (final item in parsed) {
          newContracts.add(CarContractModel(
            id: const Uuid().v4(),
            tenantId: tenantId,
            sellerName: item['sellerName'] ?? '',
            sellerPhone: item['sellerPhone'],
            sellerAddress: item['sellerAddress'],
            buyerName: item['buyerName'] ?? '',
            buyerPhone: item['buyerPhone'],
            buyerAddress: item['buyerAddress'],
            carType: item['carType'] ?? 'خصوصي',
            carModelName: item['carModelName'] ?? 'صالون',
            carYear: item['carYear'],
            carPlate: item['carPlate'],
            carColor: item['carColor'],
            carChassis: item['carChassis'],
            priceTotal: (item['priceTotal'] as num?)?.toDouble() ?? 0.0,
            pricePaid: (item['pricePaid'] as num?)?.toDouble() ?? 0.0,
            priceRemaining: (item['priceRemaining'] as num?)?.toDouble() ?? 0.0,
            notes: item['notes'],
            createdAt: DateTime.now(),
          ));
        }

        // Save batch
        final repo = ref.read(carContractsRepositoryProvider);
        await repo.batchSaveContracts(tenantId, newContracts);

        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🎉 تم استيراد ${newContracts.length} عقد بنجاح!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ أثناء الاستيراد: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
