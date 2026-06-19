import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_models/shared_models.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../data/car_contracts_repository.dart';
import 'car_contract_print_preview.dart';

class CarContractFormScreen extends HookConsumerWidget {
  final CarContractModel? editContract;
  const CarContractFormScreen({super.key, this.editContract});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final isSubmitting = useState(false);

    // Seller fields
    final sellerName = useTextEditingController(text: editContract?.sellerName ?? '');
    final sellerId = useTextEditingController(text: editContract?.sellerId ?? '');
    final sellerAddress = useTextEditingController(text: editContract?.sellerAddress ?? '');
    final sellerPhone = useTextEditingController(text: editContract?.sellerPhone ?? '');
    final sellerMukhtar = useTextEditingController(text: editContract?.sellerMukhtar ?? '');
    final sellerPhotoPath = useState<String?>(editContract?.sellerPhotoUrl);

    // Buyer fields
    final buyerName = useTextEditingController(text: editContract?.buyerName ?? '');
    final buyerId = useTextEditingController(text: editContract?.buyerId ?? '');
    final buyerAddress = useTextEditingController(text: editContract?.buyerAddress ?? '');
    final buyerPhone = useTextEditingController(text: editContract?.buyerPhone ?? '');
    final buyerMukhtar = useTextEditingController(text: editContract?.buyerMukhtar ?? '');
    final buyerPhotoPath = useState<String?>(editContract?.buyerPhotoUrl);

    // Car fields
    final carType = useState(editContract?.carType ?? 'خصوصي');
    final carModelName = useTextEditingController(text: editContract?.carModelName ?? '');
    final carYear = useTextEditingController(text: editContract?.carYear ?? '');
    final carPlate = useTextEditingController(text: editContract?.carPlate ?? '');
    final carColor = useTextEditingController(text: editContract?.carColor ?? '');
    final carAnnualId = useTextEditingController(text: editContract?.carAnnualId ?? '');
    final carChassis = useTextEditingController(text: editContract?.carChassis ?? '');

    // Price
    final priceTotal = useTextEditingController(text: editContract?.priceTotal.toStringAsFixed(0) ?? '0');
    final pricePaid = useTextEditingController(text: editContract?.pricePaid.toStringAsFixed(0) ?? '0');
    final priceRemaining = useTextEditingController(text: editContract?.priceRemaining.toStringAsFixed(0) ?? '0');
    final notes = useTextEditingController(text: editContract?.notes ?? '');

    useEffect(() {
      void calc() {
        final total = double.tryParse(priceTotal.text) ?? 0;
        final paid = double.tryParse(pricePaid.text) ?? 0;
        priceRemaining.text = (total - paid).toStringAsFixed(0);
      }
      priceTotal.addListener(calc);
      pricePaid.addListener(calc);
      return () {
        priceTotal.removeListener(calc);
        pricePaid.removeListener(calc);
      };
    }, [priceTotal, pricePaid]);

