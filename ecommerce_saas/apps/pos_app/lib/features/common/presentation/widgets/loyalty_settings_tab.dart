import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/app_settings_repository.dart';

class LoyaltySettingsTab extends HookConsumerWidget {
  const LoyaltySettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final isSaving = useState(false);
    final loyaltyEnabled = useState(true);
    final pointsPerUnit = useTextEditingController(text: '1000');
    final pointsValue = useTextEditingController(text: '100');

    useEffect(() {
      settingsAsync.whenData((s) {
        loyaltyEnabled.value = s.loyaltyEnabled;
        pointsPerUnit.text = s.pointsPerCurrencyUnit.toStringAsFixed(0);
        pointsValue.text = s.pointsValue.toStringAsFixed(0);
      });
      return null;
    }, [settingsAsync.value]);

    Future<void> save() async {
      isSaving.value = true;
      try {
        final current = await ref.read(appSettingsRepositoryProvider).getSettings();
        await ref.read(appSettingsRepositoryProvider).saveSettings(current.copyWith(
          loyaltyEnabled: loyaltyEnabled.value,
          pointsPerCurrencyUnit: double.tryParse(pointsPerUnit.text) ?? 1000,
          pointsValue: double.tryParse(pointsValue.text) ?? 100,
        ));
        ref.invalidate(appSettingsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات نقاط الولاء بنجاح ✅'), backgroundColor: Colors.green));
        }
      } finally {
        isSaving.value = false;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إعدادات نقاط الولاء', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('تحكم في كيفية حساب وصرف نقاط المكافآت للزبائن.', style: TextStyle(color: Colors.grey)),
          const Divider(height: 32),

          // Toggle Enable
          Card(
            child: SwitchListTile(
              title: const Text('تفعيل نظام نقاط الولاء', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('عند التعطيل، لن يتم منح نقاط أو السماح بصرفها.'),
              value: loyaltyEnabled.value,
              onChanged: (v) => loyaltyEnabled.value = v,
              secondary: const Icon(Icons.stars, color: Colors.orange),
            ),
          ),
          const SizedBox(height: 20),

          if (loyaltyEnabled.value) ...[
            // Points Earning Rate
            const Text('معدل الكسب (Earning Rate)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('كم دينار يحتاجه الزبون لكسب نقطة واحدة؟', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: pointsPerUnit,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              decoration: InputDecoration(
                labelText: 'دينار = نقطة واحدة',
                prefixIcon: const Icon(Icons.paid_outlined),
                suffixText: 'IQD',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 24),

            // Points Redemption Value
            const Text('قيمة كل نقطة عند الصرف (Redemption Value)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('كم تساوي النقطة الواحدة عند الاستبدال بخصم؟', style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 8),
            TextField(
              controller: pointsValue,
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              decoration: InputDecoration(
                labelText: 'قيمة النقطة',
                prefixIcon: const Icon(Icons.redeem),
                suffixText: 'IQD',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            // Summary card
            Card(
              color: Colors.orange.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.orange, width: 0.3)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('مثال توضيحي', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    const SizedBox(height: 6),
                    Text(
                      'زبون يشتري بمبلغ ${pointsPerUnit.text} دينار → يكسب 1 نقطة\n'
                      'عند صرف 10 نقاط → خصم ${(double.tryParse(pointsValue.text) ?? 100) * 10} دينار',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: isSaving.value ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
              label: const Text('حفظ الإعدادات'),
              onPressed: isSaving.value ? null : save,
            ),
          ),
        ],
      ),
    );
  }
}
