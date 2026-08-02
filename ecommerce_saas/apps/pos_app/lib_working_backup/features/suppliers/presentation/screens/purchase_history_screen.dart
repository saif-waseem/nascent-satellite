import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import '../../data/purchase_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import 'purchase_invoice_detail_screen.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../../core/utils/printing_service.dart';

import '../../../../core/widgets/barcode_scanner_dialog.dart';

final allPurchaseInvoicesProvider = FutureProvider.autoDispose((ref) {
  final tenantId = ref.watch(tenantIdProvider);
  return ref.watch(purchaseRepositoryProvider).getAllInvoices(tenantId);
});

class PurchaseHistoryScreen extends HookConsumerWidget {
  const PurchaseHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(allPurchaseInvoicesProvider);
    final searchQuery = useState('');

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المشتريات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _openScanner(context, invoicesAsync.asData?.value ?? []),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => searchQuery.value = val,
              decoration: InputDecoration(
                hintText: 'بحث باسم المورد أو المعرف...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
        ),
      ),
      body: invoicesAsync.when(
        data: (invoices) {
          final filteredInvoices = invoices.where((inv) => 
            (inv.supplierName?.contains(searchQuery.value) ?? false) ||
            inv.id.contains(searchQuery.value)
          ).toList();

          if (filteredInvoices.isEmpty) {
            return const Center(child: Text('لا توجد فواتير مطابقة للبحث.'));
          }

          return ListView.builder(
            itemCount: filteredInvoices.length,
            itemBuilder: (context, index) {
              final invoice = filteredInvoices[index];
              return ListTile(
                leading: const Icon(Icons.receipt_long, color: Colors.green),
                title: Text(invoice.supplierName ?? 'مورد غير معروف'),
                subtitle: Text('التاريخ: ${invoice.date.toString().substring(0, 16)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${invoice.totalAmount.toStringAsFixed(0)} IQD', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(invoice.status == PurchaseInvoiceStatus.finalized ? 'مكتملة' : 'مسودة', 
                             style: TextStyle(fontSize: 10, color: invoice.status == PurchaseInvoiceStatus.finalized ? Colors.green : Colors.orange)),
                      ],
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.print, size: 20, color: Colors.blue),
                      onPressed: () => ref.read(printingServiceProvider).printPurchaseInvoice(invoice),
                    ),
                  ],
                ),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseInvoiceDetailScreen(invoice: invoice)));
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _openScanner(BuildContext context, List<PurchaseInvoiceModel> currentInvoices) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => const BarcodeScannerDialog(),
    );
    if (result != null && result.isNotEmpty) {
      final found = currentInvoices.where((inv) => inv.id == result).toList();
      if (found.isNotEmpty) {
        if (context.mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PurchaseInvoiceDetailScreen(invoice: found.first)));
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('لم يتم العثور على الفاتورة')));
        }
      }
    }
  }
}
