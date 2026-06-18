import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:super_admin/core/localization/resources/app_strings.dart';
import 'package:super_admin/features/shared/providers.dart';
import 'package:shared_models/shared_models.dart';

class AddTenantDialog extends HookConsumerWidget {
  final String lang;
  const AddTenantDialog({super.key, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final idController = useTextEditingController();
    final adminIdController = useTextEditingController();
    final logoController = useTextEditingController();
    final colorController = useTextEditingController(text: '#2196F3');
    final whatsappController = useTextEditingController();
    final oneSignalIdController = useTextEditingController();
    final oneSignalKeyController = useTextEditingController();
    final managerNameController = useTextEditingController();
    final managerPhoneController = useTextEditingController();
    final descriptionController = useTextEditingController();

    return AlertDialog(
      title: Text(AppStrings.get('add_tenant', lang)),
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
              controller: idController,
              decoration: const InputDecoration(labelText: 'Store ID (e.g. store_name_id)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: adminIdController,
              decoration: InputDecoration(labelText: AppStrings.get('admin_id', lang)),
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
            TextField(
              controller: colorController,
              decoration: InputDecoration(
                labelText: AppStrings.get('primary_color', lang),
                helperText: 'HEX: #RRGGBB',
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
            if (nameController.text.trim().isEmpty || idController.text.trim().isEmpty || adminIdController.text.trim().isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('الرجاء ملء الحقول الإلزامية (اسم المتجر، المعرف، معرف المسئول)')),
                );
              }
              return;
            }
            
            try {
              final service = ref.read(superAdminFirestoreServiceProvider);
              
              final newTenant = TenantModel(
                id: idController.text.trim(),
                name: nameController.text.trim(),
                adminIds: [adminIdController.text.trim()],
                logoUrl: logoController.text.trim().isEmpty ? null : logoController.text.trim(),
                primaryColor: colorController.text.trim().isEmpty ? '#2196F3' : colorController.text.trim(),
                whatsappNumber: whatsappController.text.trim(),
                oneSignalAppId: oneSignalIdController.text.trim().isEmpty ? null : oneSignalIdController.text.trim(),
                oneSignalRestKey: oneSignalKeyController.text.trim().isEmpty ? null : oneSignalKeyController.text.trim(),
                managerName: managerNameController.text.trim(),
                managerPhone: managerPhoneController.text.trim(),
                description: descriptionController.text.trim(),
                createdAt: DateTime.now(),
                isActive: false,
              );
              
              await service.addTenant(newTenant);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('حدث خطأ أثناء الإضافة: $e')),
                );
              }
            }
          },
          child: Text(AppStrings.get('save', lang)),
        ),
      ],
    );
  }
}
