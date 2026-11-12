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
    final selectedTier = useState<String>(tenant.posTier);
    final deviceLimitController = useTextEditingController(text: tenant.posDeviceLimit.toString());
    final graceDaysController = useTextEditingController(text: tenant.posGraceDays.toString());
    final trialDaysController = useTextEditingController(text: '14');

    // Features Flags State
    final lanSync = useState<bool>(tenant.posLanSyncEnabled);
    final cloudBackup = useState<bool>(tenant.posCloudBackupEnabled);
    final remoteDash = useState<bool>(tenant.posRemoteDashEnabled);
    final excelEnabled = useState<bool>(tenant.posExcelEnabled);
    final multiBranch = useState<bool>(tenant.posMultiBranchEnabled);
    final videoGen = useState<bool>(tenant.posVideoGenEnabled);

    // Renewal inputs
    final monthsController = useTextEditingController(text: '12');
    final posMonthsController = useTextEditingController(text: '12');
    final carsDaysController = useTextEditingController(text: '365');
    final codeController = useTextEditingController(
        text: 'ACT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final posCodeController = useTextEditingController(
        text: 'POS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');
    final carsCodeController = useTextEditingController(
        text: 'CAR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');

    // Automatically set tier defaults when tier changes
    void onTierChanged(String? newTier) {
      if (newTier == null) return;
      selectedTier.value = newTier;
      switch (newTier) {
        case 'A': // المجانية - جهاز واحد - بدون مزامنة
          deviceLimitController.text = '1';
          lanSync.value = false;
          cloudBackup.value = false;
          remoteDash.value = false;
          excelEnabled.value = false;
          multiBranch.value = false;
          videoGen.value = false;
          break;
        case 'B': // شبكة محلية LAN - 5 أجهزة
          deviceLimitController.text = '5';
          lanSync.value = true;
          cloudBackup.value = false;
          remoteDash.value = false;
          excelEnabled.value = false;
          multiBranch.value = false;
          videoGen.value = false;
          break;
        case 'C': // سحابية - 10 أجهزة + نسخ احتياطي + إكسل
          deviceLimitController.text = '10';
          lanSync.value = true;
          cloudBackup.value = true;
          remoteDash.value = true;
          excelEnabled.value = true;
          multiBranch.value = false;
          videoGen.value = true;
          break;
        case 'D': // مؤسسات - غير محدود + مزامنة سحابية لحظية
          deviceLimitController.text = '-1';
          lanSync.value = true;
          cloudBackup.value = true;
          remoteDash.value = true;
          excelEnabled.value = true;
          multiBranch.value = true;
          videoGen.value = true;
          break;
      }
    }

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.verified_user_rounded, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${AppStrings.get('manage_subscription', lang)} - ${tenant.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================== 1. قسم باقات الكاشير (POS Tiers) ====================
              _SectionHeader(
                icon: Icons.layers_rounded,
                title: lang == 'ar' ? 'إدارة باقات الكاشير (POS Tiers)' : 'POS Tiers Management',
                color: Colors.indigo,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.indigo.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('الباقة الحالية: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        DropdownButton<String>(
                          value: selectedTier.value,
                          items: const [
                            DropdownMenuItem(value: 'A', child: Text('🥉 Tier A - المجانية (جهاز واحد، Offline)')),
                            DropdownMenuItem(value: 'B', child: Text('🥈 Tier B - المحلية (مزامنة LAN)')),
                            DropdownMenuItem(value: 'C', child: Text('🥇 Tier C - السحابية (نسخ سحابي + إكسل)')),
                            DropdownMenuItem(value: 'D', child: Text('💎 Tier D - المؤسسات (فروع ومزامنة لحظية)')),
                          ],
                          onChanged: onTierChanged,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: deviceLimitController,
                            decoration: const InputDecoration(
                              labelText: 'الحد الأقصى للأجهزة',
                              hintText: 'مثال: 5 أو -1 لغير محدود',
                              prefixIcon: Icon(Icons.devices_rounded),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: graceDaysController,
                            decoration: const InputDecoration(
                              labelText: 'أيام السماح (Grace Period)',
                              suffixText: 'يوم',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('الميزات المضمنة في الباقة:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        FilterChip(
                          label: const Text('مزامنة LAN'),
                          selected: lanSync.value,
                          onSelected: (v) => lanSync.value = v,
                        ),
                        FilterChip(
                          label: const Text('نسخ سحابي'),
                          selected: cloudBackup.value,
                          onSelected: (v) => cloudBackup.value = v,
                        ),
                        FilterChip(
                          label: const Text('مراقبة عن بعد'),
                          selected: remoteDash.value,
                          onSelected: (v) => remoteDash.value = v,
                        ),
                        FilterChip(
                          label: const Text('استيراد/تصدير إكسل'),
                          selected: excelEnabled.value,
                          onSelected: (v) => excelEnabled.value = v,
                        ),
                        FilterChip(
                          label: const Text('فروع متعددة'),
                          selected: multiBranch.value,
                          onSelected: (v) => multiBranch.value = v,
                        ),
                        FilterChip(
                          label: const Text('توليد فيديو بالذكاء الاصطناعي'),
                          selected: videoGen.value,
                          onSelected: (v) => videoGen.value = v,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('حفظ إعدادات الباقة والميزات'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                        onPressed: () async {
                          final devLimit = int.tryParse(deviceLimitController.text) ?? 1;
                          final grace = int.tryParse(graceDaysController.text) ?? 14;

                          final updated = tenant.copyWith(
                            posTier: selectedTier.value,
                            posDeviceLimit: devLimit,
                            posGraceDays: grace,
                            posLanSyncEnabled: lanSync.value,
                            posCloudBackupEnabled: cloudBackup.value,
                            posRemoteDashEnabled: remoteDash.value,
                            posExcelEnabled: excelEnabled.value,
                            posMultiBranchEnabled: multiBranch.value,
                            posVideoGenEnabled: videoGen.value,
                          );

                          await ref.read(superAdminFirestoreServiceProvider).updateTenant(updated);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تحديث الباقة والميزات بنجاح!'), backgroundColor: Colors.green),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),

              // ==================== 2. قسم المدة المجانية التجريبية (Free Trial) ====================
              _SectionHeader(
                icon: Icons.card_giftcard_rounded,
                title: lang == 'ar' ? 'منح مدة تجريبية مجانية (Free Trial)' : 'Grant Free Trial',
                color: Colors.teal,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.teal.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant.isTrialActive && tenant.trialEndDate != null
                          ? '✅ المتجر حالياً في فترة تجريبية تنتهي في: ${DateFormat('yyyy/MM/dd').format(tenant.trialEndDate!)}'
                          : 'المتجر لا يملك فترة تجريبية نشطة حالياً.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tenant.isTrialActive ? Colors.teal[800] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: trialDaysController,
                            decoration: const InputDecoration(
                              labelText: 'مدة التجربة المجانية',
                              suffixText: 'أيام',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          icon: const Icon(Icons.flash_on_rounded),
                          label: const Text('تفعيل التجربة الآن'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.teal),
                          onPressed: () async {
                            final days = int.tryParse(trialDaysController.text) ?? 14;
                            final now = DateTime.now();
                            final end = now.add(Duration(days: days));

                            final updated = tenant.copyWith(
                              isTrialActive: true,
                              trialStartDate: now,
                              trialEndDate: end,
                              isPosEnabled: true,
                              posExpiryDate: end,
                              posTier: selectedTier.value == 'A' ? 'C' : selectedTier.value, // تجربة باقة متقدمة
                            );

                            await ref.read(superAdminFirestoreServiceProvider).updateTenant(updated);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('تم منح $days يوم تجربة مجانية بنجاح!'), backgroundColor: Colors.teal),
                              );
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(),

              // ==================== 3. قسم تفعيل الكاشير (POS Activation) ====================
              _SectionHeader(
                icon: Icons.point_of_sale_rounded,
                title: lang == 'ar' ? 'تفعيل مبيعات الكاشير (POS)' : 'POS Activation',
                color: Colors.blue,
              ),
              Text(
                '${lang == 'ar' ? 'صلاحية اشتراك الكاشير' : 'POS Expiry'}: '
                '${tenant.posExpiryDate != null ? DateFormat('yyyy/MM/dd').format(tenant.posExpiryDate!) : 'دائم / غير محدد'}',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: posMonthsController,
                      decoration: InputDecoration(
                        labelText: AppStrings.get('renewal_period', lang),
                        suffixText: AppStrings.get('months', lang),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final months = int.tryParse(posMonthsController.text) ?? 1;
                      await ref
                          .read(superAdminFirestoreServiceProvider)
                          .activatePosSubscription(tenant.id, months, posCodeController.text.trim());
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(AppStrings.get('activate', lang)),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),

              // ==================== 4. قسم تفعيل المتجر (Store App) ====================
              _SectionHeader(
                icon: Icons.store_rounded,
                title: lang == 'ar' ? 'تفعيل المتجر (الويب/الموبايل)' : 'Store Activation',
                color: Colors.orange,
              ),
              Text(
                '${AppStrings.get('expiry', lang)}: '
                '${tenant.expiryDate != null ? DateFormat('yyyy/MM/dd').format(tenant.expiryDate!) : 'دائم / غير محدد'}',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: monthsController,
                      decoration: InputDecoration(
                        labelText: AppStrings.get('renewal_period', lang),
                        suffixText: AppStrings.get('months', lang),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final months = int.tryParse(monthsController.text) ?? 1;
                      await ref
                          .read(superAdminFirestoreServiceProvider)
                          .activateSubscription(tenant.id, months, codeController.text.trim());
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(AppStrings.get('activate', lang)),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(),

              // ==================== 5. قسم نظام السيارات (Cars) ====================
              _SectionHeader(
                icon: Icons.directions_car_rounded,
                title: lang == 'ar' ? 'تفعيل نظام السيارات (العقود)' : 'Cars Module Activation',
                color: Colors.purple,
              ),
              Text(
                '${lang == 'ar' ? 'صلاحية اشتراك السيارات' : 'Cars Expiry'}: '
                '${tenant.carsExpiryDate != null ? DateFormat('yyyy/MM/dd').format(tenant.carsExpiryDate!) : 'دائم / غير محدد'}',
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: carsDaysController,
                      decoration: InputDecoration(
                        labelText: lang == 'ar' ? 'فترة التجديد' : 'Renewal Period',
                        suffixText: lang == 'ar' ? 'أيام' : 'Days',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final days = int.tryParse(carsDaysController.text) ?? 365;
                      await ref
                          .read(superAdminFirestoreServiceProvider)
                          .activateCarsModule(tenant.id, carsCodeController.text.trim(), days);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(AppStrings.get('activate', lang)),
                  ),
                ],
              ),
            ],
          ),
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

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }
}
