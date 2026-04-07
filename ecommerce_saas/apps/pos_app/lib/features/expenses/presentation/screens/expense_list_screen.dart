import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import '../providers/expense_providers.dart';
import '../../data/expense_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import 'package:intl/intl.dart';

class ExpenseListScreen extends ConsumerWidget {
  const ExpenseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المصاريف (Expenses)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 28),
            onPressed: () => _showAddExpenseDialog(context, ref),
          ),
        ],
      ),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return const Center(child: Text('لا توجد مصاريف مسجلة'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: expenses.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final expense = expenses[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red[50],
                  child: const Icon(Icons.outbox, color: Colors.red),
                ),
                title: Text(expense.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (expense.description.isNotEmpty) Text(expense.description),
                    Text(DateFormat('yyyy/MM/dd - hh:mm a').format(expense.date), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${expense.amount.toStringAsFixed(0)} IQD',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.grey),
                      onPressed: () => _confirmDelete(context, ref, expense),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      bottomNavigationBar: _buildSummaryBar(ref),
    );
  }

  Widget _buildSummaryBar(WidgetRef ref) {
    final total = ref.watch(totalExpensesProvider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('إجمالي المصاريف:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Text(
            '${total.toStringAsFixed(0)} IQD',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ],
      ),
    );
  }

  void _showAddExpenseDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _AddExpenseDialog(),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ExpenseModel expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مصروف'),
        content: const Text('هل أنت متأكد من حذف هذا المصروف؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );

    if (confirmed == true) {
      final tenantId = ref.read(tenantIdProvider);
      await ref.read(expenseRepositoryProvider).deleteExpense(tenantId, expense.id);
    }
  }
}

class _AddExpenseDialog extends HookConsumerWidget {
  const _AddExpenseDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryController = useTextEditingController();
    final amountController = useTextEditingController();
    final descController = useTextEditingController();
    final isLoading = useState(false);

    final categories = ['إيجار', 'كهرباء', 'رواتب', 'أخرى'];

    return AlertDialog(
      title: const Text('إضافة مصروف جديد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'الفئة (Category)'),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => categoryController.text = val ?? '',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'المبلغ (Amount)', suffixText: 'IQD'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'ملاحظات (Description)'),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: isLoading.value ? null : () async {
            if (categoryController.text.isEmpty || amountController.text.isEmpty) return;
            
            isLoading.value = true;
            try {
              final tenantId = ref.read(tenantIdProvider);
              final expense = ExpenseModel(
                id: '',
                tenantId: tenantId,
                category: categoryController.text,
                amount: double.tryParse(amountController.text) ?? 0.0,
                description: descController.text,
                date: DateTime.now(),
              );
              await ref.read(expenseRepositoryProvider).addExpense(tenantId, expense);
              if (context.mounted) Navigator.pop(context);
            } finally {
              isLoading.value = false;
            }
          },
          child: isLoading.value ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ'),
        ),
      ],
    );
  }
}
