import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import '../providers/customer_providers.dart';
import '../../data/customer_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends HookConsumerWidget {
  const CustomerListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customersListProvider);
    final filteredCustomers = ref.watch(filteredCustomersProvider);
    final searchController = useTextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الزبائن'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, size: 28),
            onPressed: () => _showAddCustomerDialog(context, ref),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'البحث باسم الزبون أو رقم الهاتف...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (val) => ref.read(customerSearchProvider.notifier).set(val),
            ),
          ),
          Expanded(
            child: customersAsync.when(
              data: (list) {
                // Ensure list is not null and handled safely
                final displayList = filteredCustomers; 
                if (displayList.isEmpty) {
                  return const Center(child: Text('لا يوجد زبائن مطابقين أو مسجلين'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: displayList.length,
                  itemBuilder: (context, index) {
                    final customer = displayList[index];
                    return _CustomerCard(customer: customer);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) {
                debugPrint('Customer Scan Error: $err');
                return Center(child: Text('خطأ في تحميل البيانات: $err'));
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _CustomerFormDialog(),
    );
  }
}

class _CustomerCard extends ConsumerWidget {
  final CustomerModel customer;
  const _CustomerCard({required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: customer))),
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[50],
          child: const Icon(Icons.person, color: Colors.blue),
        ),
        title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.phone, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(customer.phoneNumber, style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _InfoChip(label: '${customer.loyaltyPoints} نقطة', color: Colors.orange, icon: Icons.stars),
                const SizedBox(width: 8),
                _InfoChip(
                  label: 'دين: ${customer.balance.toStringAsFixed(0)}', 
                  color: customer.balance > 0 ? Colors.red : Colors.green,
                  icon: Icons.account_balance_wallet,
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'edit', child: Text('تعديل')),
            const PopupMenuItem(value: 'delete', child: Text('حذف', style: TextStyle(color: Colors.red))),
          ],
          onSelected: (val) {
            if (val == 'edit') _showEditDialog(context, ref);
            if (val == 'delete') _confirmDelete(context, ref);
          },
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => _CustomerFormDialog(customer: customer),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الزبون'),
        content: Text('هل أنت متأكد من حذف ${customer.name}؟ لن يتم حذف بيانات الديون المرتبطة به ولكن سيفقد سجله.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );

    if (confirmed == true) {
      final tenantId = ref.read(tenantIdProvider);
      await ref.read(customerRepositoryProvider).deleteCustomer(tenantId, customer.id);
    }
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _InfoChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _CustomerFormDialog extends HookConsumerWidget {
  final CustomerModel? customer;
  const _CustomerFormDialog({this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController(text: customer?.name);
    final phoneController = useTextEditingController(text: customer?.phoneNumber);
    final isLoading = useState(false);

    return AlertDialog(
      title: Text(customer == null ? 'إضافة زبون جديد' : 'تعديل بيانات الزبون'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'اسم الزبون', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined)),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: isLoading.value ? null : () async {
            if (nameController.text.isEmpty) return;
            isLoading.value = true;
            try {
              final tenantId = ref.read(tenantIdProvider);
              final newCustomer = (customer ?? CustomerModel(
                id: '',
                tenantId: tenantId,
                name: '',
                phoneNumber: '',
                createdAt: DateTime.now(),
              )).copyWith(
                name: nameController.text,
                phoneNumber: phoneController.text,
              );

              if (customer == null) {
                await ref.read(customerRepositoryProvider).addCustomer(tenantId, newCustomer);
              } else {
                await ref.read(customerRepositoryProvider).updateCustomer(tenantId, newCustomer);
              }
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
