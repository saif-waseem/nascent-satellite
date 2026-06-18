import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../data/car_contracts_repository.dart';
import 'car_contract_print_preview.dart';

class CarContractFormScreen extends HookConsumerWidget {
  const CarContractFormScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    final sellerName = useTextEditingController();
    final sellerId = useTextEditingController();
    final sellerAddress = useTextEditingController();
    final sellerPhone = useTextEditingController();
    final sellerMukhtar = useTextEditingController();

    final buyerName = useTextEditingController();
    final buyerId = useTextEditingController();
    final buyerAddress = useTextEditingController();
    final buyerPhone = useTextEditingController();
    final buyerMukhtar = useTextEditingController();

    final carType = useState('خصوصي');
    final carModelName = useTextEditingController();
    final carYear = useTextEditingController();
    final carPlate = useTextEditingController();
    final carColor = useTextEditingController();
    final carAnnualId = useTextEditingController();
    final carChassis = useTextEditingController();

    final priceTotal = useTextEditingController(text: '0');
    final pricePaid = useTextEditingController(text: '0');
    final priceRemaining = useTextEditingController(text: '0');
    
    final notes = useTextEditingController();
    final isSubmitting = useState(false);

    useEffect(() {
      void calcRemaining() {
        final total = double.tryParse(priceTotal.text) ?? 0.0;
        final paid = double.tryParse(pricePaid.text) ?? 0.0;
        final remaining = total - paid;
        priceRemaining.text = remaining.toStringAsFixed(0);
      }
      priceTotal.addListener(calcRemaining);
      pricePaid.addListener(calcRemaining);
      return () {
        priceTotal.removeListener(calcRemaining);
        pricePaid.removeListener(calcRemaining);
      };
    }, [priceTotal, pricePaid]);

    Future<void> saveContract() async {
      if (!formKey.currentState!.validate()) return;
      isSubmitting.value = true;
      try {
        final contract = CarContractModel(
          id: const Uuid().v4(),
          tenantId: tenantId,
          sellerName: sellerName.text.trim(),
          sellerId: sellerId.text.trim(),
          sellerAddress: sellerAddress.text.trim(),
          sellerPhone: sellerPhone.text.trim(),
          sellerMukhtar: sellerMukhtar.text.trim(),
          buyerName: buyerName.text.trim(),
          buyerId: buyerId.text.trim(),
          buyerAddress: buyerAddress.text.trim(),
          buyerPhone: buyerPhone.text.trim(),
          buyerMukhtar: buyerMukhtar.text.trim(),
          carType: carType.value,
          carModelName: carModelName.text.trim(),
          carYear: carYear.text.trim(),
          carPlate: carPlate.text.trim(),
          carColor: carColor.text.trim(),
          carAnnualId: carAnnualId.text.trim(),
          carChassis: carChassis.text.trim(),
          priceTotal: double.tryParse(priceTotal.text) ?? 0,
          pricePaid: double.tryParse(pricePaid.text) ?? 0,
          priceRemaining: double.tryParse(priceRemaining.text) ?? 0,
          notes: notes.text.trim(),
          createdAt: DateTime.now(),
        );

        await ref.read(carContractsRepositoryProvider).saveContract(tenantId, contract);
        ref.invalidate(carContractsProvider(tenantId));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ العقد بنجاح')));
          Navigator.push(context, MaterialPageRoute(builder: (_) => CarContractPrintPreview(contract: contract)));
        }

        sellerName.clear(); sellerId.clear(); sellerAddress.clear(); sellerPhone.clear(); sellerMukhtar.clear();
        buyerName.clear(); buyerId.clear(); buyerAddress.clear(); buyerPhone.clear(); buyerMukhtar.clear();
        carModelName.clear(); carYear.clear(); carPlate.clear(); carColor.clear(); carAnnualId.clear(); carChassis.clear();
        priceTotal.text = '0'; pricePaid.text = '0'; priceRemaining.text = '0'; notes.clear();

      } catch (e) {
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      } finally {
        isSubmitting.value = false;
      }
    }

    Widget buildSectionTitle(String title, IconData icon) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildSectionTitle('بيانات البائع', Icons.person_remove),
                          TextFormField(controller: sellerName, decoration: const InputDecoration(labelText: 'اسم البائع الثلاثي واللقب *'), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                          const SizedBox(height: 8),
                          TextFormField(controller: sellerId, decoration: const InputDecoration(labelText: 'رقم الهوية / البطاقة الوطنية')),
                          const SizedBox(height: 8),
                          TextFormField(controller: sellerAddress, decoration: const InputDecoration(labelText: 'محل السكن')),
                          const SizedBox(height: 8),
                          TextFormField(controller: sellerPhone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                          const SizedBox(height: 8),
                          TextFormField(controller: sellerMukhtar, decoration: const InputDecoration(labelText: 'اسم المختار')),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildSectionTitle('بيانات المشتري', Icons.person_add),
                          TextFormField(controller: buyerName, decoration: const InputDecoration(labelText: 'اسم المشتري الثلاثي واللقب *'), validator: (v) => v!.isEmpty ? 'مطلوب' : null),
                          const SizedBox(height: 8),
                          TextFormField(controller: buyerId, decoration: const InputDecoration(labelText: 'رقم الهوية / البطاقة الوطنية')),
                          const SizedBox(height: 8),
                          TextFormField(controller: buyerAddress, decoration: const InputDecoration(labelText: 'محل السكن')),
                          const SizedBox(height: 8),
                          TextFormField(controller: buyerPhone, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
                          const SizedBox(height: 8),
                          TextFormField(controller: buyerMukhtar, decoration: const InputDecoration(labelText: 'اسم المختار')),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSectionTitle('بيانات المركبة', Icons.directions_car),
                    Row(
                      children: [
                        Expanded(child: DropdownButtonFormField<String>(value: carType.value, decoration: const InputDecoration(labelText: 'نوع المركبة'), items: ['خصوصي', 'أجرة', 'حمل'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => carType.value = v!)),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: carModelName, decoration: const InputDecoration(labelText: 'موديل المركبة (الاسم) *'), validator: (v) => v!.isEmpty ? 'مطلوب' : null)),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: carYear, decoration: const InputDecoration(labelText: 'سنة الصنع'))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: carPlate, decoration: const InputDecoration(labelText: 'رقم اللوحة والمرور'))),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: carColor, decoration: const InputDecoration(labelText: 'اللون'))),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: carAnnualId, decoration: const InputDecoration(labelText: 'رقم السنوية'))),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: carChassis, decoration: const InputDecoration(labelText: 'رقم الشاصي'))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    buildSectionTitle('المالية والملاحظات', Icons.attach_money),
                    Row(
                      children: [
                        Expanded(child: TextFormField(controller: priceTotal, decoration: const InputDecoration(labelText: 'مبلغ البيع الكلي'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: pricePaid, decoration: const InputDecoration(labelText: 'المبلغ المدفوع (المقبوض)'), keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: TextFormField(controller: priceRemaining, decoration: const InputDecoration(labelText: 'المبلغ المتبقي'), readOnly: true, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظات إضافية (شروط العقد، الخ)'), maxLines: 3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: isSubmitting.value ? null : saveContract,
                icon: isSubmitting.value ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.save),
                label: const Text('حفظ وإصدار العقد', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
