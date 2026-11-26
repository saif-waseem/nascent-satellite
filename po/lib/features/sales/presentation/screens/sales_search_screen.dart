import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import '../../data/sales_repository.dart';
import '../providers/sales_pos_provider.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/utils/printing_service.dart';

class SalesSearchScreen extends HookConsumerWidget {
  const SalesSearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptController = useTextEditingController();
    final searchResult = useState<SalesInvoiceModel?>(null);
    final isLoading = useState(false);
    final tenantId = ref.watch(tenantIdProvider);

    void search(String value) async {
      if (value.isEmpty) return;
      isLoading.value = true;
      final result = await ref
          .read(salesRepositoryProvider)
          .getInvoiceByReceiptNumber(tenantId, value);
      searchResult.value = result;
      isLoading.value = false;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الوصل غير موجود / Receipt not found')),
        );
      }
    }

    final salesAsync = ref.watch(salesListProvider);
    final selectedDate = useState<DateTime?>(null);

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المبيعات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (date != null) selectedDate.value = date;
            },
          ),
          if (selectedDate.value != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => selectedDate.value = null,
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar for specific receipt
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: receiptController,
              decoration: InputDecoration(
                labelText: 'رقم الوصل',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => search(receiptController.text),
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: search,
            ),
          ),
          if (selectedDate.value != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Chip(
                label: Text('التاريخ: ${selectedDate.value!.toString().split(' ')[0]}'),
                onDeleted: () => selectedDate.value = null,
              ),
            ),
          Expanded(
            child: searchResult.value != null
                ? SingleChildScrollView(
                    child: _SalesInvoiceDetailView(
                      invoice: searchResult.value!,
                      onReturn: () => search(receiptController.text),
                    ),
                  )
                : salesAsync.when(
                    data: (list) {
                      final filtered = selectedDate.value == null
                          ? list
                          : list.where((invoice) => 
                              invoice.date.year == selectedDate.value!.year &&
                              invoice.date.month == selectedDate.value!.month &&
                              invoice.date.day == selectedDate.value!.day).toList();
                      
                      if (filtered.isEmpty) {
                        return const Center(child: Text('لا توجد مبيعات في هذا التاريخ'));
                      }
                      return ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final invoice = filtered[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Text('وصل رقم: ${invoice.receiptNumber}'),
                              subtitle: Text('${invoice.date.toString().substring(0, 16)} | ${invoice.customerName ?? 'نقدي'}'),
                              trailing: Text('${invoice.totalAmount} ${invoice.currency ?? 'د.ع'}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                              onTap: () => searchResult.value = invoice,
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
      ),
    );
  }
}

class _SalesInvoiceDetailView extends HookConsumerWidget {
  final SalesInvoiceModel invoice;
  final VoidCallback onReturn;

  const _SalesInvoiceDetailView(
      {required this.invoice, required this.onReturn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('وصل رقم: ${invoice.receiptNumber}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
                Text(invoice.date.toString().substring(0, 16),
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
            const Divider(height: 32),
            Text('العميل: ${invoice.customerName ?? 'نقدي'}'),
            const SizedBox(height: 16),
            const Text('المواد المباعة:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invoice.items.length,
              itemBuilder: (context, index) {
                final item = invoice.items[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.productName),
                  subtitle: Text('الكمية: ${item.quantity} | السعر: ${item.unitPrice}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${item.totalPrice} IQD'),
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => _handleReturn(context, ref, item),
                        child: const Text('إرجاع'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الإجمالي النهائي:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('${invoice.totalAmount} ${invoice.currency ?? 'د.ع'}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.blue)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print),
                label: const Text('إعادة طباعة الوصل (Reprint)'),
                onPressed: () async {
                  final printer = ref.read(printingServiceProvider);
                  final shopInfo = ref.read(tenantProvider).asData?.value;
                  if (shopInfo != null) {
                    await printer.printSalesInvoice(
                      invoice: invoice, 
                      shopInfo: shopInfo,
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleReturn(BuildContext context, WidgetRef ref, SalesItem item) async {
    final qtyController = TextEditingController(text: '1');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إرجاع مادة: ${item.productName}'),
        content: TextField(
          controller: qtyController,
          decoration: const InputDecoration(labelText: 'الكمية الراجعة'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('تأكيد الإرجاع')),
        ],
      ),
    );

    if (confirmed == true) {
      final returnQty = int.tryParse(qtyController.text) ?? 0;
      if (returnQty <= 0) return;
      if (returnQty > item.quantity) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('الكمية الراجعة أكبر من المباعة')));
        }
        return;
      }

      try {
        final tenantId = ref.read(tenantIdProvider);
        final returnedItem = SalesItem(
          productId: item.productId,
          productName: item.productName,
          quantity: returnQty,
          unitPrice: item.unitPrice,
          category: item.category,
          variantColor: item.variantColor,
          variantSize: item.variantSize,
        );

        await ref
            .read(salesRepositoryProvider)
            .processReturnAndExchange(
              tenantId: tenantId, 
              originalInvoice: invoice, 
              returnedItems: [returnedItem],
              exchangeItems: [],
              totalReturnAmount: returnQty * item.unitPrice,
              totalExchangeAmount: 0.0,
            );
        ref.invalidate(salesListProvider);
        onReturn();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم إرجاع المادة وتحديث المخزن')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        }
      }
    }
  }
}
