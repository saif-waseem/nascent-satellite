import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../sales/data/sales_repository.dart';
import '../../../../core/utils/printing_service.dart';
import '../../../sales/presentation/screens/sales_invoice_detail_screen.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

final customerSalesProvider = FutureProvider.family<List<SalesInvoiceModel>, String>((ref, customerId) async {
  final tenantId = ref.watch(tenantIdProvider);
  return ref.read(salesRepositoryProvider).getSalesByCustomer(tenantId, customerId);
});

class CustomerDetailScreen extends HookConsumerWidget {
  final CustomerModel customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesAsync = ref.watch(customerSalesProvider(customer.id));
    final shopInfo = ref.watch(tenantProvider).value;

    final searchQuery = useState('');

    return Scaffold(
      appBar: AppBar(
        title: Text('سجل الزبون: ${customer.name}'),
      ),
      body: Column(
        children: [
          _buildCustomerSummaryHeader(context),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => searchQuery.value = val,
              decoration: InputDecoration(
                hintText: 'بحث في الفواتير (رقم الفاتورة)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('فواتير المبيعات السابقة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          Expanded(
            child: salesAsync.when(
              data: (invoices) {
                final filteredInvoices = invoices.where((inv) => 
                  inv.receiptNumber.contains(searchQuery.value) ||
                  (inv.customerName?.contains(searchQuery.value) ?? false)
                ).toList();

                if (filteredInvoices.isEmpty) {
                  return const Center(child: Text('لا توجد فواتير مطابقة للبحث.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredInvoices.length,
                  itemBuilder: (context, index) {
                    final invoice = filteredInvoices[index];
                    return _InvoiceTile(invoice: invoice, shopInfo: shopInfo);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('حدث خطأ: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSummaryHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue.withOpacity(0.05),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatCard(title: 'الديون المتبقية', value: customer.balance.toStringAsFixed(0), icon: Icons.account_balance_wallet, color: Colors.red),
          _StatCard(title: 'نقاط الولاء', value: customer.loyaltyPoints.toString(), icon: Icons.stars, color: Colors.orange),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: Colors.grey)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: color)),
      ],
    );
  }
}

class _InvoiceTile extends ConsumerWidget {
  final SalesInvoiceModel invoice;
  final TenantModel? shopInfo;

  const _InvoiceTile({required this.invoice, required this.shopInfo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatCurrency = NumberFormat.currency(symbol: 'IQD', decimalDigits: 0);
    final isReturn = invoice.isReturned;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => SalesInvoiceDetailScreen(invoice: invoice)));
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isReturn ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
          child: Icon(isReturn ? Icons.assignment_return : Icons.receipt_long, color: isReturn ? Colors.red : Colors.green),
        ),
        title: Text('رقم الفاتورة: ${invoice.receiptNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(DateFormat('yyyy/MM/dd hh:mm a').format(invoice.date), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 4),
            Text('${invoice.items.length} منتجات', style: const TextStyle(fontSize: 13)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(formatCurrency.format(invoice.totalAmount.abs()), style: TextStyle(fontWeight: FontWeight.bold, color: isReturn ? Colors.red : Colors.green, fontSize: 16)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () {
                if (shopInfo != null) {
                  ref.read(printingServiceProvider).printSalesInvoice(invoice: invoice, shopInfo: shopInfo!);
                }
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.print, size: 16, color: Colors.blue),
                  SizedBox(width: 4),
                  Text('إعادة طباعة', style: TextStyle(color: Colors.blue, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
