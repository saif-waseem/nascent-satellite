import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import '../providers/suppliers_provider.dart';
import '../../data/supplier_repository.dart';
import '../../data/purchase_repository.dart';
import '../../../../../core/providers/tenant_provider.dart';
import 'supplier_detail_screen.dart';
import 'package:pos_app/features/suppliers/presentation/screens/purchase_invoice_detail_screen.dart';

class SupplierListScreen extends HookConsumerWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final suppliersAsync = ref.watch(suppliersFutureProvider);
    final searchQuery = useState('');

    return Scaffold(
      appBar: AppBar(
        title: const Text('الموردين / Suppliers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (v) => searchQuery.value = v,
              decoration: InputDecoration(
                hintText: 'بحث عن مورد...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: suppliersAsync.when(
        data: (suppliers) {
          final filtered = suppliers.where((s) => s.name.toLowerCase().contains(searchQuery.value.toLowerCase())).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('لا يوجد موردين بهذا الاسم'));
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final supplier = filtered[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(supplier.phoneNumber),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('الرصيد:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        '${supplier.balance.toStringAsFixed(0)} IQD',
                        style: TextStyle(
                          color: supplier.balance > 0 ? Colors.red : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupplierDetailScreen(supplier: supplier),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSupplierDialog(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة مورد'),
      ),
    );
  }

  void _showAddSupplierDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => _SupplierFormDialog(),
    );
  }
}

class SupplierInvoicesScreen extends ConsumerWidget {
  final SupplierModel supplier;
  final String tenantId;

  const SupplierInvoicesScreen({super.key, required this.supplier, required this.tenantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(purchasesListProvider(tenantId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(supplier.name),
            Text(
              'الرصيد: ${supplier.balance.toStringAsFixed(0)} IQD',
              style: TextStyle(
                fontSize: 13,
                color: supplier.balance > 0 ? Colors.red.shade200 : Colors.green.shade200,
              ),
            ),
          ],
        ),
      ),
      body: invoicesAsync.when(
        data: (allInvoices) {
          final invoices = allInvoices.where((inv) => inv.supplierId == supplier.id).toList();
          
          if (invoices.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد فواتير لهذا المورد', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: invoices.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final inv = invoices[i];
              final isPaid = inv.remainingAmount <= 0;
              return Card(
                child: ListTile(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseInvoiceDetailScreen(invoice: inv))),
                  leading: CircleAvatar(
                    backgroundColor: isPaid ? Colors.green.shade100 : Colors.orange.shade100,
                    child: Icon(
                      isPaid ? Icons.check_circle_outline : Icons.pending_outlined,
                      color: isPaid ? Colors.green : Colors.orange,
                    ),
                  ),
                  title: Text(
                    'فاتورة #${inv.id.substring(0, 6).toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    inv.date.toString().substring(0, 10),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${inv.totalAmount.toStringAsFixed(0)} IQD',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        isPaid ? 'مدفوع' : 'متبقي: ${inv.remainingAmount.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isPaid ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('خطأ: $err')),
      ),
    );
  }
}

class _SupplierFormDialog extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameController = useTextEditingController();
    final phoneController = useTextEditingController();
    final isLoading = useState(false);

    return AlertDialog(
      title: const Text('إضافة مورد جديد'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'اسم المورد',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
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
              final supplier = SupplierModel(
                id: '',
                tenantId: tenantId,
                name: nameController.text,
                phoneNumber: phoneController.text,
                createdAt: DateTime.now(),
              );
              await ref.read(supplierRepositoryProvider).addSupplier(tenantId, supplier);
              ref.invalidate(suppliersFutureProvider);
              if (context.mounted) Navigator.pop(context);
            } finally {
              isLoading.value = false;
            }
          },
          child: isLoading.value
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('حفظ'),
        ),
      ],
    );
  }
}
