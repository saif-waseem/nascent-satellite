import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:printing/printing.dart';
import '../../data/printer_settings_repository.dart';
import '../../data/app_settings_repository.dart';

class DevicesTab extends HookConsumerWidget {
  const DevicesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printerSettingsAsync = ref.watch(printerSettingsProvider);
    final appSettingsAsync = ref.watch(appSettingsProvider);

    return printerSettingsAsync.when(
      data: (settings) => appSettingsAsync.when(
        data: (appSettings) => _buildContent(context, ref, settings, appSettings),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, PrinterSettings pSettings, AppSettings aSettings) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إعدادات الطابعات والأجهزة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),

            // --- Receipt Printer Section ---
            _buildPrinterSection(
              context,
              ref,
              title: 'طابعة الوصلات (Receipt Printer)',
              subtitle: 'تستخدم لطباعة وصولات البيع والمشتريات',
              printerName: pSettings.receiptPrinterId,
              onSelect: (name) => ref.read(printerSettingsRepositoryProvider).saveReceiptPrinter(name),
              onAutoDetect: () => _autoDetectPreset(ref, pSettings.receiptPrinterId, isReceipt: true),
            ),
            
            const SizedBox(height: 16),

            // --- Barcode Printer Section ---
            _buildPrinterSection(
              context,
              ref,
              title: 'طابعة الباركود (Barcode Printer)',
              subtitle: 'تستخدم لطباعة ملصقات الباركود للمواد',
              printerName: pSettings.labelPrinterId,
              onSelect: (name) => ref.read(printerSettingsRepositoryProvider).saveLabelPrinter(name),
              onAutoDetect: () => _autoDetectPreset(ref, pSettings.labelPrinterId, isReceipt: false),
            ),

