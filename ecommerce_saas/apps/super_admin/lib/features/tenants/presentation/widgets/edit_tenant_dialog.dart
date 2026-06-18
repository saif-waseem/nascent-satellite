import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:super_admin/core/localization/resources/app_strings.dart';
import 'package:super_admin/features/shared/providers.dart';
import 'package:shared_models/shared_models.dart';

class EditTenantDialog extends HookConsumerWidget {
  final TenantModel tenant;
  final String lang;
  
  const EditTenantDialog({super.key, required this.tenant, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController(text: tenant.name);
    final logoController = useTextEditingController(text: tenant.logoUrl);
    final colorController = useTextEditingController(text: tenant.primaryColor);
    final whatsappController = useTextEditingController(text: tenant.whatsappNumber);
    final oneSignalIdController = useTextEditingController(text: tenant.oneSignalAppId);
    final oneSignalKeyController = useTextEditingController(text: tenant.oneSignalRestKey);
    final managerNameController = useTextEditingController(text: tenant.managerName);
    final managerPhoneController = useTextEditingController(text: tenant.managerPhone);
    final descriptionController = useTextEditingController(text: tenant.description);
    
    final isStoreEnabled = useState(tenant.isStoreEnabled);
    final isPosEnabled = useState(tenant.isPosEnabled);
    final isCarsEnabled = useState(tenant.isCarsEnabled);

    return AlertDialog(
      title: Text(lang == 'ar' ? 'تعديل المتجر' : 'Edit Store'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: AppStrings.get('store_name', lang)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: logoController,
              decoration: InputDecoration(labelText: AppStrings.get('logo_url', lang)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: AppStrings.get('description', lang)),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            Text(AppStrings.get('connection_settings', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            TextField(
              controller: whatsappController,
              decoration: InputDecoration(labelText: AppStrings.get('whatsapp', lang)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: oneSignalIdController,
              decoration: InputDecoration(labelText: AppStrings.get('onesignal_id', lang)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: oneSignalKeyController,
              decoration: InputDecoration(labelText: AppStrings.get('onesignal_key', lang)),
            ),
            const SizedBox(height: 24),
            Text(lang == 'ar' ? 'بيانات المسئول' : 'Manager Info', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            TextField(
              controller: managerNameController,
              decoration: InputDecoration(labelText: AppStrings.get('manager_name', lang)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: managerPhoneController,
              decoration: InputDecoration(labelText: AppStrings.get('manager_phone', lang)),
            ),
            const SizedBox(height: 24),
            ListTile(
              title: Text(AppStrings.get('primary_color', lang)),
              subtitle: Text(colorController.text),
              trailing: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(int.parse(colorController.text.replaceFirst('#', '0xff'))),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey),
                ),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Pick a color'),
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        pickerColor: Color(int.parse(colorController.text.replaceFirst('#', '0xff'))),
                        onColorChanged: (color) {
                          colorController.text = '#${color.toARGB32().toRadixString(16).substring(2)}';

                        },
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 16),
            Text(lang == 'ar' ? 'تفعيل البرامج' : 'App Activation', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(lang == 'ar' ? 'تفعيل المتجر (للعملاء)' : 'Store Enabled'),
                    value: isStoreEnabled.value,
                    onChanged: (v) => isStoreEnabled.value = v,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(lang == 'ar' ? 'تفعيل المبيعات (نقطة البيع - POS)' : 'POS Enabled'),
                    value: isPosEnabled.value,
                    onChanged: (v) => isPosEnabled.value = v,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: Text(lang == 'ar' ? 'تفعيل السيارات (العقود)' : 'Cars Enabled'),
                    value: isCarsEnabled.value,
                    onChanged: (v) => isCarsEnabled.value = v,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.get('cancel', lang)),
        ),
        FilledButton(
          onPressed: () async {
            if (nameController.text.isEmpty) return;
            
            final service = ref.read(superAdminFirestoreServiceProvider);
            
            final updatedTenant = tenant.copyWith(
              name: nameController.text.trim(),
              logoUrl: logoController.text.trim().isEmpty ? null : logoController.text.trim(),
              primaryColor: colorController.text.trim().isEmpty ? '#2196F3' : colorController.text.trim(),
              whatsappNumber: whatsappController.text.trim(),
              oneSignalAppId: oneSignalIdController.text.trim().isEmpty ? null : oneSignalIdController.text.trim(),
              oneSignalRestKey: oneSignalKeyController.text.trim().isEmpty ? null : oneSignalKeyController.text.trim(),
              managerName: managerNameController.text.trim(),
              managerPhone: managerPhoneController.text.trim(),
              description: descriptionController.text.trim(),
              isStoreEnabled: isStoreEnabled.value,
              isPosEnabled: isPosEnabled.value,
              isCarsEnabled: isCarsEnabled.value,
              isActive: isStoreEnabled.value || isPosEnabled.value || isCarsEnabled.value, // Keep legacy flag consistent
            );
            
            await service.updateTenant(updatedTenant);
            if (context.mounted) Navigator.pop(context);
          },
          child: Text(AppStrings.get('save', lang)),
        ),
      ],
    );
  }
}
