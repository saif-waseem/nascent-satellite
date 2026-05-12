import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:super_admin/core/localization/resources/app_strings.dart';
import 'package:super_admin/features/shared/providers.dart';
import 'package:shared_models/shared_models.dart';
import 'package:intl/intl.dart';

class SubscriptionDialog extends HookConsumerWidget {
  final TenantModel tenant;
  final String lang;
  const SubscriptionDialog({super.key, required this.tenant, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthsController = useTextEditingController(text: '12');
    final codeController = useTextEditingController(text: 'ACT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final posCodeController = useTextEditingController(text: 'POS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');

    final currentExpiry = tenant.expiryDate ?? DateTime.now();
    final newExpiry = useState(currentExpiry.add(const Duration(days: 365)));

    void updateNewExpiry(String val) {
      final months = int.tryParse(val) ?? 0;
      final now = DateTime.now();
      final startDate = (tenant.expiryDate == null || tenant.expiryDate!.isBefore(now)) 
          ? now 
          : tenant.expiryDate!;
      newExpiry.value = startDate.add(Duration(days: months * 30));
    }

    return AlertDialog(
      title: Text('${AppStrings.get('manage_subscription', lang)} - ${tenant.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Store Section ---
            _TitleSection(title: lang == 'ar' ? 'تفعيل المتجر' : 'Store Activation'),
            Text('${AppStrings.get('expiry', lang)} (Current): ${tenant.expiryDate != null ? DateFormat('yyyy/MM/dd').format(tenant.expiryDate!) : 'Permanent / None'}'),
            const SizedBox(height: 8),
            Row(
              children: [
                 Expanded(
                   child: TextField(
                     controller: monthsController,
                     onChanged: updateNewExpiry,
                     decoration: InputDecoration(
                       labelText: AppStrings.get('renewal_period', lang),
                       suffixText: AppStrings.get('months', lang),
                       hintText: 'مثال: 12 أو -3 للتنقيص',
                     ),
                     keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
                   ),
                 ),
                 const SizedBox(width: 8),
                 ElevatedButton(
                   onPressed: () async {
                     final months = int.tryParse(monthsController.text) ?? 1;
                     await ref.read(superAdminFirestoreServiceProvider).activateSubscription(tenant.id, months, codeController.text.trim());
                     if (context.mounted) Navigator.pop(context);
                   },
                   child: Text(AppStrings.get('activate', lang)),
                 )
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            _TitleSection(title: lang == 'ar' ? 'تفعيل دائمي' : 'Permanent Activation'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: codeController,
                    decoration: InputDecoration(labelText: 'كود المتجر'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    await ref.read(superAdminFirestoreServiceProvider).activateStorePermanently(tenant.id, codeController.text.trim());
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text('متجر دائم'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: posCodeController,
                    decoration: InputDecoration(labelText: 'كود المبيعات (POS)'),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () async {
                    await ref.read(superAdminFirestoreServiceProvider).activatePosPermanently(tenant.id, posCodeController.text.trim());
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text('مبيعات دائم'),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.get('cancel', lang)),
        ),
      ],
    );
  }
}

class _TitleSection extends StatelessWidget {
  final String title;
  const _TitleSection({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
    );
  }
}
