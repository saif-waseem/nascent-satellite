import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:store_admin/features/shared/widgets/admin_drawer.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/features/shared/icon_selector_dialog.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';

class AdminCategoriesScreen extends HookConsumerWidget {
  const AdminCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCategories = ref.watch(adminCategoriesProvider);
    final lang = ref.watch(appSettingsProvider).locale.languageCode;

    return Scaffold(
      drawer: const AdminDrawer(),
      appBar: AppBar(
        title: Text(AppStrings.get('categories', lang)),
      ),
      body: asyncCategories.when(
        data: (categories) => ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: Icon(
                  IconData(int.tryParse(cat.icon) ?? 0xe163, fontFamily: 'MaterialIcons'),
                  color: Colors.blue,
                ),
              ),
              title: Text(cat.name),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _confirmDelete(context, ref, cat),
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryDialog(context, ref, lang),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => _AddCategoryDialog(ref: ref),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CategoryModel category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: Text('Are you sure you want to delete "${category.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final tenantId = ref.read(currentTenantIdProvider);
              await ref.read(adminFirestoreServiceProvider).deleteCategory(category.id, tenantId);
              if (context.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AddCategoryDialog extends HookConsumerWidget {
  final WidgetRef ref;
  const _AddCategoryDialog({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final iconCode = useState('0xe163'); // Default category icon

    return AlertDialog(
      title: const Text('Add New Category'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Category Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
                child: Icon(IconData(int.tryParse(iconCode.value) ?? 0xe163, fontFamily: 'MaterialIcons')),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () async {
                    final code = await showDialog<String>(context: context, builder: (ctx) => const IconSelectorDialog());
                    if (code != null) iconCode.value = code;
                  },
                  child: const Text('Select Icon'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (nameController.text.isNotEmpty) {
              final tenantId = ref.read(currentTenantIdProvider);
              await ref.read(adminFirestoreServiceProvider).addCategory(
                CategoryModel(id: '', name: nameController.text.trim(), icon: iconCode.value),
                tenantId,
              );
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
