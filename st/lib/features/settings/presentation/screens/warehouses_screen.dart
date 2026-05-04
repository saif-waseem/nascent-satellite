import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';

class WarehousesScreen extends HookConsumerWidget {
  const WarehousesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final tenantId = ref.watch(currentTenantIdProvider);
    final controller = useTextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: Text(lang == 'ar' ? 'إدارة المخازن' : 'Warehouses Management'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ref.read(adminFirestoreServiceProvider).getWarehouses(tenantId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data ?? [];
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: lang == 'ar' ? 'اسم المخزن الجديد' : 'New Warehouse Name',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (controller.text.isNotEmpty) {
                          await ref.read(adminFirestoreServiceProvider).addWarehouse(tenantId, controller.text);
                          controller.clear();
                        }
                      },
                      child: Text(lang == 'ar' ? 'إضافة' : 'Add'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    return ListTile(
                      title: Text(item['name'] ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => ref.read(adminFirestoreServiceProvider).deleteWarehouse(tenantId, item['id']),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
