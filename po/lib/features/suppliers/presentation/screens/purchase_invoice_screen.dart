import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import '../widgets/add_item_dialog.dart';
import '../widgets/barcode_scanner_widget.dart';
import '../providers/purchase_invoice_provider.dart';
import '../../../products/data/product_repository.dart' as pos_prod;
import '../../data/purchase_repository.dart';
import '../providers/suppliers_provider.dart';
import '../../../../core/providers/tenant_provider.dart';

class PurchaseInvoiceScreen extends HookConsumerWidget {
  final SupplierModel? initialSupplier;
  const PurchaseInvoiceScreen({super.key, this.initialSupplier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(purchaseSessionProvider);
    final sessionManager = ref.read(purchaseSessionProvider.notifier);
    final activeInvoice = sessionState.activeInvoice;
    final tenantId = ref.watch(tenantIdProvider);
    final suppliersAsync = ref.watch(suppliersFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة شراء جديدة'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'فتح فاتورة أخرى',
            onPressed: () => sessionManager.addSession(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: _buildSessionTabs(context, ref, sessionState, sessionManager),
        ),
      ),
      body: Row(
        children: [
          // Left Side: Product Selection & Scanning
          Expanded(
            flex: 2,
            child: _buildProductSelection(context, ref, activeInvoice),
          ),
          const VerticalDivider(width: 1),
          // Right Side: Current Invoice Items & Summary
          Expanded(
            flex: 3,
            child: _buildInvoiceEditor(context, ref, activeInvoice, sessionManager, suppliersAsync),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTabs(BuildContext context, WidgetRef ref, PurchaseSessionState state, PurchaseSessionManager manager) {
    return Container(
      height: 50,
      color: Colors.blue.withOpacity(0.05),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: state.sessions.length,
        itemBuilder: (context, index) {
          final session = state.sessions[index];
          final isActive = state.activeIndex == index;
          return GestureDetector(
            onTap: () => manager.setActiveIndex(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? Colors.white : Colors.transparent,
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? Colors.blue : Colors.transparent,
                    width: 3,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    session.sessionName ?? 'فاتورة ${index + 1}',
                    style: TextStyle(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? Colors.blue : Colors.black54,
                    ),
                  ),
                  if (state.sessions.length > 1) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => manager.closeSession(index),
                      child: const Icon(Icons.close, size: 16, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductSelection(BuildContext context, WidgetRef ref, PurchaseInvoiceModel invoice) {
    final searchController = useTextEditingController();
    final searchResults = useState<List<ProductModel>>([]);
    final initialProducts = useState<List<ProductModel>>([]);
    final isLoading = useState(false);
    final error = useState<String?>(null);
    final tenantId = ref.watch(tenantIdProvider);

    // Initial load of products (Future-based for stability)
    useEffect(() {
      Future<void> loadInitial() async {
        isLoading.value = true;
        try {
          final repo = ref.read(pos_prod.productRepositoryProvider);
          final products = await repo.getProducts(tenantId);
          initialProducts.value = products;
        } catch (e) {
          error.value = 'فشل تحميل المنتجات: $e';
        } finally {
          isLoading.value = false;
        }
      }
      loadInitial();
      
      // If initialSupplier is provided, set it in the session
      if (initialSupplier != null) {
        Future.microtask(() {
          ref.read(purchaseSessionProvider.notifier).updateActiveSupplier(initialSupplier!.id, initialSupplier!.name);
        });
      }
      return null;
    }, [tenantId, initialSupplier]);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: (v) async {
              if (v.length > 1) {
                isLoading.value = true;
                error.value = null;
                try {
                  searchResults.value = await ref.read(pos_prod.productRepositoryProvider).searchProducts(tenantId, v);
                } catch (e) {
                  error.value = 'فشل البحث: $e';
                } finally {
                  isLoading.value = false;
                }
              } else {
                searchResults.value = [];
                isLoading.value = false;
              }
            },
            decoration: InputDecoration(
              hintText: 'ابحث عن منتج أو امسح الباركود...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (searchController.text.isNotEmpty)
                    IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      searchController.clear();
                      searchResults.value = [];
                    }),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () => _openScanner(context, ref, tenantId),
                  ),
                ],
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading.value && initialProducts.value.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : error.value != null
                    ? Center(child: Text(error.value!, style: const TextStyle(color: Colors.red)))
                    : (searchController.text.length > 1 && searchResults.value.isEmpty && !isLoading.value)
                        ? const Center(child: Text('لا توجد نتائج بحث مطابقة'))
                        : ListView.builder(
                            itemCount: searchController.text.length > 1 ? searchResults.value.length : initialProducts.value.length,
                            itemBuilder: (context, index) {
                              final product = searchController.text.length > 1 ? searchResults.value[index] : initialProducts.value[index];
                              return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('باركود: ${product.barcode ?? 'N/A'} | الكمية الحالية: ${product.stockQuantity}'),
                              trailing: Text('${product.price} IQD', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                              onTap: () => _showAddItemDialog(context, ref, product),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showAddItemDialog(BuildContext context, WidgetRef ref, ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AddItemDialog(product: product),
    ).then((result) {
      if (result != null && result is InvoiceItem) {
        ref.read(purchaseSessionProvider.notifier).addItemToActive(result);
      }
    });
  }

  void _openScanner(BuildContext context, WidgetRef ref, String tenantId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BarcodeScannerWidget(
          onDetect: (barcode) async {
            try {
              final product = await ref.read(pos_prod.productRepositoryProvider).getProductByBarcode(tenantId, barcode);
              if (product != null) {
                if (context.mounted) {
                  Navigator.pop(context); // Close scanner
                  _showAddItemDialog(context, ref, product);
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('المنتج بالباركود $barcode غير موجود')),
                  );
                }
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('خطأ في المسح: $e')),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Widget _buildInvoiceEditor(BuildContext context, WidgetRef ref, PurchaseInvoiceModel invoice, PurchaseSessionManager manager, AsyncValue<List<SupplierModel>> suppliersAsync) {
    return Column(
      children: [
        _buildSupplierHeader(context, ref, invoice, manager, suppliersAsync),
        const Divider(height: 1),
        Expanded(
          child: _buildItemsTable(context, invoice, manager),
        ),
        _buildInvoiceFooter(context, ref, invoice, manager),
      ],
    );
  }

  Widget _buildSupplierHeader(BuildContext context, WidgetRef ref, PurchaseInvoiceModel invoice, PurchaseSessionManager manager, AsyncValue<List<SupplierModel>> suppliersAsync) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.blue.withOpacity(0.05),
      child: InkWell(
        onTap: () => _showSupplierPicker(context, ref, manager, suppliersAsync),
        child: Row(
          children: [
            const Icon(Icons.person_outline, color: Colors.blue),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('المورد / Supplier', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  invoice.supplierId.isEmpty
                      ? 'اضغط لاختيار المورد...'
                      : (invoice.supplierName ?? invoice.supplierId),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildItemsTable(BuildContext context, PurchaseInvoiceModel invoice, PurchaseSessionManager manager) {
    if (invoice.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('الفاتورة فارغة، ابدأ بإضافة المنتجات', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: invoice.items.length,
      itemBuilder: (context, index) {
        final item = invoice.items[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: ListTile(
            title: Text(item.productName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.variantColor != null || item.variantSize != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${item.variantColor ?? ""} ${item.variantSize ?? ""}'.trim(),
                        style: TextStyle(color: Colors.blue.shade800, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                Text('الكمية: ${item.quantity} | السعر: ${item.unitCost} IQD', style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${item.totalCost.toStringAsFixed(0)} IQD', style: const TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => manager.removeItemFromActive(index),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoiceFooter(BuildContext context, WidgetRef ref, PurchaseInvoiceModel invoice, PurchaseSessionManager manager) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي العام:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${invoice.totalAmount.toStringAsFixed(0)} IQD', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => manager.resetActive(),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: const Text('تصفير'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: invoice.items.isEmpty || invoice.supplierId.isEmpty
                      ? null
                      : () => _handleCheckout(context, ref, invoice, manager),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('إتمام الشراء وحفظ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSupplierPicker(BuildContext context, WidgetRef ref, PurchaseSessionManager manager, AsyncValue<List<SupplierModel>> suppliersAsync) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('اختر المورد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Expanded(
              child: suppliersAsync.when(
                data: (list) => list.isEmpty 
                  ? const Center(child: Text('لا يوجد موردين مضافين'))
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final s = list[index];
                        return ListTile(
                          title: Text(s.name),
                          subtitle: Text(s.phoneNumber),
                          onTap: () {
                            manager.updateActiveSupplier(s.id, s.name);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleCheckout(BuildContext context, WidgetRef ref, PurchaseInvoiceModel invoice, PurchaseSessionManager manager) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final tenantId = ref.read(tenantIdProvider);
      final finalizedInvoice = invoice.copyWith(status: PurchaseInvoiceStatus.finalized);
      await ref.read(purchaseRepositoryProvider).saveInvoice(tenantId, finalizedInvoice);
      
      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إتمام عملية الشراء وتحديث المخزون بنجاح')));
        manager.resetActive();
        Navigator.pop(context); // Return to history/supplier screen if desired
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }
}
