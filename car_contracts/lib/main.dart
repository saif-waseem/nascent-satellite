import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_models/shared_models.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const CarContractsApp());
}

class CarContractsApp extends StatelessWidget {
  const CarContractsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'إدارة عقود ومعارض السيارات',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
      ),
      home: const CarContractsDashboardScreen(),
    );
  }
}

class CarContractsDashboardScreen extends StatefulWidget {
  const CarContractsDashboardScreen({super.key});

  @override
  State<CarContractsDashboardScreen> createState() =>
      _CarContractsDashboardScreenState();
}

class _CarContractsDashboardScreenState
    extends State<CarContractsDashboardScreen> {
  final List<CarContractModel> _contracts = [
    CarContractModel(
      id: '1',
      tenantId: 'mahmodcar',
      sellerName: 'أحمد علي حسن',
      sellerPhone: '07701234567',
      sellerAddress: 'بغداد - الكرادة',
      buyerName: 'سيف وسيم كريم',
      buyerPhone: '07809876543',
      buyerAddress: 'بغداد - المنصور',
      carType: 'خصوصي',
      carModelName: 'تويوتا كامري',
      carYear: '2023',
      carPlate: '12345 بغداد',
      carColor: 'أبيض لؤلؤي',
      priceTotal: 28500000,
      pricePaid: 20000000,
      priceRemaining: 8500000,
      notes: 'تم فحص السيارة بالكامل وتسليم السنوية',
      createdAt: DateTime.now(),
    ),
  ];

  Future<void> _exportContracts() async {
    try {
      final csvData = UniversalExcelService.exportCarContractsToCsv(
        _contracts,
        lang: 'ar',
      );
      final bytes = utf8.encode(csvData);
      final fileName =
          'car_contracts_${DateTime.now().millisecondsSinceEpoch}.csv';

      if (kIsWeb) {
        // Web: use file_picker save (not supported) — show snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('التصدير غير مدعوم على الويب في هذا الإصدار'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final savedUri = await FilePicker.saveFile(
        fileName: fileName,
        bytes: Uint8List.fromList(bytes),
      );

      if (savedUri == null) return; // user cancelled

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصدير العقود بنجاح! 🚗'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء التصدير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importContracts() async {
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
        final parsed = UniversalExcelService.parseCarContractsFromCsv(
          csvString,
          'mahmodcar',
        );

        if (parsed.isEmpty) {
          throw Exception('لم يتم العثور على عقود صالحة في الملف');
        }

        setState(() {
          for (var p in parsed) {
            _contracts.add(
              CarContractModel(
                id: const Uuid().v4(),
                tenantId: 'mahmodcar',
                sellerName: p['sellerName'] ?? '',
                sellerPhone: p['sellerPhone'] ?? '',
                sellerAddress: p['sellerAddress'] ?? '',
                buyerName: p['buyerName'] ?? '',
                buyerPhone: p['buyerPhone'] ?? '',
                buyerAddress: p['buyerAddress'] ?? '',
                carType: p['carType'] ?? 'خصوصي',
                carModelName: p['carModelName'] ?? '',
                carYear: p['carYear'] ?? '',
                carPlate: p['carPlate'] ?? '',
                carColor: p['carColor'] ?? '',
                carChassis: p['carChassis'],
                priceTotal: (p['priceTotal'] ?? 0).toDouble(),
                pricePaid: (p['pricePaid'] ?? 0).toDouble(),
                priceRemaining: (p['priceRemaining'] ?? 0).toDouble(),
                notes: p['notes'],
                createdAt: DateTime.now(),
              ),
            );
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم استيراد ${parsed.length} عقد سيارة بنجاح! ✅'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء الاستيراد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('عقود ومعارض السيارات - السجل العام'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined, color: Colors.green),
            onPressed: _exportContracts,
            tooltip: 'تصدير العقود إلى إكسل',
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, color: Colors.blue),
            onPressed: _importContracts,
            tooltip: 'استيراد عقود من إكسل',
          ),
        ],
      ),
      body: _contracts.isEmpty
          ? const Center(child: Text('لا توجد عقود مسجلة حالياً'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _contracts.length,
              itemBuilder: (context, index) {
                final c = _contracts[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.directions_car_filled,
                              color: Colors.blueGrey,
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${c.carModelName} (${c.carYear ?? "عام"})',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                c.carType,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '👤 البائع: ${c.sellerName}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '🤝 المشتري: ${c.buyerName}',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '💰 الإجمالي: ${c.priceTotal.toStringAsFixed(0)} د.ع',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '💵 الواصل: ${c.pricePaid.toStringAsFixed(0)} د.ع',
                                style: const TextStyle(color: Colors.green),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '⏳ المتبقي: ${c.priceRemaining.toStringAsFixed(0)} د.ع',
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
