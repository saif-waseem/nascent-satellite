import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../providers/category_provider.dart';
import '../../data/category_repository.dart';
import '../../../../core/providers/tenant_provider.dart';

class CategoryManagementScreen extends ConsumerWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التصنيفات'),
      ),
      body: categoriesAsync.when(
        data: (categories) => ListView.builder(
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            return ListTile(
              title: Text(category.name),
              trailing: IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDelete(context, ref, category),
              ),
              onTap: () => _showCategoryDialog(context, ref, category: category),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCategoryDialog(BuildContext context, WidgetRef ref, {CategoryModel? category}) {
    final controller = TextEditingController(text: category?.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'إضافة تصنيف' : 'تعديل تصنيف'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم التصنيف'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;

              final tenantId = ref.read(tenantIdProvider);
              if (category == null) {
                await ref.read(categoryRepositoryProvider).addCategory(tenantId, CategoryModel(id: '', name: name, icon: 'folder'));
              } else {
                await ref.read(categoryRepositoryProvider).updateCategory(tenantId, category.copyWith(name: name));
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, CategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('هل أنت متأكد من حذف تصنيف "${category.name}"؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              final tenantId = ref.read(tenantIdProvider);
              await ref.read(categoryRepositoryProvider).deleteCategory(tenantId, category.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