            const SizedBox(height: 32),
            const Text('قياسات الورق (Paper Presets)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // --- Receipt Presets ---
            const Text('حجم ورق الوصلات:', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildPresetCard(
                  title: 'Standard (Large)',
                  subtitle: '80mm Thermal',
                  isSelected: pSettings.receiptPreset == ReceiptPreset.thermal80,
                  onTap: () => _updateReceiptPreset(ref, ReceiptPreset.thermal80),
                  icon: Icons.receipt_long,
                ),
                const SizedBox(width: 12),
                _buildPresetCard(
                  title: 'Small (Compact)',
                  subtitle: '58mm Thermal',
                  isSelected: pSettings.receiptPreset == ReceiptPreset.thermal58,
                  onTap: () => _updateReceiptPreset(ref, ReceiptPreset.thermal58),
                  icon: Icons.receipt,
                ),
                const SizedBox(width: 12),
                _buildPresetCard(
                  title: 'Office A4',
                  subtitle: 'Standard Paper',
                  isSelected: pSettings.receiptPreset == ReceiptPreset.a4,
                  onTap: () => _updateReceiptPreset(ref, ReceiptPreset.a4),
                  icon: Icons.description,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // --- Label Presets ---
            const Text('حجم ملصقات الباركود:', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPresetCard(
                    title: 'Jewelry Label',
                    subtitle: '30x20mm',
                    isSelected: pSettings.labelPreset == LabelPreset.jewelry3020,
                    onTap: () => _updateLabelPreset(ref, LabelPreset.jewelry3020),
                    icon: Icons.sell,
                  ),
                  const SizedBox(width: 12),
                  _buildPresetCard(
                    title: 'Standard Label',
                    subtitle: '40x30mm',
                    isSelected: pSettings.labelPreset == LabelPreset.standard4030,
                    onTap: () => _updateLabelPreset(ref, LabelPreset.standard4030),
                    icon: Icons.label,
                  ),
                  const SizedBox(width: 12),
                  _buildPresetCard(
                    title: 'Shipping Label',
                    subtitle: '100x150mm',
                    isSelected: pSettings.labelPreset == LabelPreset.shipping100150,
                    onTap: () => _updateLabelPreset(ref, LabelPreset.shipping100150),
                    icon: Icons.local_shipping,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),

            // --- Hardware Features ---
            const Text('ميزات إضافية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('الطباعة التلقائية (Auto Print)'),
                    subtitle: const Text('إرسال الفاتورة للطابعة فور إنهاء البيع'),
                    value: aSettings.autoPrintReceipt,
                    onChanged: (val) async {
                      final newSettings = aSettings.copyWith(autoPrintReceipt: val);
                      await ref.read(appSettingsRepositoryProvider).saveSettings(newSettings);
                      ref.invalidate(appSettingsProvider);
                    },
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('فتح درج الكاشير (Cash Drawer)'),
                    subtitle: const Text('إرسال أمر الفتح عبر طابعة الوصلات (ESC/POS)'),
                    value: aSettings.openCashDrawer,
                    onChanged: (val) async {
                      final newSettings = aSettings.copyWith(openCashDrawer: val);
                      await ref.read(appSettingsRepositoryProvider).saveSettings(newSettings);
                      ref.invalidate(appSettingsProvider);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetCard({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 32),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? Colors.blue : Colors.black)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterSection(
    BuildContext context, 
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required String? printerName,
    required Future<void> Function(String?) onSelect,
    required VoidCallback onAutoDetect,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
                if (printerName != null)
                  TextButton.icon(
                    onPressed: onAutoDetect,
                    icon: const Icon(Icons.auto_fix_high, size: 16),
                    label: const Text('التعرف التلقائي'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.print, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الطابعة المختارة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(printerName ?? 'لم يتم الاختيار بعد', 
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: printerName == null ? Colors.red : Colors.green
                        )
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('بحث'),
                  onPressed: () => _pickPrinter(context, ref, onSelect),
                ),
                if (printerName != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () async {
                      await onSelect(null);
                      ref.invalidate(printerSettingsProvider);
                    },
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateReceiptPreset(WidgetRef ref, ReceiptPreset preset) async {
    await ref.read(printerSettingsRepositoryProvider).saveReceiptPreset(preset);
    // Also sync the old paperType for backward compatibility
    if (preset == ReceiptPreset.a4) {
      await ref.read(printerSettingsRepositoryProvider).savePaperType(PaperType.a4);
    } else {
      await ref.read(printerSettingsRepositoryProvider).savePaperType(PaperType.thermal80mm);
    }
    ref.invalidate(printerSettingsProvider);
  }

  Future<void> _updateLabelPreset(WidgetRef ref, LabelPreset preset) async {
    await ref.read(printerSettingsRepositoryProvider).saveLabelPreset(preset);
    ref.invalidate(printerSettingsProvider);
  }

  Future<void> _autoDetectPreset(WidgetRef ref, String? printerId, {required bool isReceipt}) async {
    if (printerId == null) return;

    final idLower = printerId.toLowerCase();
    
    if (isReceipt) {
      if (idLower.contains('58')) {
        await _updateReceiptPreset(ref, ReceiptPreset.thermal58);
      } else if (idLower.contains('a4') || idLower.contains('laser') || idLower.contains('l3110') || idLower.contains('hp')) {
        await _updateReceiptPreset(ref, ReceiptPreset.a4);
      } else {
        // Default to 80mm for thermal if nothing else matches
        await _updateReceiptPreset(ref, ReceiptPreset.thermal80);
      }
    } else {
      if (idLower.contains('standard') || idLower.contains('40x30')) {
        await _updateLabelPreset(ref, LabelPreset.standard4030);
      } else if (idLower.contains('jewelry') || idLower.contains('30x20')) {
        await _updateLabelPreset(ref, LabelPreset.jewelry3020);
      } else if (idLower.contains('shipping') || idLower.contains('100x150') || idLower.contains('zpl') || idLower.contains('zebra')) {
        await _updateLabelPreset(ref, LabelPreset.shipping100150);
      } else {
        await _updateLabelPreset(ref, LabelPreset.standard4030);
      }
    }
  }

  Future<void> _pickPrinter(BuildContext context, WidgetRef ref, Future<void> Function(String?) onSelect) async {
    final printers = await Printing.listPrinters();
    
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر الطابعة من القائمة'),
        content: SizedBox(
          width: double.maxFinite,
          child: printers.isEmpty 
            ? const Text('لم يتم العثور على طابعات معرفة في الويندوز')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: printers.length,
                itemBuilder: (context, index) {
                  final printer = printers[index];
                  return ListTile(
                    leading: const Icon(Icons.print),
                    title: Text(printer.name),
                    subtitle: Text(printer.url),
                    onTap: () async {
                      await onSelect(printer.name);
                      ref.invalidate(printerSettingsProvider);
                      if (context.mounted) Navigator.pop(context);
                    },
                  );
                },
              ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}
