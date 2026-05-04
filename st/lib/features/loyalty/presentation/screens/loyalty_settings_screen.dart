import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:store_admin/features/shared/widgets/admin_drawer.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/core/utils/formatters.dart';
import 'package:shared_models/shared_models.dart';

class LoyaltySettingsScreen extends ConsumerWidget {
  const LoyaltySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTenant = ref.watch(tenantProvider);
    final lang = ref.watch(appSettingsProvider).locale.languageCode;

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(title: Text(AppStrings.get('loyalty_settings', lang))),
      body: asyncTenant.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (tenant) {
          if (tenant == null) return const Center(child: Text('Store settings not found'));

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSettingItem(
                title: AppStrings.get('reg_bonus', lang),
                subtitle: AppStrings.get('points_desc', lang),
                value: '${tenant.registrationPoints} ${AppStrings.get('points', lang)}',
                icon: Icons.person_add_outlined,
                onTap: () => _showEditDialog(context, ref, tenant, 'registrationPoints', true, lang),
              ),
              const Divider(),
              _buildSettingItem(
                title: AppStrings.get('purchase_reward', lang),
                subtitle: AppStrings.get('points_desc', lang),
                value: '${(tenant.purchasePointsPercent * 100).toStringAsFixed(0)}%',
                icon: Icons.shopping_basket_outlined,
                onTap: () => _showEditDialog(context, ref, tenant, 'purchasePointsPercent', false, lang),
              ),
              _buildSettingItem(
                title: '${AppStrings.get('max_points', lang)} (${AppStrings.get('daily', lang)})',
                subtitle: AppStrings.get('loyalty_settings', lang),
                value: '${tenant.maxDailyPurchasePoints} ${AppStrings.get('points', lang)}',
                icon: Icons.timer_outlined,
                onTap: () => _showEditDialog(context, ref, tenant, 'maxDailyPurchasePoints', true, lang),
              ),
              const Divider(),
              _buildSettingItem(
                title: AppStrings.get('conversion_ratio', lang),
                subtitle: AppStrings.get('example_conversion', lang),
                value: '1 ${AppStrings.get('points', lang)} = ${formatCurrency(tenant.pointsToCurrencyRatio, lang: lang)}',
                icon: Icons.currency_exchange_outlined,
                onTap: () => _showEditDialog(context, ref, tenant, 'pointsToCurrencyRatio', false, lang),
              ),
              const SizedBox(height: 40),
              Text(AppStrings.get('settings', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              _buildSettingItem(
                title: AppStrings.get('shipping_cost', lang),
                subtitle: AppStrings.get('points_desc', lang),
                value: formatCurrency(tenant.shippingCost, lang: lang),
                icon: Icons.local_shipping_outlined,
                onTap: () => _showEditDialog(context, ref, tenant, 'shippingCost', false, lang),
              ),
              const Divider(),
              _buildSettingItem(
                title: AppStrings.get('sharing_bonus_title', lang),
                subtitle: AppStrings.get('sharing_bonus_subtitle', lang),
                value: '${tenant.sharesRewardPoints} ${AppStrings.get('points', lang)}',
                icon: Icons.share_outlined,
                onTap: () => _showEditDialog(context, ref, tenant, 'sharesRewardPoints', true, lang),
              ),
              _buildSettingItem(
                title: '${AppStrings.get('max_points', lang)} (${AppStrings.get('daily', lang)})',
                subtitle: AppStrings.get('loyalty_settings', lang),
                value: '${tenant.maxDailySharePoints} ${AppStrings.get('points', lang)}',
                icon: Icons.timer_outlined,
                onTap: () => _showEditDialog(context, ref, tenant, 'maxDailySharePoints', true, lang),
              ),
              const Divider(),
              _buildSettingItem(
                title: AppStrings.get('review_bonus_title', lang),
                subtitle: AppStrings.get('review_bonus_subtitle', lang),
                value: '${tenant.reviewRewardPoints} ${AppStrings.get('points', lang)}',
                icon: Icons.rate_review_outlined,
                onTap: () => _showEditDialog(context, ref, tenant, 'reviewRewardPoints', true, lang),
              ),
              _buildSettingItem(
                title: '${AppStrings.get('max_points', lang)} (${AppStrings.get('daily', lang)})',
                subtitle: AppStrings.get('loyalty_settings', lang),
                value: '${tenant.maxDailyReviewPoints} ${AppStrings.get('points', lang)}',
                icon: Icons.timer_outlined,
                onTap: () => _showEditDialog(context, ref, tenant, 'maxDailyReviewPoints', true, lang),
              ),
              const SizedBox(height: 40),
              Text(AppStrings.get('first_order_discount', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(AppStrings.get('first_order_discount', lang)),
                subtitle: Text(AppStrings.get('first_order_discount_desc', lang)),
                value: tenant.firstOrderDiscountEnabled,
                onChanged: (v) {
                  ref.read(adminFirestoreServiceProvider).updateTenant(tenant.copyWith(firstOrderDiscountEnabled: v));
                },
              ),
              if (tenant.firstOrderDiscountEnabled)
                _buildSettingItem(
                  title: '${AppStrings.get('discount', lang)} %',
                  subtitle: AppStrings.get('first_order_discount_desc', lang),
                  value: '${(tenant.firstOrderDiscountPercent * 100).toStringAsFixed(0)}%',
                  icon: Icons.percent,
                  onTap: () => _showEditDialog(context, ref, tenant, 'firstOrderDiscountPercent', false, lang),
                ),
              if (tenant.firstOrderDiscountEnabled)
                _buildSettingItem(
                  title: '${AppStrings.get('discount', lang)} (${AppStrings.get('amount', lang)})',
                  subtitle: AppStrings.get('first_order_discount_desc', lang),
                  value: formatCurrency(tenant.firstOrderDiscountAmount, lang: lang),
                  icon: Icons.money,
                  onTap: () => _showEditDialog(context, ref, tenant, 'firstOrderDiscountAmount', false, lang),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingItem({required String title, required String subtitle, required String value, required IconData icon, required VoidCallback onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue)),
      onTap: onTap,
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, TenantModel tenant, String field, bool isInt, String lang) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('edit_product', lang).replaceAll('المنتج', field)), // Simple replace for context
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            border: const OutlineInputBorder(), 
            hintText: AppStrings.get('product_name', lang)
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel', lang))),
          FilledButton(
            onPressed: () {
              final newVal = double.tryParse(controller.text);
              if (newVal != null) {
                final json = tenant.toJson();
                json[field] = isInt ? newVal.toInt() : newVal;
                ref.read(adminFirestoreServiceProvider).updateTenant(TenantModel.fromJson(json));
                Navigator.pop(ctx);
              }
            },
            child: Text(AppStrings.get('save', lang)),
          ),
        ],
      ),
    );
  }
}
