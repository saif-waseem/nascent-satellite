import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import '../providers/debt_providers.dart';
import '../../data/debt_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import 'package:intl/intl.dart';

class DebtManagementScreen extends HookConsumerWidget {
  const DebtManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة الديون / Debt Management'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_outline), text: 'ديون الزبائن'),
              Tab(icon: Icon(Icons.business_outlined), text: 'ديون الموردين'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CustomerDebtsView(),
            SupplierDebtsView(),
          ],
        ),
      ),
    );
  }
}

class CustomerDebtsView extends HookConsumerWidget {
  const CustomerDebtsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customersAsync = ref.watch(customerDebtsProvider);
    final searchController = useTextEditingController();
    final filter = useState('');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: searchController,
            onChanged: (v) => filter.value = v,
            decoration: InputDecoration(
              hintText: 'بحث عن زبون...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        Expanded(
          child: customersAsync.when(
            data: (list) {
              final query = filter.value.toLowerCase();
              final filtered = list.where((c) => 
                c.name.toLowerCase().contains(query) || 
                c.phoneNumber.contains(query)
              ).toList();
              if (filtered.isEmpty) return const Center(child: Text('لا يوجد ديون مسجلة'));
              
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final customer = filtered[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(customer.phoneNumber),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('المبلغ المطلوب:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                '${customer.balance.toStringAsFixed(0)} IQD',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.history, color: Colors.blue),
                            onPressed: () => _showHistoryBottomSheet(context, ref, customer: customer),
                          ),
                        ],
                      ),
                      onTap: () => _showPaymentDialog(context, ref, customer: customer),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

class SupplierDebtsView extends HookConsumerWidget {
  const SupplierDebtsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(supplierDebtsProvider);
    final searchController = useTextEditingController();
    final filter = useState('');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: searchController,
            onChanged: (v) => filter.value = v,
            decoration: InputDecoration(
              hintText: 'بحث عن مورد...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        Expanded(
          child: suppliersAsync.when(
            data: (list) {
              final query = filter.value.toLowerCase();
              final filtered = list.where((s) => 
                s.name.toLowerCase().contains(query) || 
                s.phoneNumber.contains(query)
              ).toList();
              if (filtered.isEmpty) return const Center(child: Text('لا يوجد ديون للموردين'));
              
              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final supplier = filtered[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      title: Text(supplier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(supplier.phoneNumber),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('المبلغ المتبقي:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                '${supplier.balance.toStringAsFixed(0)} IQD',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 16),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.history, color: Colors.blue),
                            onPressed: () => _showHistoryBottomSheet(context, ref, supplier: supplier),
                          ),
                        ],
                      ),
                      onTap: () => _showPaymentDialog(context, ref, supplier: supplier),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }
}

void _showPaymentDialog(BuildContext context, WidgetRef ref, {CustomerModel? customer, SupplierModel? supplier}) {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  final localCustomer = customer;
  final localSupplier = supplier;
  final isCustomer = localCustomer != null;
  final name = isCustomer ? localCustomer.name : localSupplier!.name;
  final currentBalance = isCustomer ? localCustomer.balance : localSupplier!.balance;

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text('إدارة حساب: $name'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الرصيد الحالي: ${currentBalance.toStringAsFixed(0)} IQD', 
                     style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'المبلغ',
                    border: OutlineInputBorder(),
                    suffixText: 'IQD',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظة (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: () => _handleAction(context, ref, true, isCustomer, localCustomer, localSupplier, amountController.text, noteController.text),
                      child: const Text('تسديد مبلغ (خصم)'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => _handleAction(context, ref, false, isCustomer, localCustomer, localSupplier, amountController.text, noteController.text),
                      child: const Text('إضافة دين'),
                    ),
                  ],
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
          ],
        );
      }
    ),
  );
}

void _handleAction(BuildContext context, WidgetRef ref, bool isPayment, bool isCustomer, CustomerModel? localCustomer, SupplierModel? localSupplier, String amountStr, String note) async {
  final amount = double.tryParse(amountStr) ?? 0.0;
  if (amount <= 0) return;
  
  try {
    final tenantId = ref.read(tenantIdProvider);
    final repo = ref.read(debtRepositoryProvider);
    
    if (isCustomer) {
      if (isPayment) {
        await repo.recordCustomerPayment(tenantId, localCustomer!.id, amount, note: note);
      } else {
        await repo.recordCustomerDebt(tenantId, localCustomer!.id, amount, note: note);
      }
    } else {
      if (isPayment) {
        await repo.recordSupplierPayment(tenantId, localSupplier!.id, amount, note: note);
      } else {
        await repo.recordSupplierDebt(tenantId, localSupplier!.id, amount, note: note);
      }
    }
    
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تسجيل العملية بنجاح')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }
}

void _showHistoryBottomSheet(BuildContext context, WidgetRef ref, {CustomerModel? customer, SupplierModel? supplier}) {
  final isCustomer = customer != null;
  final id = isCustomer ? customer.id : supplier!.id;
  final name = isCustomer ? customer.name : supplier!.name;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            height: 4, width: 40,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('سجل المعاملات: $name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          Expanded(
            child: Consumer(
              builder: (context, ref, child) {
                final transactionsAsync = isCustomer 
                    ? ref.watch(customerTransactionsProvider(id))
                    : ref.watch(supplierTransactionsProvider(id));

                return transactionsAsync.when(
                  data: (list) {
                    if (list.isEmpty) return const Center(child: Text('لا توجد معاملات مسجلة'));
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final trans = list[index];
                        final amount = (trans['amount'] as num).toDouble();
                        final type = trans['type'] as String;
                        final date = (trans['date'] as Timestamp?)?.toDate() ?? DateTime.now();
                        final note = trans['note'] as String? ?? '';
                        final isDebt = type == 'debt';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDebt ? Colors.red[50] : Colors.green[50],
                            child: Icon(isDebt ? Icons.arrow_upward : Icons.arrow_downward, 
                                        color: isDebt ? Colors.red : Colors.green),
                          ),
                          title: Text(isDebt ? 'دين جديد' : 'تسديد مبلغ', 
                                     style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${DateFormat('yyyy/MM/dd HH:mm').format(date)}\n$note'),
                          trailing: Text(
                            '${isDebt ? '+' : '-'}${amount.toStringAsFixed(0)} IQD',
                            style: TextStyle(fontWeight: FontWeight.bold, color: isDebt ? Colors.red : Colors.green, fontSize: 16),
                          ),
                          isThreeLine: true,
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
