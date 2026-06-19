import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/settings_provider.dart';

class SettingsScreen extends HookConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final officeName = useTextEditingController(text: settings.officeName);
    final managerName = useTextEditingController(text: settings.managerName);
    final officeAddress = useTextEditingController(text: settings.officeAddress);
    final phone = useTextEditingController(text: settings.phone);
    final licenseNumber = useTextEditingController(text: settings.licenseNumber);
    final showStats = useState(settings.showStats);
    final logoPath = useState<String?>(settings.logoImagePath);
    final isSaving = useState(false);

    Future<void> pickLogo() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked != null) logoPath.value = picked.path;
    }

    Future<void> save() async {
      isSaving.value = true;
      await ref.read(settingsProvider.notifier).save(settings.copyWith(
        officeName: officeName.text.trim().isEmpty ? 'مكتب السيارات' : officeName.text.trim(),
        managerName: managerName.text.trim(),
        officeAddress: officeAddress.text.trim(),
        phone: phone.text.trim(),
        licenseNumber: licenseNumber.text.trim(),
        logoImagePath: logoPath.value,
        showStats: showStats.value,
      ));
      isSaving.value = false;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حفظ الإعدادات'), backgroundColor: Colors.green),
        );
      }
    }

    Widget field(String label, TextEditingController ctrl, {TextInputType? type}) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextFormField(
            controller: ctrl,
            keyboardType: type,
            style: GoogleFonts.cairo(),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: AppColors.lapisDark, fontWeight: FontWeight.w600, fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.gold, width: 2)),
            ),
          ),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: const Border(right: BorderSide(color: AppColors.lapis, width: 4)),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إعدادات المكتب', style: GoogleFonts.amiri(fontSize: 22, color: AppColors.terracotta, fontWeight: FontWeight.bold)),
            const Divider(color: AppColors.clayDark, height: 28),
            Row(
              children: [
                Expanded(child: field('اسم المكتب', officeName)),
                const SizedBox(width: 16),
                Expanded(child: field('مدير المكتب', managerName)),
              ],
            ),
            Row(
              children: [
                Expanded(child: field('العنوان', officeAddress)),
                const SizedBox(width: 16),
                Expanded(child: field('الهاتف', phone, type: TextInputType.phone)),
              ],
            ),
            field('رقم الإجازة', licenseNumber),
            // Logo
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: pickLogo,
                  icon: const Icon(Icons.image, size: 16),
                  label: Text('اختر شعار المكتب', style: GoogleFonts.cairo(fontSize: 13)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.lapisDark, foregroundColor: Colors.white),
                ),
                if (logoPath.value != null) ...[
                  const SizedBox(width: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(File(logoPath.value!), width: 70, height: 70, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => logoPath.value = null, child: const Text('إزالة', style: TextStyle(color: Colors.red))),
                ],
              ],
            ),
            const SizedBox(height: 20),
            // Show Stats Toggle
            Row(
              children: [
                Switch(
                  value: showStats.value,
                  onChanged: (v) => showStats.value = v,
                  activeColor: AppColors.lapis,
                ),
                const SizedBox(width: 8),
                Text('إظهار الإحصائيات في الصفحة الرئيسية', style: GoogleFonts.cairo(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaving.value ? null : save,
                icon: isSaving.value ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
                label: Text('حفظ الإعدادات', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 15)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lapis,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
