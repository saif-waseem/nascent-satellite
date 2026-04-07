import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:go_router/go_router.dart';

class CouponFormScreen extends HookConsumerWidget {
  final CouponModel? initialCoupon;
  const CouponFormScreen({super.key, this.initialCoupon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final codeController = useTextEditingController(text: initialCoupon?.code);
    final valueController = useTextEditingController(text: initialCoupon?.value.toString());
    final minPurchaseController = useTextEditingController(text: initialCoupon?.minPurchase.toString() ?? '0');
    final maxUsageController = useTextEditingController(text: initialCoupon?.maxUsage.toString() ?? '100');
    
    final discountType = useState(initialCoupon?.type ?? DiscountType.percentage);
    final isActive = useState(initialCoupon?.isActive ?? true);

    return Scaffold(
      appBar: AppBar(
        title: Text(initialCoupon == null ? AppStrings.get('add_coupon', lang) : AppStrings.get('edit_coupon', lang)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.get('coupon_details', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 24),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: AppStrings.get('coupon_code', lang), 
                border: const OutlineInputBorder(),
                hintText: 'e.g. SAVE20',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            Text(AppStrings.get('discount_type', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<DiscountType>(
                    title: const Text('Percent (%)'),
                    value: DiscountType.percentage,
                    groupValue: discountType.value,
                    onChanged: (v) => discountType.value = v!,
                  ),
                ),
                Expanded(
                  child: RadioListTile<DiscountType>(
                    title: const Text('Fixed (IQD)'),
                    value: DiscountType.fixed,
                    groupValue: discountType.value,
                    onChanged: (v) => discountType.value = v!,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: valueController,
              decoration: InputDecoration(
                labelText: AppStrings.get('discount_value', lang), 
                border: const OutlineInputBorder(),
                suffixText: discountType.value == DiscountType.percentage ? '%' : 'IQD',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(AppStrings.get('usage_limits', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: minPurchaseController,
              decoration: InputDecoration(
                labelText: AppStrings.get('min_purchase', lang), 
                border: const OutlineInputBorder(),
                suffixText: 'IQD',
                helperText: AppStrings.get('min_purchase_helper', lang),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: maxUsageController,
              decoration: InputDecoration(
                labelText: AppStrings.get('max_usage', lang), 
                border: const OutlineInputBorder(),
                helperText: AppStrings.get('max_usage_helper', lang),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: Text(AppStrings.get('is_active', lang)),
              subtitle: Text(AppStrings.get('is_active_helper', lang)),
              value: isActive.value,
              onChanged: (v) => isActive.value = v,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () async {
                  final tenantId = ref.read(currentTenantIdProvider);
                  final code = codeController.text.trim().toUpperCase();
                  
                  if (code.isEmpty || valueController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('fill_fields', lang))));
                    return;
                  }

                  final coupon = CouponModel(
                    id: initialCoupon?.id ?? '', // Firestore will assign if empty
                    code: code,
                    type: discountType.value,
                    value: double.tryParse(valueController.text) ?? 0.0,
                    minPurchase: double.tryParse(minPurchaseController.text) ?? 0.0,
                    maxUsage: int.tryParse(maxUsageController.text) ?? 999,
                    isActive: isActive.value,
                    usageCount: initialCoupon?.usageCount ?? 0,
                  );

                  if (initialCoupon == null) {
                    await ref.read(adminFirestoreServiceProvider).addCoupon(tenantId, coupon);
                  } else {
                    await ref.read(adminFirestoreServiceProvider).updateCoupon(tenantId, coupon);
                  }
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('success_msg', lang))));
                    context.pop();
                  }
                },
                child: Text(initialCoupon == null ? AppStrings.get('create_coupon', lang) : AppStrings.get('save_changes', lang)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
