import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../data/car_contracts_repository.dart';
import 'package:intl/intl.dart';
import 'car_contract_print_preview.dart';

class CarContractsListScreen extends HookConsumerWidget {
  const CarContractsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final contractsAsync = ref.watch(carContractsProvider(tenantId));
    final searchQuery = useState('');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'البحث عن عقد (اسم بائع، مشتري، رقم سيارة)...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (v) => searchQuery.value = v,
          ),
        ),
        Expanded(
          child: contractsAsync.when(
            data: (contracts) {
              final filtered = contracts.where((c) {
                final query = searchQuery.value.toLowerCase();
                return c.sellerName.toLowerCase().contains(query) ||
                       c.buyerName.toLowerCase().contains(query) ||
                       (c.carPlate?.toLowerCase().contains(query) ?? false) ||
                       (c.carModelName.toLowerCase().contains(query));
              }).toList();

              if (filtered.isEmpty) {
                return const Center(child: Text('لا توجد عقود مطابقة'));
              }

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final contract = filtered[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                      title: Text('${contract.carModelName} - ${contract.carPlate ?? "بدون رقم"}'),
                      subtitle: Text('البائع: ${contract.sellerName} | المشتري: ${contract.buyerName}\nالتاريخ: ${DateFormat('yyyy/MM/dd HH:mm').format(contract.createdAt)}'),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${contract.priceTotal} د.ع', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                          const SizedBox(width: 16),
                          IconButton(
                            icon: const Icon(Icons.print, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => CarContractPrintPreview(contract: contract)));
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('تأكيد الحذف'),
                                  content: const Text('هل أنت متأكد من حذف هذا العقد؟'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ref.read(carContractsRepositoryProvider).deleteContract(tenantId, contract.id);
                                ref.invalidate(carContractsProvider(tenantId));
                              }
                            },
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('خطأ: $e')),
          ),
        ),
      ],
    );
  }
}
