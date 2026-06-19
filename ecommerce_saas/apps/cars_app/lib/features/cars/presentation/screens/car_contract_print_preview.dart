import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/settings_provider.dart';

class CarContractPrintPreview extends ConsumerWidget {
  final CarContractModel contract;
  const CarContractPrintPreview({super.key, required this.contract});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final date = contract.createdAt;
    final dateStr = '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
    final timeStr = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final serial = contract.id.length > 6 ? contract.id.substring(contract.id.length - 6) : contract.id;
    
    String formatNumber(double num) {
      return num.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    }

    const tblBorder = TableBorder.symmetric(
      inside: BorderSide(color: Colors.black, width: 0.5),
      outside: BorderSide(color: Colors.black, width: 1),
    );

    Widget tblHeader(String text) => Container(
          color: const Color(0xFFeeeeee),
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
        );

    Widget tblCell(String text, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color, fontFamily: 'Cairo')),
        );

    Widget secTitle(String title) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontFamily: 'Cairo')),
        );

    final printContent = Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ──────────────────────────────────────────────
            Table(
              children: [
                TableRow(children: [
                  // Office Info (right)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(settings.officeName, style: GoogleFonts.amiri(fontSize: 18, color: const Color(0xFFc62828), fontWeight: FontWeight.bold)),
                      const Text('لاستيراد وتسجيل السيارات', style: TextStyle(fontSize: 10, fontFamily: 'Cairo')),
                      const Text('عقود مرورية - مكاتبات', style: TextStyle(fontSize: 10, fontFamily: 'Cairo')),
                      if (settings.managerName.isNotEmpty)
                        Text('بإدارة: ${settings.managerName}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                    ]),
                  ),
                  // Logo (center)
                  Center(
                    child: settings.logoImagePath != null
                        ? Image.file(File(settings.logoImagePath!), height: 70, width: 100, fit: BoxFit.contain)
                        : const Text('🚗', style: TextStyle(fontSize: 40)),
                  ),
                  // Contact (left)
                  Align(
                    alignment: Alignment.topLeft,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (settings.licenseNumber.isNotEmpty) Text('رقم الإجازة: ${settings.licenseNumber}', style: const TextStyle(fontSize: 10, fontFamily: 'Cairo')),
                      if (settings.officeAddress.isNotEmpty) Text('العنوان: ${settings.officeAddress}', style: const TextStyle(fontSize: 10, fontFamily: 'Cairo')),
                      if (settings.phone.isNotEmpty) Text('هاتف: ${settings.phone}', style: const TextStyle(fontSize: 10, fontFamily: 'Cairo')),
                    ]),
                  ),
                ]),
              ],
            ),
            const Divider(color: AppColors.gold, thickness: 2),
            // Serial / Date / Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('التسلسل: $serial', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                Text('تاريخ: $dateStr', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
                Text('الوقت: $timeStr', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Cairo')),
              ],
            ),
            const SizedBox(height: 8),
            // ── SELLER TABLE ────────────────────────────────────────
            secTitle('معلومات البائع'),
            Table(border: tblBorder, columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1.5), 3: FlexColumnWidth(1.5), 4: FlexColumnWidth(1.5)}, children: [
              TableRow(children: [tblHeader('الاسم الثلاثي واللقب'), tblHeader('السكن'), tblHeader('رقم الهوية'), tblHeader('رقم الهاتف'), tblHeader('اسم المختار')]),
              TableRow(children: [tblCell(contract.sellerName), tblCell(contract.sellerAddress ?? ''), tblCell(contract.sellerId ?? ''), tblCell(contract.sellerPhone ?? ''), tblCell(contract.sellerMukhtar ?? 'يجهل اسمه')]),
            ]),
            // Seller Photo
            if (contract.sellerPhotoUrl != null && File(contract.sellerPhotoUrl!).existsSync())
              Padding(padding: const EdgeInsets.only(top: 4), child: Image.file(File(contract.sellerPhotoUrl!), width: 60, height: 60, fit: BoxFit.cover)),
            const SizedBox(height: 8),
            // ── BUYER TABLE ─────────────────────────────────────────
            secTitle('معلومات المشتري'),
            Table(border: tblBorder, columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1.5), 3: FlexColumnWidth(1.5), 4: FlexColumnWidth(1.5)}, children: [
              TableRow(children: [tblHeader('الاسم الثلاثي واللقب'), tblHeader('السكن'), tblHeader('رقم الهوية'), tblHeader('رقم الهاتف'), tblHeader('اسم المختار')]),
              TableRow(children: [tblCell(contract.buyerName), tblCell(contract.buyerAddress ?? ''), tblCell(contract.buyerId ?? ''), tblCell(contract.buyerPhone ?? ''), tblCell(contract.buyerMukhtar ?? 'يجهل اسمه')]),
            ]),
            // Buyer Photo
            if (contract.buyerPhotoUrl != null && File(contract.buyerPhotoUrl!).existsSync())
              Padding(padding: const EdgeInsets.only(top: 4), child: Image.file(File(contract.buyerPhotoUrl!), width: 60, height: 60, fit: BoxFit.cover)),
            const SizedBox(height: 10),
            // Contract Text
            Center(
              child: Text(
                'عقد هذا الاتفاق بين الطرفين كما يلي: باع الطرف الاول للطرف الثاني السيارة المفصلة أدناه:',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
              ),
            ),
            const SizedBox(height: 6),
            // ── CAR TABLE ───────────────────────────────────────────
            Table(border: tblBorder, children: [
              TableRow(children: [tblHeader('تصنيف السيارة'), tblHeader('اسم السيارة'), tblHeader('رقم اللوحة'), tblHeader('الموديل'), tblHeader('اللون'), tblHeader('رقم الشاصي')]),
              TableRow(children: [
                tblCell(contract.carType, bold: true),
                tblCell(contract.carModelName),
                tblCell(contract.carPlate ?? 'غير مسجل'),
                tblCell(contract.carYear ?? ''),
                tblCell(contract.carColor ?? ''),
                tblCell(contract.carChassis ?? 'بلا'),
              ]),
            ]),
            const SizedBox(height: 6),
            // ── PRICE TABLE ─────────────────────────────────────────
            Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.65,
                child: Table(border: tblBorder, children: [
                  TableRow(children: [tblHeader('سعر البيع الكلي'), tblHeader('المبلغ الواصل (المدفوع)'), tblHeader('المتبقي بذمة المشتري')]),
                  TableRow(children: [
                    tblCell(formatNumber(contract.priceTotal), bold: true),
                    tblCell(formatNumber(contract.pricePaid), bold: true),
                    tblCell(formatNumber(contract.priceRemaining), bold: true, color: Colors.red),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            // Notes + Disclaimer
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: Colors.black), borderRadius: BorderRadius.circular(4)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('الملاحظات: ${contract.notes?.isNotEmpty == true ? contract.notes : 'لا يوجد'}', style: const TextStyle(fontSize: 9, fontFamily: 'Cairo')),
                const SizedBox(height: 4),
                const Text(
                  'تنبيه وإخلاء مسؤولية: المكتب غير مسؤول عن إبراز المستمسكات المزورة للطرفين أن وجد ذلك لأن الطرفان متعارفان ومتفقان خارج المكتب والمكتب وسيط وليس كفيل. يتعهد الطرفان بصحة المعلومات أعلاه.',
                  style: TextStyle(fontSize: 9, fontFamily: 'Cairo'),
                ),
              ]),
            ),
            const SizedBox(height: 28),
            // ── SIGNATURES ──────────────────────────────────────────
            Row(
              children: [
                Expanded(child: Column(children: [
                  const Divider(color: Colors.black, thickness: 1),
                  const SizedBox(height: 4),
                  const Text('توقيع وبصمة البائع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                  Text(contract.sellerName, style: const TextStyle(fontSize: 10, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                ])),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [
                  const Divider(color: Colors.black, thickness: 1),
                  const SizedBox(height: 4),
                  const Text('إدارة المكتب', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                  Text(settings.managerName.isNotEmpty ? settings.managerName : settings.officeName, style: const TextStyle(fontSize: 10, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                ])),
                const SizedBox(width: 16),
                Expanded(child: Column(children: [
                  const Divider(color: Colors.black, thickness: 1),
                  const SizedBox(height: 4),
                  const Text('توقيع وبصمة المشتري', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                  const SizedBox(height: 40),
                  Text(contract.buyerName, style: const TextStyle(fontSize: 10, fontFamily: 'Cairo'), textAlign: TextAlign.center),
                ])),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Colors.black),
            const Center(child: Text('تم الإنشاء بواسطة المهندس سيف وسيم', style: TextStyle(fontSize: 9, fontFamily: 'Cairo', color: Colors.black54))),
          ],
        ),
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFf0f0f0),
        appBar: AppBar(
          title: Text('معاينة العقد - ${contract.carModelName}', style: GoogleFonts.amiri()),
          backgroundColor: AppColors.lapis,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'طباعة',
              onPressed: () {
                // On Android: use system share/print
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('استخدم زر المشاركة لإرسال أو طباعة العقد')),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(elevation: 4, child: printContent),
        ),
      ),
    );
  }
}
