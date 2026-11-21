import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/services/cashier_stock_service.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../data/app_settings_repository.dart';

class InventorySettingsTab extends HookConsumerWidget {
  const InventorySettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        final daysController = useTextEditingController(
          text: settings.inventoryDeadStockDays.toString(),
        );
        final isAlertEnabled = useState(settings.stockAlertsEnabled);

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إعدادات الذكاء المخزني',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'تحكم في كيفية تحليل النظام للبضائع الراكدة وتنبيهات النواقص.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const Divider(height: 32),

                SwitchListTile(
                  title: const Text('تفعيل تنبيهات نقص المخزون'),
                  subtitle: const Text(
                    'إظهار إشعارات وشارات حمراء عند وصول الكمية للحد الأدنى.',
                  ),
                  value: isAlertEnabled.value,
                  onChanged: (val) => isAlertEnabled.value = val,
                ),
                const SizedBox(height: 16),

                const Text(
                  'معيار البضاعة الراكدة (الخاملة)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: daysController,
                  decoration: const InputDecoration(
                    labelText: 'عدد الأيام لمراقبة المبيعات',
                    hintText: 'مثلاً: 30',
                    border: OutlineInputBorder(),
                    suffixText: 'يوم',
                    helperText:
                        'إذا لم يباع المنتج خلال هذه المدة وهو متوفر، سيصنف كراكــد.',
                  ),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.link),
                  label: const Text('ربط مخزون Supabase'),
                  onPressed: () async {
                    final tenant = ref.read(tenantIdProvider);
                    String key = '';
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('ربط جهاز الكاشير بالمخزون'),
                        content: TextField(
                          obscureText: true,
                          onChanged: (value) => key = value.trim(),
                          decoration: const InputDecoration(
                            labelText: 'مفتاح الجهاز',
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('ربط'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true || !context.mounted) return;
                    try {
                      await ref.read(cashierStockProvider).pair(tenant, key);
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم ربط المخزون')),
                        );
                    } catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final days = int.tryParse(daysController.text) ?? 30;
                      final newSettings = settings.copyWith(
                        inventoryDeadStockDays: days,
                        stockAlertsEnabled: isAlertEnabled.value,
                      );
                      await ref
                          .read(appSettingsRepositoryProvider)
                          .saveSettings(newSettings);
                      ref.invalidate(appSettingsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم حفظ إعدادات المخزون'),
                          ),
                        );
                      }
                    },
                    child: const Text('حفظ الإعدادات'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
