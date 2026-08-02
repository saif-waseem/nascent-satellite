import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/utils/printing_service.dart';
import 'package:pos_app/features/suppliers/data/purchase_repository.dart';
import '../../../../core/providers/tenant_provider.dart';

class PurchaseInvoiceDetailScreen extends HookConsumerWidget {
  final PurchaseInvoiceModel invoice;

  const PurchaseInvoiceDetailScreen({super.key, required this.invoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formatCurrency = NumberFormat.currency(symbol: 'IQD', decimalDigits: 0);
    final isFinalizing = useState(false);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل فاتورة المشتريات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              ref.read(printingServiceProvider).printPurchaseInvoice(invoice);
            },
            tooltip: 'إعادة طباعة الفاتورة',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildInvoiceHeader(),
          const Divider(thickness: 2),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Colors.blue),
                SizedBox(width: 8),
                Text('المنتجات (المواد المشتراة)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
          Expanded(
            child: invoice.items.isEmpty 
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('لا توجد مواد مسجلة في هذه الفاتورة', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: invoice.items.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = invoice.items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${item.quantity} وحدة × ${formatCurrency.format(item.unitCost)}'),
                      trailing: Text(
                        formatCurrency.format(item.totalCost),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                      ),
                    );
                  },
                ),
          ),
          _buildInvoiceFooter(context, ref, formatCurrency, isFinalizing),
        ],
      ),
    );
  }

  Widget _buildInvoiceHeader() {
    final isDraft = invoice.status == PurchaseInvoiceStatus.draft;
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDraft ? Colors.orange.shade50 : Colors.green.shade50,
        border: Border(bottom: BorderSide(color: isDraft ? Colors.orange.shade200 : Colors.green.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('المورد: ${invoice.supplierName ?? 'غير معروف'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDraft ? Colors.orange : Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isDraft ? 'مسودة / Draft' : 'تم الوصول / Finalized',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(DateFormat('yyyy/MM/dd hh:mm a').format(invoice.date), style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              Text('المعرف: ${invoice.id.substring(0, 8)}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceFooter(BuildContext context, WidgetRef ref, NumberFormat formatCurrency, ValueNotifier<bool> isFinalizing) {
    final isDraft = invoice.status == PurchaseInvoiceStatus.draft;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجمالي الفاتورة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(formatCurrency.format(invoice.totalAmount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          if (!isDraft) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المبلغ المدفوع (الواصل):', style: TextStyle(fontSize: 16, color: Colors.green)),
                Text(formatCurrency.format(invoice.paidAmount), style: const TextStyle(fontSize: 16, color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
          if (isDraft) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isFinalizing.value ? null : () => _finalizeInvoice(context, ref, isFinalizing),
                icon: isFinalizing.value 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
                label: const Text('تأكيد الاستلام والترحيل للمخزن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'عند الضغط، سيتم زيادة الكميات في المخزن وتحديث حساب المورد.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _finalizeInvoice(BuildContext context, WidgetRef ref, ValueNotifier<bool> isFinalizing) async {
    isFinalizing.value = true;
    try {
      final tenantId = ref.read(tenantIdProvider);
      final repo = ref.read(purchaseRepositoryProvider);
      
      // Update status to finalized
      final updatedInvoice = invoice.copyWith(status: PurchaseInvoiceStatus.finalized);
      
      await repo.saveInvoice(tenantId, updatedInvoice);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ترحيل الفاتورة وتحديث المخزون بنجاح')));
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ أثناء الترحيل: $e')));
      }
    } finally {
      isFinalizing.value = false;
    }
  }
}

