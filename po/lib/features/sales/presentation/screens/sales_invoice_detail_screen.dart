import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/utils/printing_service.dart';

class SalesInvoiceDetailScreen extends ConsumerWidget {
  final SalesInvoiceModel invoice;

  const SalesInvoiceDetailScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatCurrency = NumberFormat.currency(symbol: 'IQD', decimalDigits: 0);
    final isReturn = invoice.isReturned;
    final shopInfo = ref.watch(tenantProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل الفاتورة: ${invoice.receiptNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              if (shopInfo != null) {
                ref.read(printingServiceProvider).printSalesInvoice(
                  invoice: invoice, 
                  shopInfo: shopInfo,
                );
              }
            },
            tooltip: 'إعادة طباعة',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummaryHeader(isReturn, formatCurrency),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.shopping_basket_outlined, size: 20),
                SizedBox(width: 8),
                Text('قائمة المواد المباعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: invoice.items.length,
              itemBuilder: (context, index) {
                final item = invoice.items[index];
                String itemName = item.productName;
                if (item.variantColor != null || item.variantSize != null) {
                  itemName += ' (${item.variantColor ?? ''} ${item.variantSize ?? ''})';
                }

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(itemName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${item.quantity} × ${formatCurrency.format(item.unitPrice)}'),
                    trailing: Text(
                      formatCurrency.format(item.totalPrice),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          _buildFooter(formatCurrency),
        ],
      ),
    );
  }

  Widget _buildSummaryHeader(bool isReturn, NumberFormat formatCurrency) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isReturn ? Colors.red.shade50 : Colors.blue.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الزبون: ${invoice.customerName ?? 'زبون نقدي'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text('التاريخ: ${DateFormat('yyyy/MM/dd hh:mm a').format(invoice.date)}', style: const TextStyle(color: Colors.grey)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isReturn ? Colors.red : Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isReturn ? 'فاتورة راجع' : 'فاتورة مبيعات',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(NumberFormat formatCurrency) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FooterRow(label: 'المجموع:', value: formatCurrency.format(invoice.totalAmount + invoice.discountAmount)),
          if (invoice.discountAmount > 0)
            _FooterRow(label: 'الخصم:', value: '-${formatCurrency.format(invoice.discountAmount)}', color: Colors.red),
          const Divider(),
          _FooterRow(
            label: 'المطلوب دفعه:', 
            value: formatCurrency.format(invoice.totalAmount), 
            isBold: true, 
            fontSize: 22, 
            color: Colors.blue.shade800
          ),
           _FooterRow(
            label: 'المبلغ المدفوع:', 
            value: formatCurrency.format(invoice.paidAmount), 
            color: Colors.green
          ),
          if (invoice.totalAmount > invoice.paidAmount)
             _FooterRow(
            label: 'المتبقي (دين):', 
            value: formatCurrency.format(invoice.totalAmount - invoice.paidAmount), 
            color: Colors.orange.shade900,
             isBold: true
          ),
        ],
      ),
    );
  }
}

class _FooterRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool isBold;
  final double fontSize;

  const _FooterRow({
    required this.label, 
    required this.value, 
    this.color, 
    this.isBold = false, 
    this.fontSize = 16
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }
}
