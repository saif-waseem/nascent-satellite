import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:printing/printing.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../data/printer_settings_repository.dart';
import '../../data/app_settings_repository.dart';
import '../../../../core/utils/printing_service.dart';

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
    // Local controllers to prevent rebuild flickering during typing
    final widthController = useTextEditingController(text: pSettings.customWidth.toString());
    final heightController = useTextEditingController(text: pSettings.customHeight.toString());
    final marginController = useTextEditingController(text: pSettings.customMargin.toString());

    // Sync controllers if settings change externally
    useEffect(() {
      if (double.tryParse(widthController.text) != pSettings.customWidth) {
        widthController.text = pSettings.customWidth.toString();
      }
      if (double.tryParse(heightController.text) != pSettings.customHeight) {
        heightController.text = pSettings.customHeight.toString();
      }
      if (double.tryParse(marginController.text) != pSettings.customMargin) {
        marginController.text = pSettings.customMargin.toString();
      }
      return null;
    }, [pSettings.customWidth, pSettings.customHeight, pSettings.customMargin]);

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
            
            const SizedBox(height: 16),
            
            // --- Barcode Bluetooth Section ---
            _buildBluetoothSection(
              context,
              ref,
              title: 'طابعة باركود بلوتوث (اختياري)',
              subtitle: 'استخدم طابعة بلوتوث مخصصة للملصقات',
              isEnabled: pSettings.useBluetoothForLabels,
              macAddress: pSettings.bluetoothLabelPrinterMac,
              onToggle: (val) => ref.read(printerSettingsRepositoryProvider).saveBluetoothLabelSettings(val, pSettings.bluetoothLabelPrinterMac),
              onSearch: () => _pickBluetoothPrinter(context, ref, isLabel: true),
            ),

            const SizedBox(height: 16),
            
            // --- Receipt Bluetooth Section ---
            _buildBluetoothSection(
              context,
              ref,
              title: 'طابعة وصلات بلوتوث (للجوال)',
              subtitle: 'تطبع مباشرة عبر البلوتوث للطابعات الحرارية',
              isEnabled: pSettings.useBluetooth,
              macAddress: pSettings.bluetoothPrinterMac,
              onToggle: (val) => ref.read(printerSettingsRepositoryProvider).saveBluetoothSettings(val, pSettings.bluetoothPrinterMac),
              onSearch: () => _pickBluetoothPrinter(context, ref, isLabel: false),
            ),

            const SizedBox(height: 32),
            const Text('قياسات الورق (Paper Presets)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // --- Receipt Presets ---
            const Text('حجم ورق الوصلات:', style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
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
                  const SizedBox(width: 12),
                  _buildPresetCard(
                    title: 'Custom',
                    subtitle: 'مخصص',
                    isSelected: pSettings.receiptPreset == ReceiptPreset.custom,
                    onTap: () => _updateReceiptPreset(ref, ReceiptPreset.custom),
                    icon: Icons.settings_overscan,
                  ),
                ],
              ),
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
                  const SizedBox(width: 12),
                  _buildPresetCard(
                    title: 'Custom',
                    subtitle: 'مخصص',
                    isSelected: pSettings.labelPreset == LabelPreset.custom,
                    onTap: () => _updateLabelPreset(ref, LabelPreset.custom),
                    icon: Icons.settings_overscan,
                  ),
                ],
              ),
            ),

            if (pSettings.receiptPreset == ReceiptPreset.custom || pSettings.labelPreset == LabelPreset.custom) ...[
              const SizedBox(height: 32),
              const Text('إعدادات القياس المخصص (Custom Size)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 16),
              Row(
                children: [
                   Expanded(
                    child: TextField(
                      controller: widthController,
                      decoration: const InputDecoration(labelText: 'العرض (mm)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: heightController,
                      decoration: const InputDecoration(labelText: 'الارتفاع (mm)', border: OutlineInputBorder(), hintText: '0 للمستمر'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: marginController,
                      decoration: const InputDecoration(labelText: 'الحاشية (mm)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('حفظ الأبعاد المخصصة'),
                onPressed: () async {
                  final w = double.tryParse(widthController.text) ?? pSettings.customWidth;
                  final h = double.tryParse(heightController.text) ?? pSettings.customHeight;
                  final m = double.tryParse(marginController.text) ?? pSettings.customMargin;
                  
                  await ref.read(printerSettingsRepositoryProvider).saveCustomDimensions(
                    width: w,
                    height: h,
                    margin: m,
                  );
                  ref.invalidate(printerSettingsProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الأبعاد بنجاح')));
                  }
                },
              ),
            ],
            
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

  Widget _buildBluetoothSection(
    BuildContext context, 
    WidgetRef ref, {
    required String title,
    required String subtitle,
    required bool isEnabled,
    required String? macAddress,
    required Function(bool) onToggle,
    required VoidCallback onSearch,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.withOpacity(0.3))),
      color: Colors.blue.withOpacity(0.02),
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
                    Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                Switch(
                  value: isEnabled,
                  onChanged: (val) async {
                    await onToggle(val);
                    ref.invalidate(printerSettingsProvider);
                  },
                ),
              ],
            ),
            if (isEnabled) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.bluetooth, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الطابعة المقترنة:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        Text(macAddress ?? 'لم يتم اختيار طابعة بلوتوث', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: macAddress == null ? Colors.red : Colors.green
                          )
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('بحث بالبلوتوث'),
                    onPressed: onSearch,
                  ),
                ],
              ),
            ],
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
                if (printerName != null) ...[
                  IconButton(
                    icon: const Icon(Icons.print_outlined, color: Colors.blue),
                    tooltip: 'طباعة صفحة تجريبية',
                    onPressed: () => ref.read(printingServiceProvider).printTestPage(isReceipt: title.contains('الوصلات')),
                  ),
                  const SizedBox(width: 4),
                ],
                ElevatedButton.icon(
                  icon: const Icon(Icons.search, size: 18),
                  label: const Text('بحث'),
                  onPressed: () => _pickPrinter(context, ref, onSelect, isReceipt: title.contains('الوصلات')),
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
      if (idLower.contains('58') || idLower.contains('zjiang') || idLower.contains('pos-58') || idLower.contains('bill')) {
        await _updateReceiptPreset(ref, ReceiptPreset.thermal58);
      } else if (idLower.contains('a4') || idLower.contains('laser') || idLower.contains('l3110') || idLower.contains('hp') || idLower.contains('canon') || idLower.contains('brother')) {
        await _updateReceiptPreset(ref, ReceiptPreset.a4);
      } else if (idLower.contains('xp') || idLower.contains('receipt') || idLower.contains('thermal') || idLower.contains('printer')) {
        await _updateReceiptPreset(ref, ReceiptPreset.thermal80);
      } else {
        // Default to A4 if it seems like an office printer, else 80mm
        if (idLower.contains('inkjet') || idLower.contains('copy')) {
           await _updateReceiptPreset(ref, ReceiptPreset.a4);
        } else {
           await _updateReceiptPreset(ref, ReceiptPreset.thermal80);
        }
      }
    } else {
      if (idLower.contains('standard') || idLower.contains('40x30') || idLower.contains('label')) {
        await _updateLabelPreset(ref, LabelPreset.standard4030);
      } else if (idLower.contains('jewelry') || idLower.contains('30x20') || idLower.contains('ring')) {
        await _updateLabelPreset(ref, LabelPreset.jewelry3020);
      } else if (idLower.contains('shipping') || idLower.contains('100x150') || idLower.contains('zpl') || idLower.contains('zebra') || idLower.contains('dymo')) {
        await _updateLabelPreset(ref, LabelPreset.shipping100150);
      } else {
        await _updateLabelPreset(ref, LabelPreset.standard4030);
      }
    }
  }

  Future<void> _pickPrinter(BuildContext context, WidgetRef ref, Future<void> Function(String?) onSelect, {required bool isReceipt}) async {
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
                      // Save the printer identifier
                      await onSelect(printer.name);
                      ref.invalidate(printerSettingsProvider);
                      
                      // Auto detect type based on name if possible
                      if (context.mounted) {
                        _autoDetectPreset(ref, printer.name, isReceipt: isReceipt);
                        Navigator.pop(context);
                      }
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

  Future<void> _pickBluetoothPrinter(BuildContext context, WidgetRef ref, {required bool isLabel}) async {
    // Bluetooth selection is mainly for mobile. On Windows, system printers are preferred.
    if (Theme.of(context).platform == TargetPlatform.windows) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('إعدادات البلوتوث متاحة فقط في نسخة الجوال. يرجى استخدام طابعات النظام في نسخة الحاسوب.')));
       return;
    }

    // Request Bluetooth permissions on Android
    if (Theme.of(context).platform == TargetPlatform.android) {
       final status = await [
         Permission.bluetooth,
         Permission.bluetoothConnect,
         Permission.bluetoothScan,
       ].request();
       
       if (status[Permission.bluetoothConnect] != PermissionStatus.granted) {
         if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء منح صلاحيات البلوتوث للمتابعة')));
         }
         return;
       }
    }

    final isBluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!isBluetoothEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تفعيل البلوتوث أولاً')));
      }
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(content: Row(children: [CircularProgressIndicator(), SizedBox(width: 16), Text('جاري جلب الأجهزة المقترنة...')])),
    );
    
    final pairedDevices = await PrintBluetoothThermal.pairedBluetooths;
    if (!context.mounted) return;
    Navigator.pop(context); // pop loading

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر طابعة بلوتوث'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pairedDevices.isEmpty) 
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('لم يتم العثور على أجهزة بلوتوث مقترنة.', textAlign: TextAlign.center),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: pairedDevices.length,
                    itemBuilder: (context, index) {
                      final device = pairedDevices[index];
                      final String devName = device.name;
                      final String devAddress = (device as dynamic).address ?? (device as dynamic).mac ?? 'Unknown';
                      
                      return ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(devName),
                        subtitle: Text(devAddress),
                        onTap: () async {
                          if (isLabel) {
                            await ref.read(printerSettingsRepositoryProvider).saveBluetoothLabelSettings(true, devAddress);
                          } else {
                            await ref.read(printerSettingsRepositoryProvider).saveBluetoothSettings(true, devAddress);
                          }
                          ref.invalidate(printerSettingsProvider);
                          if (context.mounted) Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              const Divider(),
              const Text('إذا لم تجد طابعتك، تأكد من إقرانها أولاً من إعدادات الهاتف', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}