    Future<void> pickImage(ValueNotifier<String?> target) async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (picked != null) target.value = picked.path;
    }

    void clearForm() {
      sellerName.clear(); sellerId.clear(); sellerAddress.clear(); sellerPhone.clear(); sellerMukhtar.clear();
      buyerName.clear(); buyerId.clear(); buyerAddress.clear(); buyerPhone.clear(); buyerMukhtar.clear();
      carModelName.clear(); carYear.clear(); carPlate.clear(); carColor.clear(); carAnnualId.clear(); carChassis.clear();
      priceTotal.text = '0'; pricePaid.text = '0'; priceRemaining.text = '0'; notes.clear();
      sellerPhotoPath.value = null; buyerPhotoPath.value = null;
      carType.value = 'خصوصي';
    }

    Future<void> save({bool clearAfter = false}) async {
      if (!formKey.currentState!.validate()) return;
      isSubmitting.value = true;
      try {
        final contract = CarContractModel(
          id: editContract?.id ?? const Uuid().v4(),
          tenantId: tenantId.isEmpty ? 'local_default' : tenantId,
          sellerName: sellerName.text.trim(),
          sellerId: sellerId.text.trim(),
          sellerAddress: sellerAddress.text.trim(),
          sellerPhone: sellerPhone.text.trim(),
          sellerMukhtar: sellerMukhtar.text.trim().isEmpty ? 'يجهل اسمه' : sellerMukhtar.text.trim(),
          sellerPhotoUrl: sellerPhotoPath.value,
          buyerName: buyerName.text.trim(),
          buyerId: buyerId.text.trim(),
          buyerAddress: buyerAddress.text.trim(),
          buyerPhone: buyerPhone.text.trim(),
          buyerMukhtar: buyerMukhtar.text.trim().isEmpty ? 'يجهل اسمه' : buyerMukhtar.text.trim(),
          buyerPhotoUrl: buyerPhotoPath.value,
          carType: carType.value,
          carModelName: carModelName.text.trim(),
          carYear: carYear.text.trim(),
          carPlate: carPlate.text.trim().isEmpty ? 'غير مسجل' : carPlate.text.trim(),
          carColor: carColor.text.trim(),
          carAnnualId: carAnnualId.text.trim(),
          carChassis: carChassis.text.trim().isEmpty ? 'بلا' : carChassis.text.trim(),
          priceTotal: double.tryParse(priceTotal.text) ?? 0,
          pricePaid: double.tryParse(pricePaid.text) ?? 0,
          priceRemaining: double.tryParse(priceRemaining.text) ?? 0,
          notes: notes.text.trim(),
          createdAt: editContract?.createdAt ?? DateTime.now(),
        );
        await ref.read(carContractsRepositoryProvider).saveContract(contract.tenantId, contract);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم حفظ العقد بنجاح'), backgroundColor: Colors.green),
          );
          await Navigator.push(context, MaterialPageRoute(builder: (_) => CarContractPrintPreview(contract: contract)));
        }
        if (clearAfter) clearForm();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
        }
      } finally {
        isSubmitting.value = false;
      }
    }

    Widget sectionTitle(String title) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Text(title, style: GoogleFonts.amiri(fontSize: 18, color: AppColors.terracotta, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              const Expanded(child: Divider(color: AppColors.clayDark)),
            ],
          ),
        );

    Widget field(String label, TextEditingController ctrl, {bool required = false, String? hint, TextInputType? type, bool readOnly = false, Color? textColor}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: ctrl,
            readOnly: readOnly,
            keyboardType: type,
            style: TextStyle(fontFamily: 'Cairo', color: textColor),
            inputFormatters: type == TextInputType.number ? [FilteringTextInputFormatter.digitsOnly] : null,
            decoration: InputDecoration(
              labelText: label + (required ? ' *' : ''),
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.black38, fontSize: 12),
            ),
            validator: required ? (v) => (v == null || v.isEmpty) ? 'مطلوب' : null : null,
          ),
        );

    Widget photoField(String label, ValueNotifier<String?> path) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.lapisDark, fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => pickImage(path),
                  icon: const Icon(Icons.photo_library, size: 16),
                  label: Text('اختر صورة', style: GoogleFonts.cairo(fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.lapisDark, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                ),
                if (path.value != null) ...[
                  const SizedBox(width: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(File(path.value!), width: 60, height: 60, fit: BoxFit.cover),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
          ],
        );

    Widget formSection(String title, List<Widget> children) => Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: const Border(right: BorderSide(color: AppColors.lapis, width: 4)),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [sectionTitle(title), ...children]),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          children: [
            // Seller & Buyer in 2 columns
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: formSection('بيانات البائع', [
                    field('اسم البائع الثلاثي واللقب', sellerName, required: true),
                    field('رقم الهوية / البطاقة الوطنية', sellerId),
                    field('محل السكن', sellerAddress),
                    field('رقم الهاتف', sellerPhone, type: TextInputType.phone),
                    field('اسم المختار', sellerMukhtar, hint: 'يجهل اسمه'),
                    photoField('صورة البائع', sellerPhotoPath),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: formSection('بيانات المشتري', [
                    field('اسم المشتري الثلاثي واللقب', buyerName, required: true),
                    field('رقم الهوية / البطاقة الوطنية', buyerId),
                    field('محل السكن', buyerAddress),
                    field('رقم الهاتف', buyerPhone, type: TextInputType.phone),
                    field('اسم المختار', buyerMukhtar, hint: 'يجهل اسمه'),
                    photoField('صورة المشتري', buyerPhotoPath),
                  ]),
                ),
              ],
            ),
            // Car Section
            formSection('بيانات المركبة', [
              Row(children: [
                Expanded(child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: carType.value,
                    decoration: const InputDecoration(labelText: 'نوع المركبة'),
                    items: ['خصوصي', 'أجرة', 'إنشائية', 'حمل', 'دراجة']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.cairo())))
                        .toList(),
                    onChanged: (v) => carType.value = v!,
                  ),
                )),
                const SizedBox(width: 12),
                Expanded(child: field('اسم السيارة', carModelName, required: true)),
                const SizedBox(width: 12),
                Expanded(child: field('الموديل (السنة)', carYear)),
              ]),
              Row(children: [
                Expanded(child: field('رقم اللوحة والمرور', carPlate, hint: 'بغداد 12345...')),
                const SizedBox(width: 12),
                Expanded(child: field('اللون', carColor)),
                const SizedBox(width: 12),
                Expanded(child: field('رقم السنوية', carAnnualId)),
                const SizedBox(width: 12),
                Expanded(child: field('رقم الشاصي', carChassis, hint: 'بلا')),
              ]),
            ]),
            // Finance Section
            formSection('المالية والملاحظات', [
              Row(children: [
                Expanded(child: field('مبلغ البيع الكلي', priceTotal, type: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: field('المبلغ المدفوع (المقبوض)', pricePaid, type: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: field('المبلغ المتبقي', priceRemaining, readOnly: true, textColor: Colors.red)),
              ]),
              field('ملاحظات إضافية (شروط العقد)', notes),
            ]),
            // Disclaimer Note
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: const Color(0xFFfff3cd),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFffeeba)),
              ),
              child: Text(
                'المكتب غير مسؤول عن إبراز المستمسكات المزورة للطرفين أن وجد ذلك لأن الطرفان متعارفان ومتفقان خارج المكتب والمكتب وسيط وليس كفيل.',
                style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF856404)),
                textAlign: TextAlign.center,
              ),
            ),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isSubmitting.value ? null : () => save(clearAfter: false),
                    icon: isSubmitting.value ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                    label: Text('حفظ', style: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 15)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.lapis, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isSubmitting.value ? null : () => save(clearAfter: true),
                    icon: const Icon(Icons.add_task),
                    label: Text('حفظ وآخر', style: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 15)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.lapisDark, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
