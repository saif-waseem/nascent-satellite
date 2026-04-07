import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart' as sm;
import '../../data/sales_repository.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../products/data/product_repository.dart';
import '../widgets/variant_picker_dialog.dart';

class ReturnExchangeScreen extends HookConsumerWidget {
  const ReturnExchangeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchedInvoice = useState<sm.SalesInvoiceModel?>(null);
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);

    // Maps original item index to returned quantity
    final returnQuantities = useState<Map<int, int>>({});
    // List of new items being bought in exchange
    final exchangeItems = useState<List<sm.SalesItem>>([]);

    final tenantId = ref.watch(tenantIdProvider);

    void searchInvoice() async {
      final receiptNum = searchController.text.trim();
      if (receiptNum.isEmpty) return;
      
      isLoading.value = true;
      errorMessage.value = null;
      returnQuantities.value = {};
      exchangeItems.value = [];
      
      try {
        final result = await ref.read(salesRepositoryProvider).getInvoiceByReceiptNumber(tenantId, receiptNum);
        if (result == null) {
          errorMessage.value = "لم يتم العثور على الفاتورة. تأكد من رقم الوصل.";
          searchedInvoice.value = null;
        } else {
          searchedInvoice.value = result;
        }
      } catch (e) {
        errorMessage.value = "خطأ في البحث: $e";
      } finally {
        isLoading.value = false;
      }
    }

    // Calculations
    double totalReturnAmount = 0.0;
    if (searchedInvoice.value != null) {
      for (final entry in returnQuantities.value.entries) {
        final invoiceItem = searchedInvoice.value!.items[entry.key];
        totalReturnAmount += (invoiceItem.unitPrice * entry.value);
      }
    }

    double totalExchangeAmount = 0.0;
    for (final item in exchangeItems.value) {
      totalExchangeAmount += (item.unitPrice * item.quantity);
    }

    final netDifference = totalExchangeAmount - totalReturnAmount;

    void submitTransaction() async {
      if (searchedInvoice.value == null) return;
      if (returnQuantities.value.isEmpty && exchangeItems.value.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء تحديد مواد للإرجاع أو الاستبدال')));
        return;
      }

      final returnedItemsList = <sm.SalesItem>[];
      for (final entry in returnQuantities.value.entries) {
        if (entry.value > 0) {
          final original = searchedInvoice.value!.items[entry.key];
          returnedItemsList.add(sm.SalesItem(
            productId: original.productId,
            productName: original.productName,
            quantity: entry.value,
            unitPrice: original.unitPrice,
            category: original.category,
            variantColor: original.variantColor,
            variantSize: original.variantSize,
            discount: original.discount,
          ));
        }
      }

      try {
        await ref.read(salesRepositoryProvider).processReturnAndExchange(
          tenantId: tenantId,
          originalInvoice: searchedInvoice.value!,
          returnedItems: returnedItemsList,
          exchangeItems: exchangeItems.value,
          totalReturnAmount: totalReturnAmount,
          totalExchangeAmount: totalExchangeAmount,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تنفيذ المرتجع/الاستبدال بنجاح!'), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } catch (e) {
        if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التنفيذ: $e'), backgroundColor: Colors.red));
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('إدارة الراجع والاستبدال')),
      body: Row(
        children: [
          // Left Panel: Search & Return Selection
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('1. البحث عن الفاتورة الأصلية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          decoration: const InputDecoration(
                            hintText: 'أدخل رقم الوصل',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => searchInvoice(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: searchInvoice, child: const Text('بحث')),
                    ],
                  ),
                  if (isLoading.value) const Padding(padding: EdgeInsets.all(16.0), child: Center(child: CircularProgressIndicator())),
                  if (errorMessage.value != null) Padding(padding: const EdgeInsets.all(16.0), child: Text(errorMessage.value!, style: const TextStyle(color: Colors.red))),
                  const Divider(height: 32),
                  if (searchedInvoice.value != null) ...[
                    Text('الفاتورة الأصلية (${searchedInvoice.value!.receiptNumber})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('تاريخ: ${searchedInvoice.value!.date.toString().substring(0, 16)}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: searchedInvoice.value!.items.length,
                        itemBuilder: (context, index) {
                          final item = searchedInvoice.value!.items[index];
                          final returningQty = returnQuantities.value[index] ?? 0;
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text('السعر: ${item.unitPrice} | الكمية المشترات: ${item.quantity}', style: const TextStyle(fontSize: 12)),
                                        if (item.variantColor != null || item.variantSize != null)
                                          Text('المتغير: ${item.variantColor ?? ''} ${item.variantSize ?? ''}', style: const TextStyle(color: Colors.blueGrey, fontSize: 10)),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                        onPressed: returningQty > 0 ? () {
                                          final newMap = Map<int, int>.from(returnQuantities.value);
                                          newMap[index] = returningQty - 1;
                                          if (newMap[index] == 0) newMap.remove(index);
                                          returnQuantities.value = newMap;
                                        } : null,
                                      ),
                                      Text(returningQty.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      IconButton(
                                        icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                        onPressed: returningQty < item.quantity ? () {
                                          final newMap = Map<int, int>.from(returnQuantities.value);
                                          newMap[index] = returningQty + 1;
                                          returnQuantities.value = newMap;
                                        } : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          // Right Panel: New Exchange Items & Checkout sum
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('2. إضافة عناصر بديلة (استبدال)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  _ExchangeProductSearch(onProductSelected: (item) {
                    final newList = List<sm.SalesItem>.from(exchangeItems.value);
                    final existingIdx = newList.indexWhere((e) => e.productId == item.productId && e.variantColor == item.variantColor && e.variantSize == item.variantSize);
                    if (existingIdx >= 0) {
                      final existing = newList[existingIdx];
                      newList[existingIdx] = sm.SalesItem(
                        productId: existing.productId,
                        productName: existing.productName,
                        quantity: existing.quantity + 1,
                        unitPrice: existing.unitPrice,
                        category: existing.category,
                        variantColor: existing.variantColor,
                        variantSize: existing.variantSize,
                        discount: existing.discount,
                      );
                    } else {
                      newList.add(item);
                    }
                    exchangeItems.value = newList;
                  }),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: exchangeItems.value.length,
                      itemBuilder: (context, index) {
                        final item = exchangeItems.value[index];
                        return ListTile(
                          dense: true,
                          title: Text(item.productName),
                          subtitle: Text('السعر: ${item.unitPrice} | الكمية: ${item.quantity}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                            onPressed: () {
                              final newList = List<sm.SalesItem>.from(exchangeItems.value);
                              newList.removeAt(index);
                              exchangeItems.value = newList;
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  const Text('الخلاصة المادية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [const Text('إجمالي المرتجع:'), Text('${totalReturnAmount.toStringAsFixed(0)} IQD', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [const Text('إجمالي البدائل:'), Text('${totalExchangeAmount.toStringAsFixed(0)} IQD', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))],
                  ),
                  const Divider(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: netDifference > 0 ? Colors.orange[50] : (netDifference < 0 ? Colors.green[50] : Colors.grey[100]),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(netDifference > 0 ? 'المطلوب من الزبون الدفع:' : (netDifference < 0 ? 'المطلوب إرجاعه للزبون:' : 'لا يوجد فرق:'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${netDifference.abs().toStringAsFixed(0)} IQD', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: searchedInvoice.value == null ? null : submitTransaction,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('تنفيذ وتحديث المخزون', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExchangeProductSearch extends HookConsumerWidget {
  final Function(sm.SalesItem) onProductSelected;
  const _ExchangeProductSearch({required this.onProductSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final results = useState<List<sm.ProductModel>>([]);
    final isLoading = useState(false);

    void onSearch(String query) async {
      if (query.isEmpty) {
        results.value = [];
        return;
      }
      isLoading.value = true;
      final tenantId = ref.read(tenantIdProvider);
      final allProducts = await ref.read(productRepositoryProvider).getProducts(tenantId);
      
      results.value = allProducts.where((p) => 
        p.name.toLowerCase().contains(query.toLowerCase()) || 
        (p.barcode?.contains(query) ?? false)
      ).take(10).toList();
      
      isLoading.value = false;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: searchController,
          onChanged: onSearch,
          decoration: InputDecoration(
            hintText: 'ابحث بالاسم أو الباركود',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        if (isLoading.value) const LinearProgressIndicator(),
        if (results.value.isNotEmpty)
          Container(
            height: 150,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300)),
            child: ListView.builder(
              itemCount: results.value.length,
              itemBuilder: (context, index) {
                final product = results.value[index];
                return ListTile(
                  dense: true,
                  title: Text(product.name),
                  subtitle: Text('${product.price} IQD'),
                  onTap: () async {
                    if (product.variants.isNotEmpty) {
                      final variant = await showDialog<sm.ProductVariant>(
                        context: context,
                        builder: (ctx) => VariantPickerDialog(product: product),
                      );
                      if (variant != null) {
                        onProductSelected(sm.SalesItem(
                          productId: product.id,
                          productName: product.name,
                          quantity: 1,
                          unitPrice: variant.price ?? product.price,
                          category: product.category,
                          variantColor: variant.color,
                          variantSize: variant.size,
                        ));
                        searchController.clear();
                        results.value = [];
                      }
                    } else {
                      onProductSelected(sm.SalesItem(
                        productId: product.id,
                        productName: product.name,
                        quantity: 1,
                        unitPrice: product.price,
                        category: product.category,
                      ));
                      searchController.clear();
                      results.value = [];
                    }
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}
