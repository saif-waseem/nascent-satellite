import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../data/app_settings_repository.dart';
import '../../../products/presentation/providers/product_settings_provider.dart';

class CustomizationTab extends HookConsumerWidget {
  const CustomizationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);
    
    // Using hooks for controllers to avoid re-initializing
    final headerController = useTextEditingController();
    final footerController = useTextEditingController();
    final barcodeTemplate = useState('Standard');
    final isSyncEnabled = useState(true);

    // Update controllers when data is loaded
    useEffect(() {
      settingsAsync.whenData((settings) {
        headerController.text = settings.receiptHeader;
        footerController.text = settings.receiptFooter;
        barcodeTemplate.value = settings.barcodeTemplate;
        isSyncEnabled.value = settings.isCloudSyncEnabled;
      });
      return null;
    }, [settingsAsync.value]);

    Future<void> _saveSettings() async {
      final repo = ref.read(appSettingsRepositoryProvider);
      final newSettings = AppSettings(
        barcodeTemplate: barcodeTemplate.value,
        receiptHeader: headerController.text,
        receiptFooter: footerController.text,
        isCloudSyncEnabled: isSyncEnabled.value,
      );
      await repo.saveSettings(newSettings);
      ref.invalidate(appSettingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات بنجاح')));
      }
    }

    return settingsAsync.when(
      data: (settings) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تخصيص القوالب والمزامنة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),


              _buildSectionTitle('تخصيص الباركود'),
              _buildDropdownOption(
                'قالب الباركود',
                barcodeTemplate.value,
                ['Standard', 'Compact', 'Large'],
                (val) => barcodeTemplate.value = val!,
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('تخصيص الوصل (Receipt)'),
              TextField(
                controller: headerController,
                decoration: const InputDecoration(labelText: 'نص الترويسة (Header Text)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: footerController,
                decoration: const InputDecoration(labelText: 'نص التذييل (Footer Text)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              _buildSectionTitle('مزامنة البيانات'),
              SwitchListTile(
                title: const Text('مزامنة السحاب (Cloud Sync)'),
                subtitle: const Text('عند الإيقاف، سيتم الحفظ محلياً فقط (للطوارئ)'),
                value: isSyncEnabled.value,
                onChanged: (val) => isSyncEnabled.value = val,
              ),
              const SizedBox(height: 24),
              _buildArchivalToggle(ref),

              const SizedBox(height: 32),
              _buildSectionTitle('معاينة القوالب (Live Preview)'),
              const SizedBox(height: 12),
              _buildPreviewSection(headerController.text, footerController.text, barcodeTemplate.value),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _saveSettings,
                icon: const Icon(Icons.save),
                label: const Text('حفظ جميع التغييرات'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(55),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildArchivalToggle(WidgetRef ref) {
    final archivalEnabled = ref.watch(productArchivalEnabledProvider);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.archive_outlined, color: Colors.amber.shade800),
              const SizedBox(width: 12),
              const Text(
                'نظام أرشفة المنتجات',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'عند التفعيل، سيتم نقل المنتجات المحذوفة للأرشيف بدلاً من حذفها نهائياً. يمكنك مراجعتها وحذفها نهائياً لاحقاً.',
            style: TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('تفعيل الأرشفة'),
            value: archivalEnabled,
            onChanged: (val) => ref.read(productArchivalEnabledProvider.notifier).setArchivalEnabled(val),
            activeColor: Colors.amber.shade800,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection(String header, String footer, String template) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Invoice Preview
        Expanded(
          child: Column(
            children: [
              const Text('معاينة الوصل', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                ),
                child: Column(
                  children: [
                    Text(header.isEmpty ? 'اسم المتجر هنا' : header, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
                    const Divider(),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('صنف تجريبي', style: TextStyle(fontSize: 10)),
                        Text('12,000', style: TextStyle(fontSize: 10)),
                      ],
                    ),
                    const Divider(),
                    Text(footer.isEmpty ? 'شكراً لزيارتكم' : footer, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Barcode Preview
        Expanded(
          child: Column(
            children: [
              const Text('معاينة الباركود', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    const Text('اسم المنتج', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      height: 30,
                      width: 80,
                      color: Colors.black87,
                      child: const Center(child: Text('||||||||||', style: TextStyle(color: Colors.white, fontSize: 10))),
                    ),
                    const SizedBox(height: 4),
                    const Text('12,000 IQD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blueGrey)),
    );
  }

  Widget _buildDropdownOption(String label, String value, List<String> options, ValueChanged<String?> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        DropdownButton<String>(
          value: value,
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
