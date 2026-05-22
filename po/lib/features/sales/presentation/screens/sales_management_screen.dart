import 'package:flutter/material.dart';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_models/shared_models.dart' as sm;
import 'return_exchange_screen.dart';
import '../providers/sales_pos_provider.dart';
import '../../data/sales_repository.dart';
import 'sales_search_screen.dart';
import '../../../products/data/product_repository.dart';
import '../../../products/presentation/providers/category_provider.dart';
import '../../../customers/presentation/providers/customer_providers.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../../core/providers/permissions_provider.dart';
import '../../../suppliers/presentation/widgets/barcode_scanner_widget.dart';
import '../../../../core/utils/printing_service.dart';
import '../widgets/variant_picker_dialog.dart';
import '../../../common/data/app_settings_repository.dart';
import '../../../common/data/printer_settings_repository.dart';
import '../../../settings/data/staff_repository.dart';
import '../../../products/presentation/providers/product_providers.dart';
import '../../../reports/data/report_repository.dart';
import '../../../reports/data/audit_repository.dart';
import '../../../staff/data/shift_repository.dart';
import '../../../staff/presentation/widgets/shift_management_dialog.dart';
import '../../../customers/data/customer_repository.dart';
import '../../../../core/widgets/smart_image.dart';

class SalesManagementScreen extends HookConsumerWidget {
  const SalesManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المبيعات / Point of Sale'),
          actions: [
             IconButton(
               tooltip: 'الراجع و الاستبدال',
               onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReturnExchangeScreen())),
               icon: const Icon(Icons.assignment_return_outlined, color: Colors.red),
             ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.point_of_sale), text: 'نقطة البيع (POS)'),
              Tab(icon: Icon(Icons.history), text: 'سجل المبيعات / البحث'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            POSCheckoutView(),
            SalesSearchScreen(),
          ],
        ),
      ),
    );
  }
}

class POSCheckoutView extends HookConsumerWidget {
  const POSCheckoutView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(salesSessionProvider);
    final sessionManager = ref.read(salesSessionProvider.notifier);
    final tenantId = ref.watch(tenantIdProvider);
    final staff = ref.watch(currentStaffProvider);

    // If no staff logged in or no active shift, show shift management
    if (staff == null) {
      return const Center(child: Text('يرجى اختيار الموظف أولاً من الإعدادات'));
    }

    final activeShiftAsync = ref.watch(activeShiftFutureProvider((tenantId: tenantId, staffId: staff.id)));

    return activeShiftAsync.when(
      data: (shift) {
        if (shift == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.blueGrey),
                const SizedBox(height: 16),
                const Text('يجب بدء شفت جديد قبل إتمام أي عملية بيع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => showDialog(context: context, builder: (_) => const ShiftManagementDialog()),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('بدء الشفت الآن'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        if (isMobile) {
          return Column(
            children: [
              _buildSessionRow(context, ref, sessionState, sessionManager, true),
              _buildCustomerSelectionRow(context, ref, sessionState.activeInvoice, sessionManager, true),
              Expanded(
                child: Stack(
                  children: [
                    _ProductSelectionPanel(activeInvoice: sessionState.activeInvoice, isMobile: true),
                    if (sessionState.activeInvoice.items.isNotEmpty)
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: _MobileCartBar(
                          activeInvoice: sessionState.activeInvoice, 
                          manager: sessionManager,
                          shiftId: shift.id,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildSessionRow(context, ref, sessionState, sessionManager, false),
            _buildCustomerSelectionRow(context, ref, sessionState.activeInvoice, sessionManager, false),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: _ProductSelectionPanel(activeInvoice: sessionState.activeInvoice, isMobile: false),
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(
                    flex: 1,
                    child: _POSCartPanel(activeInvoice: sessionState.activeInvoice, manager: sessionManager, isMobile: false, shiftId: shift.id),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  },
  loading: () => const Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text('جاري تحميل بيانات البيع والوردية...'),
        Text('(يرجى الانتظار، أو تأكد من تسجيل دخول الموظف)', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    ),
  ),
  error: (e, stack) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 16),
        Text('خطأ في جلب بيانات الوردية: $e'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => ref.refresh(activeShiftFutureProvider((tenantId: tenantId, staffId: staff.id))),
          child: const Text('إعادة المحاولة'),
        ),
      ],
    ),
  ),
);
  }

  Widget _buildSessionRow(BuildContext context, WidgetRef ref, SalesSessionState sessionState, SalesSessionManager sessionManager, bool isMobile) {
    return Container(
      height: 50,
      color: Colors.blueGrey[900],
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sessionState.sessions.length,
              itemBuilder: (context, index) {
                final session = sessionState.sessions[index];
                final isActive = sessionState.activeIndex == index;
                return InkWell(
                  onTap: () => sessionManager.setActiveIndex(index),
                  onLongPress: sessionState.sessions.length > 1 
                      ? () => _confirmCloseSession(context, sessionManager, index, session.sessionName ?? 'وصل ${index + 1}')
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.blueGrey[800],
                      border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? Icons.receipt : Icons.receipt_outlined, 
                          size: 14, 
                          color: isActive ? Colors.blue : Colors.white70
                        ),
                        const SizedBox(width: 8),
                        Text(
                          session.sessionName ?? 'وصل ${index + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.black : Colors.white,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                        if (!isMobile && sessionState.sessions.length > 1) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.close, size: 16, color: isActive ? Colors.red : Colors.white70),
                            onPressed: () => sessionManager.closeSession(index),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => sessionManager.addSession(),
          ),
          const VerticalDivider(width: 1, color: Colors.white24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Icon(Icons.warehouse_outlined, size: 16, color: Colors.white.withOpacity(0.7)),
          ),
          ref.watch(availableWarehousesProvider).when(
            data: (warehouses) {
              final selected = ref.watch(selectedWarehouseProvider);
              return DropdownButton<String?>(
                value: selected,
                dropdownColor: Colors.blueGrey[900],
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                hint: const Text('المخزن', style: TextStyle(color: Colors.white70, fontSize: 12)),
                style: const TextStyle(color: Colors.white, fontSize: 13),
                items: [
                  const DropdownMenuItem(value: null, child: Text('تلقائي', style: TextStyle(fontSize: 12))),
                  ...warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(fontSize: 12)))),
                ],
                onChanged: (val) => ref.read(selectedWarehouseProvider.notifier).set(val),
              );
            },
            loading: () => const SizedBox(width: 20, height: 20, child: Padding(padding: EdgeInsets.all(4), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
            error: (_, __) => const SizedBox(),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildCustomerSelectionRow(BuildContext context, WidgetRef ref, sm.SalesInvoiceModel invoice, SalesSessionManager manager, bool isMobile) {
    final children = [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_outline, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 8),
          const Text('الزبون / Customer:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
      const SizedBox(width: 12),
      ActionChip(
        label: Text(invoice.customerName ?? 'زبون نقدي (Cash)'),
        avatar: Icon(invoice.customerId == null ? Icons.add : Icons.edit, size: 16),
        onPressed: () => _showCustomerPicker(context, ref, manager),
        backgroundColor: invoice.customerId == null ? Colors.white : Colors.blue[50],
      ),
      if (invoice.customerId != null) ...[
        ref.watch(customersListProvider).when(
          data: (list) {
            final customer = list.where((c) => c.id == invoice.customerId).firstOrNull;
            if (customer == null) return const SizedBox();
            return Chip(
              label: Text('نقاط الولاء: ${customer.loyaltyPoints}'),
              backgroundColor: Colors.orange[50],
              labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            );
          },
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        ),
        IconButton(
          icon: const Icon(Icons.clear, size: 16, color: Colors.red),
          onPressed: () => manager.setCustomer(null, null),
        ),
      ],
      if (!isMobile) const Spacer(),
      ElevatedButton.icon(
        icon: const Icon(Icons.sync_alt, size: 16),
        label: const Text('الراجع و الاستبدال'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade600,
          foregroundColor: Colors.white,
          visualDensity: isMobile ? VisualDensity.compact : VisualDensity.standard,
        ),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReturnExchangeScreen())),
      ),
    ];

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.grey[100],
        child: Wrap(
          spacing: 8, 
          runSpacing: 8, 
          crossAxisAlignment: WrapCrossAlignment.center, 
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person_outline, size: 18, color: Colors.blueGrey),
                const SizedBox(width: 4),
                const Text('الزبون:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
            ActionChip(
              visualDensity: VisualDensity.compact,
              label: Text(invoice.customerName ?? 'زبون نقدي', style: const TextStyle(fontSize: 11)),
              avatar: Icon(invoice.customerId == null ? Icons.add : Icons.edit, size: 14),
              onPressed: () => _showCustomerPicker(context, ref, manager),
              backgroundColor: invoice.customerId == null ? Colors.white : Colors.blue[50],
            ),
            if (invoice.customerId != null) ...[
               ref.watch(customersListProvider).when(
                data: (list) {
                  final customer = list.where((c) => c.id == invoice.customerId).firstOrNull;
                  if (customer == null) return const SizedBox();
                  return Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${customer.loyaltyPoints} ن', style: const TextStyle(fontSize: 10)),
                    backgroundColor: Colors.orange[50],
                  );
                },
                loading: () => const SizedBox(),
                error: (_, __) => const SizedBox(),
              ),
              IconButton(
                icon: const Icon(Icons.clear, size: 14, color: Colors.red),
                onPressed: () => manager.setCustomer(null, null),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[100],
      child: Row(
        children: [
          ...children,
        ],
      ),
    );
  }

  void _showCustomerPicker(BuildContext context, WidgetRef ref, SalesSessionManager manager) {
    showDialog(
      context: context,
      builder: (ctx) => const CustomerPickerDialog(),
    ).then((customer) {
      if (customer != null && customer is sm.CustomerModel) {
        manager.setCustomer(customer.id, customer.name);
      }
    });
  }

  void _confirmCloseSession(BuildContext context, SalesSessionManager manager, int index, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إغلاق الوصل: $name'),
        content: const Text('هل أنت متأكد من إغلاق هذا الوصل؟ سيتم حذف جميع المواد غير المحفوظة.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              manager.closeSession(index);
              Navigator.pop(ctx);
            },
            child: const Text('إغلاق الوصل', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ProductSelectionPanel extends HookConsumerWidget {
  final sm.SalesInvoiceModel activeInvoice;
  final bool isMobile;
  const _ProductSelectionPanel({required this.activeInvoice, required this.isMobile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final results = useState<List<sm.ProductModel>>([]);
    final lastDocId = useState<String?>(null);
    final hasMore = useState(true);
    final isLoading = useState(false);
    final isWholesale = useState(false);
    final scrollController = useScrollController();

    final tenantId = ref.watch(tenantIdProvider);

    Future<void> loadProducts({bool reset = false}) async {
      if (isLoading.value || (!hasMore.value && !reset)) return;
      
      isLoading.value = true;
      try {
        final repo = ref.read(productRepositoryProvider);
        if (searchController.text.isNotEmpty) {
          final query = searchController.text;
          // Search mode (resets products)
          final matches = await repo.searchProducts(tenantId, query);
          results.value = matches;
          hasMore.value = false; // Search isn't paginated for now to save RAM

          // AUTO-ADD logic for Barcode scans
          if (matches.length == 1 && matches.first.barcode == query) {
            final product = matches.first;
            final currentPrice = isWholesale.value ? (product.wholesalePrice ?? product.price) : product.price;

            if (product.variants.isNotEmpty) {
              if (context.mounted) {
                final variant = await showDialog<sm.ProductVariant>(
                  context: context,
                  builder: (ctx) => VariantPickerDialog(product: product),
                );
                if (variant != null) {
                  ref.read(salesSessionProvider.notifier).addItemToActive(sm.SalesItem(
                    productId: product.id,
                    productName: product.name,
                    quantity: 1,
                    unitPrice: variant.price ?? currentPrice,
                    category: product.category,
                    variantColor: variant.color,
                    variantSize: variant.size,
                  ));
                }
              }
            } else {
              ref.read(salesSessionProvider.notifier).addItemToActive(sm.SalesItem(
                productId: product.id,
                productName: product.name,
                quantity: 1,
                unitPrice: currentPrice,
                category: product.category,
              ));
            }
            searchController.clear();
            loadProducts(reset: true);
          }
          hasMore.value = false;
        } else {
          // Paginated mode
          final lastCursor = reset ? null : lastDocId.value;
          final pResult = await repo.getProductsPaginated(tenantId, lastDocId: lastCursor, limit: 50);
          
          if (reset) {
            results.value = pResult.products;
          } else {
            results.value = [...results.value, ...pResult.products];
          }
          
          lastDocId.value = pResult.lastDocId;
          hasMore.value = pResult.products.length == 50;
        }
      } finally {
        isLoading.value = false;
      }
    }

    useEffect(() {
      loadProducts(reset: true);
      return null;
    }, []);

    useEffect(() {
      void listener() {
        if (scrollController.position.pixels >= scrollController.position.maxScrollExtent * 0.9) {
          if (searchController.text.isEmpty) {
            loadProducts();
          }
        }
      }
      scrollController.addListener(listener);
      return () => scrollController.removeListener(listener);
    }, [scrollController, searchController.text]);

    void onSearch(String query) {
      if (query.isEmpty) {
        loadProducts(reset: true);
        return;
      }
      loadProducts(reset: true);
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: 'بحث عن منتج...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    contentPadding: const EdgeInsets.all(8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                icon: const Icon(Icons.qr_code_scanner, size: 20),
                onPressed: () => _showScannerDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('نوع السعر:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              SegmentedButton<bool>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('مفرد', style: TextStyle(fontSize: 10)), icon: Icon(Icons.person_outline, size: 14)),
                  ButtonSegment(value: true, label: Text('جملة', style: TextStyle(fontSize: 10)), icon: Icon(Icons.groups_outlined, size: 14)),
                ],
                selected: {isWholesale.value},
                onSelectionChanged: (val) => isWholesale.value = val.first,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: EdgeInsets.zero,
              itemCount: results.value.length + (isLoading.value ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == results.value.length) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                    final product = results.value[index];
                    final currentPrice = isWholesale.value ? (product.wholesalePrice ?? product.price) : product.price;
                    
                    final currentStaff = ref.watch(currentStaffProvider);
                    final isAdmin = currentStaff?.roleName.toLowerCase() == 'admin' || currentStaff?.roleName.toLowerCase() == 'manager';

                    final profit = isAdmin && product.purchasePrice != null 
                        ? currentPrice - product.purchasePrice! 
                        : null;
                    final marginPct = profit != null && currentPrice > 0 
                        ? (profit / currentPrice) * 100 
                        : null;

                    return Card(
                      margin: EdgeInsets.only(bottom: isMobile ? 8 : 2),
                      child: ListTile(
                        dense: !isMobile,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: isMobile ? 4 : 0),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.blueGrey[50],
                          child: product.imageUrl != null 
                            ? SmartImage(
                                imageUrl: product.imageUrl!,
                                placeholder: const Icon(Icons.broken_image_outlined, size: 14),
                                cacheWidth: 100, // Small thumbnail
                              ) 
                            : const Icon(Icons.inventory_2_outlined, size: 14),
                        ),
                        title: Text(product.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 12)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ref.watch(categoriesListProvider).when(
                              data: (categories) {
                                final cat = categories.where((c) => c.id == product.category || c.name == product.category).firstOrNull;
                                return Text('القسم: ${cat?.name ?? product.category}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey, fontWeight: FontWeight.bold));
                              },
                              loading: () => Text('القسم: ${product.category}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                              error: (_, __) => Text('القسم: ${product.category}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
                            ),
                            Text('السعر: $currentPrice | المتوفر: ${product.stockQuantity}', style: TextStyle(fontSize: isMobile ? 12 : 10)),
                            if (profit != null && marginPct != null) 
                              Text(
                                'الربح: ${profit.toStringAsFixed(0)} IQD (${marginPct.toStringAsFixed(1)}%)', 
                                style: TextStyle(
                                  color: marginPct > 15 ? Colors.green[700] : (marginPct > 5 ? Colors.orange[700] : Colors.red[700]), 
                                  fontSize: 9, 
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                        trailing: const Icon(Icons.add_shopping_cart, color: Colors.green, size: 18),
                        onTap: () async {
                          final selectedWarehouse = ref.read(selectedWarehouseProvider);
                          if (product.variants.isNotEmpty) {
                            final variant = await showDialog<sm.ProductVariant>(
                              context: context,
                              builder: (ctx) => VariantPickerDialog(product: product, selectedWarehouse: selectedWarehouse),
                            );
                            if (variant == null) return;
                            
                            final loc = variant.storageLocations.where((l) => l.warehouseName == selectedWarehouse).firstOrNull ?? 
                                        (variant.storageLocations.isNotEmpty ? variant.storageLocations.first : null);

                            ref.read(salesSessionProvider.notifier).addItemToActive(sm.SalesItem(
                              productId: product.id,
                              productName: product.name,
                              quantity: 1,
                              unitPrice: loc?.priceOverride ?? variant.price ?? currentPrice,
                              category: product.category,
                              variantColor: variant.color,
                              variantSize: variant.size,
                              warehouseName: loc?.warehouseName ?? selectedWarehouse,
                              shelf: loc?.shelf,
                              box: loc?.box,
                            ));
                          } else {
                            ref.read(salesSessionProvider.notifier).addItemToActive(sm.SalesItem(
                              productId: product.id,
                              productName: product.name,
                              quantity: 1,
                              unitPrice: currentPrice,
                              category: product.category,
                              warehouseName: selectedWarehouse,
                            ));
                          }
                        },
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  void _showScannerDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح الباركود'),
        content: SizedBox(
          width: 350,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BarcodeScannerWidget(
                  onDetect: (barcode) async {
                    final tenantId = ref.read(tenantIdProvider);
                    final product = await ref.read(productRepositoryProvider).getProductByBarcode(tenantId, barcode);
                    
                    if (product != null) {
                      if (context.mounted) {
                        Navigator.pop(context);
                        if (product.variants.isNotEmpty) {
                           final variant = await showDialog<sm.ProductVariant>(
                              context: context,
                              builder: (ctx) => VariantPickerDialog(product: product),
                            );
                            if (variant == null) return;
                            ref.read(salesSessionProvider.notifier).addItemToActive(sm.SalesItem(
                              productId: product.id,
                              productName: product.name,
                              quantity: 1,
                              unitPrice: variant.price ?? product.price,
                              category: product.category,
                              variantColor: variant.color,
                              variantSize: variant.size,
                            ));
                        } else {
                          ref.read(salesSessionProvider.notifier).addItemToActive(sm.SalesItem(
                            productId: product.id,
                            productName: product.name,
                            quantity: 1,
                            unitPrice: product.price,
                            category: product.category,
                          ));
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تمت إضافة: ${product.name}'), duration: const Duration(seconds: 1)),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء المربع'))],
      ),
    );
  }
}

class _POSCartPanel extends ConsumerWidget {
  final sm.SalesInvoiceModel activeInvoice;
  final SalesSessionManager manager;
  final bool isMobile;
  final String? shiftId;

  const _POSCartPanel({required this.activeInvoice, required this.manager, required this.isMobile, this.shiftId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.blueGrey[50],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('السلة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${activeInvoice.items.length} أصناف', style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: activeInvoice.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = activeInvoice.items[index];
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(
                  '${item.productName}${item.variantColor != null || item.variantSize != null ? " (${item.variantColor ?? ''}${item.variantColor != null && item.variantSize != null ? ' - ' : ''}${item.variantSize ?? ''})" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  'السعر: ${item.unitPrice}${item.warehouseName != null ? " | المخزن: ${item.warehouseName}" : ""}${item.shelf != null ? " | رف: ${item.shelf}" : ""}${item.box != null ? " | صندوق: ${item.box}" : ""}', 
                  style: const TextStyle(fontSize: 11)
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.orange, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                         if (item.quantity > 1) {
                            manager.addItemToActive(sm.SalesItem(
                              productId: item.productId,
                              productName: item.productName,
                              quantity: -1,
                              unitPrice: item.unitPrice,
                              variantColor: item.variantColor,
                              variantSize: item.variantSize,
                            ));
                         }
                      },
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _showQuantityDialog(context, manager, index, item),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('${item.quantity}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: Colors.green, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        manager.addItemToActive(sm.SalesItem(
                          productId: item.productId,
                          productName: item.productName,
                          quantity: 1,
                          unitPrice: item.unitPrice,
                          variantColor: item.variantColor,
                          variantSize: item.variantSize,
                        ));
                      },
                    ),
                    const SizedBox(width: 8),
                    Text('${item.totalPrice}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                      onPressed: () async {
                         final tenantId = ref.read(tenantIdProvider);
                         final staff = ref.read(currentStaffProvider);
                         if (staff != null) {
                           await ref.read(auditRepositoryProvider).log(
                             tenantId: tenantId,
                             staffId: staff.id,
                             staffName: staff.name ?? staff.roleName,
                             action: 'delete_item',
                             description: 'حذف صنف من السلة: ${item.productName}',
                             metadata: {'productId': item.productId, 'quantity': item.quantity},
                           );
                         }
                         manager.removeItemFromActive(index);
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.local_offer_outlined, 
                        color: item.discount > 0 ? Colors.red : Colors.grey, 
                        size: 18),
                      tooltip: 'خصم للمنتج',
                      onPressed: () => _showItemDiscountDialog(context, ref, manager, index, item),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _CartFooter(activeInvoice: activeInvoice, isMobile: isMobile, shiftId: shiftId),
      ],
    );
  }

  void _showItemDiscountDialog(BuildContext context, WidgetRef ref, SalesSessionManager manager, int index, sm.SalesItem item) {
    final controller = TextEditingController(text: item.discount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('خصم لمنتج: ${item.productName}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'قيمة الخصم (المبلغ)', 
            border: OutlineInputBorder(),
            suffixText: 'IQD',
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final discount = double.tryParse(controller.text) ?? 0.0;
              if (discount > 0) {
                 final tenantId = ref.read(tenantIdProvider);
                 final staff = ref.read(currentStaffProvider);
                 if (staff != null) {
                   await ref.read(auditRepositoryProvider).log(
                     tenantId: tenantId,
                     staffId: staff.id,
                     staffName: staff.name ?? staff.roleName,
                     action: 'apply_item_discount',
                     description: 'خصم على صنف (${item.productName}): $discount IQD',
                     metadata: {'productId': item.productId, 'amount': discount},
                   );
                 }
              }
              manager.updateItemDiscount(index, discount);
              Navigator.pop(ctx);
            },
            child: const Text('تطبيق الخصم'),
          ),
        ],
      ),
    );
  }

  void _showQuantityDialog(BuildContext context, SalesSessionManager manager, int index, sm.SalesItem item) {
    final controller = TextEditingController(text: item.quantity.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تعديل كمية: ${item.productName}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'الكمية الجديدة', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final newQty = int.tryParse(controller.text) ?? item.quantity;
              final diff = newQty - item.quantity;
              if (diff != 0) {
                manager.addItemToActive(sm.SalesItem(
                  productId: item.productId,
                  productName: item.productName,
                  quantity: diff,
                  unitPrice: item.unitPrice,
                  variantColor: item.variantColor,
                  variantSize: item.variantSize,
                ));
              }
              Navigator.pop(ctx);
            },
            child: const Text('تعديل'),
          ),
        ],
      ),
    );
  }
}

class _MobileCartBar extends StatelessWidget {
  final sm.SalesInvoiceModel activeInvoice;
  final SalesSessionManager manager;
  final String? shiftId;

  const _MobileCartBar({required this.activeInvoice, required this.manager, this.shiftId});

  @override
  Widget build(BuildContext context) {
    final total = activeInvoice.items.fold(0.0, (sum, i) => sum + i.totalPrice);
    
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => Consumer(
            builder: (context, ref, _) {
              final sessionState = ref.watch(salesSessionProvider);
              final currentInvoice = sessionState.activeInvoice;
              return Container(
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    Expanded(
                      child: _POSCartPanel(activeInvoice: currentInvoice, manager: manager, isMobile: true, shiftId: shiftId),
                    ),
                  ],
                ),
              );
            }
          ),
        );
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.blue.shade800,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Badge(
              label: Text('${activeInvoice.items.length}'),
              child: const Icon(Icons.shopping_cart, color: Colors.white),
            ),
            const SizedBox(width: 16),
            const Text('عرض السلة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Text(
              '${total.toStringAsFixed(0)} IQD',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }
}

class _CartFooter extends HookConsumerWidget {
  final sm.SalesInvoiceModel activeInvoice;
  final bool isMobile;
  final String? shiftId;
  const _CartFooter({required this.activeInvoice, required this.isMobile, this.shiftId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = useState(false);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _showDiscountDialog(context, ref),
                icon: const Icon(Icons.label_outline, size: 16),
                label: Text(activeInvoice.discountAmount > 0 
                  ? 'خصم: ${activeInvoice.discountAmount}' 
                  : 'إضافة خصم'),
              ),
              const Spacer(),
              if (activeInvoice.customerId != null)
                TextButton.icon(
                  onPressed: () => _showLoyaltyDialog(context, ref, activeInvoice.customerId!),
                  icon: const Icon(Icons.star_outline, size: 16),
                  label: Text(activeInvoice.pointsRedeemed > 0 
                    ? 'نقاط: ${activeInvoice.pointsRedeemed}' 
                    : 'استخدام النقاط'),
                ),
            ],
          ),
          const Divider(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجمالي الفاتورة', style: TextStyle(fontSize: 14)),
              Text('${activeInvoice.items.fold(0.0, (sum, i) => sum + i.totalPrice)} IQD', style: const TextStyle(fontSize: 14, decoration: TextDecoration.lineThrough, color: Colors.grey)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('المجموع النهائي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Consumer(
                builder: (context, ref, _) {
                  final tenantAsync = ref.watch(tenantProvider);
                  final ptsValue = tenantAsync.asData?.value?.pointsToCurrencyRatio ?? 100.0;
                  return Text(
                    '${activeInvoice.totalAmount - activeInvoice.discountAmount - (activeInvoice.pointsRedeemed * ptsValue)} IQD', 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)
                  );
                }
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: isMobile ? (MediaQuery.of(context).size.width - 40) : null,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(salesSessionProvider.notifier).closeSession(ref.read(salesSessionProvider).activeIndex);
                    if (isMobile && context.mounted) Navigator.pop(context);
                  },
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), foregroundColor: Colors.red),
                  child: const Text('مسح السلة', style: TextStyle(fontSize: 12)),
                ),
              ),
              SizedBox(
                width: isMobile ? (MediaQuery.of(context).size.width / 2 - 28) : null,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700, 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: isLoading.value ? null : () => _handleCheckout(context, ref, forcePrint: false, loading: isLoading, shiftId: shiftId),
                  icon: isLoading.value ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save, size: 14),
                  label: const Text('حفظ', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
              SizedBox(
                width: isMobile ? (MediaQuery.of(context).size.width / 2 - 28) : null,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: isLoading.value ? null : () => _handleCheckout(context, ref, forcePrint: true, loading: isLoading, shiftId: shiftId),
                  icon: isLoading.value ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.print, size: 14),
                  label: const Text('حفظ/طبع', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleCheckout(BuildContext context, WidgetRef ref, {required bool forcePrint, required ValueNotifier<bool> loading, String? shiftId}) async {
    if (activeInvoice.items.isEmpty || loading.value) return;

    try {
      loading.value = true;
      final currentStaff = ref.read(currentStaffProvider);
      final receiptNumber = activeInvoice.receiptNumber.isEmpty 
          ? DateTime.now().millisecondsSinceEpoch.toString() 
          : activeInvoice.receiptNumber;

      final tenantAsync = ref.read(tenantProvider);
      final tenant = tenantAsync.asData?.value;
      final ptsValue = tenant?.pointsToCurrencyRatio ?? 1.0;
      final netTotal = activeInvoice.totalAmount - activeInvoice.discountAmount - (activeInvoice.pointsRedeemed * ptsValue);

      final invoiceToSave = activeInvoice.copyWith(
        status: sm.SalesInvoiceStatus.finalized,
        receiptNumber: receiptNumber,
        addedBy: currentStaff?.name,
        addedById: currentStaff?.id,
        paidAmount: netTotal,
        shiftId: shiftId,
      );

      final tenantId = ref.read(tenantIdProvider);
      await ref.read(salesRepositoryProvider).saveInvoice(tenantId, invoiceToSave);
      
      // --- Log Sale in Audit (Non-blocking) ---
      if (currentStaff != null) {
        final warehouseSummary = activeInvoice.items.map((i) => "${i.productName} (${i.warehouseName ?? 'تلقائي'})").toSet().join(", ");
        ref.read(auditRepositoryProvider).log(
          tenantId: tenantId,
          staffId: currentStaff.id,
          staffName: currentStaff.name ?? currentStaff.roleName,
          action: 'SALE',
          description: 'إتمام عملية بيع برقم وصل: $receiptNumber. المخازن المستخدمة: $warehouseSummary',
          metadata: {
            'invoiceId': invoiceToSave.id,
            'receiptNumber': receiptNumber,
            'amount': netTotal,
            'warehouses': activeInvoice.items.map((i) => i.warehouseName).toSet().toList(),
          },
        ); // Not awaited to prevent blocking UI
      }
      
      // --- Update Customer Loyalty Points (Already handled in SalesRepository locally) ---
      // We keep this here ONLY for remote update if needed, but wrapped in try/catch to never block
      if (activeInvoice.customerId != null) {
        try {
          final appSettings = await ref.read(appSettingsRepositoryProvider).getSettings();
          if (appSettings.loyaltyEnabled) {
            final customers = await ref.read(customerRepositoryProvider).getAllCustomersFuture(tenantId);
            final customer = customers.where((c) => c.id == activeInvoice.customerId).firstOrNull;
            
            if (customer != null) {
               final earnedPoints = (netTotal / (appSettings.pointsPerCurrencyUnit > 0 ? appSettings.pointsPerCurrencyUnit : 1000)).floor();
               final newPoints = (customer.loyaltyPoints ?? 0) - activeInvoice.pointsRedeemed + earnedPoints;
               
               await ref.read(customerRepositoryProvider).updateCustomerPoints(tenantId, customer.id, newPoints);
            }
          }
        } catch (e) {
          debugPrint('Silent error updating loyalty: $e');
        }
      }
      try {
        final appSettings = await ref.read(appSettingsRepositoryProvider).getSettings();
        
        // 1. Open Cash Drawer if enabled
        if (appSettings.openCashDrawer) {
          try {
            await ref.read(printingServiceProvider).openCashDrawer();
          } catch(e) {
            debugPrint('Drawer error: $e');
          }
        }

        // 2. Print Receipt using PDF (Always used for robust Arabic support)
        if (forcePrint) {
           final printer = ref.read(printingServiceProvider);
           final shopInfo = ref.read(tenantProvider).asData?.value;
           final pSettings = await ref.read(printerSettingsRepositoryProvider).getSettings();
           if (shopInfo != null) {
              await printer.printSalesInvoice(
                invoice: invoiceToSave, 
                shopInfo: shopInfo, 
                useDirectPrint: pSettings.receiptPrinterId != null && pSettings.receiptPrinterId!.isNotEmpty
              );
           }
        }
      } catch (e) {
        debugPrint('Print Error: $e');
      }

      if (context.mounted) {
        // --- Immediate UI Update ---
        ref.invalidate(salesListProvider);
        ref.invalidate(financialReportProvider);
        ref.invalidate(customersListProvider);
        ref.invalidate(activeShiftFutureProvider);
        ref.invalidate(pagedInventoryProductsProvider);
        ref.invalidate(pagedGeneralProductsProvider);
        ref.invalidate(productsFutureProvider);
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حفظ الفاتورة بنجاح. رقم الوصل: ${invoiceToSave.receiptNumber}')));
        ref.read(salesSessionProvider.notifier).closeSession(ref.read(salesSessionProvider).activeIndex);
        if (isMobile) Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      loading.value = false;
    }
  }

  void _showDiscountDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة خصم'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'قيمة الخصم (مبلغ)'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final val = double.tryParse(controller.text) ?? 0.0;
              ref.read(salesSessionProvider.notifier).setDiscount(val);
              Navigator.pop(context);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }

    void _showLoyaltyDialog(BuildContext context, WidgetRef ref, String customerId) async {
    final tenantId = ref.read(tenantIdProvider);
    final customer = await ref.read(salesRepositoryProvider).getCustomerById(tenantId, customerId);
    if (customer == null) return;
    final tenantAsync = ref.read(tenantProvider);
    final tenant = tenantAsync.asData?.value;
    if (tenant == null) return;

    final pointsValue = tenant.pointsToCurrencyRatio;
    final maxPoints = customer.loyaltyPoints;

    final selectedPoints = ValueNotifier<int>(maxPoints > 0 ? 1 : 0);
    final controller = TextEditingController(text: selectedPoints.value.toString());

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (ctx) => ValueListenableBuilder<int>(
          valueListenable: selectedPoints,
          builder: (ctx, pts, _) {
            final discount = pts * pointsValue;
            return AlertDialog(
              title: const Text('خصم نقاط الولاء'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('النقاط المتوفرة:'),
                      Text('$maxPoints نقطة', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'عدد النقاط المراد خصمها',
                      hintText: '0',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.stars, color: Colors.orange),
                    ),
                    onChanged: (val) {
                       var p = int.tryParse(val) ?? 0;
                       if (p > maxPoints) p = maxPoints;
                       if (p < 0) p = 0;
                       selectedPoints.value = p;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text('كل نقطة تعادل: ${pointsValue.toStringAsFixed(0)} IQD', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('قيمة الخصم:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${discount.toStringAsFixed(0)} IQD', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                FilledButton(
                  onPressed: pts > 0 ? () {
                    ref.read(salesSessionProvider.notifier).setLoyaltyPoints(pts, discount.toDouble());
                    Navigator.pop(ctx);
                  } : null,
                  child: const Text('تأكيد الخصم'),
                ),
              ],
            );
          },
        ),
      );
    }
  }

void _showSuccessDialog(BuildContext context, WidgetRef ref, sm.SalesInvoiceModel invoice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Center(
          child: Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'تمت العملية بنجاح',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('رقم الوصل: ${invoice.receiptNumber}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _printInvoice(context, ref, invoice);
                  },
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('طباعة'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _printInvoice(BuildContext context, WidgetRef ref, sm.SalesInvoiceModel invoice) async {
    try {
      final printer = ref.read(printingServiceProvider);
      final shopInfo = ref.read(tenantProvider).asData?.value;
      if (shopInfo == null) throw 'بيانات المحل غير متوفرة';

      final pSettings = await ref.read(printerSettingsRepositoryProvider).getSettings();
      final hasPrinter = pSettings.receiptPrinterId?.isNotEmpty == true;

      double? customerBalance;
      if (invoice.customerId != null && invoice.customerId!.isNotEmpty) {
        final tenantId = ref.read(tenantIdProvider);
        final customer = await ref.read(salesRepositoryProvider).getCustomerById(tenantId, invoice.customerId!);
        customerBalance = customer?.balance;
      }

      await printer.printSalesInvoice(
        invoice: invoice, 
        shopInfo: shopInfo,
        useDirectPrint: hasPrinter,
        customerBalance: customerBalance,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في الطباعة: $e')));
      }
    }
  }
}

class CustomerPickerDialog extends HookConsumerWidget {
  const CustomerPickerDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchController = useTextEditingController();
    final searchQuery = useState('');
    
    useEffect(() {
      void listener() => searchQuery.value = searchController.text;
      searchController.addListener(listener);
      return () => searchController.removeListener(listener);
    }, [searchController]);

    final customersAsync = ref.watch(customersListProvider);

    return AlertDialog(
      title: const Text('اختر الزبون'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: 'بحث عن زبون...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: customersAsync.when(
                data: (list) {
                  final filtered = list.where((c) => 
                    c.name.toLowerCase().contains(searchQuery.value.toLowerCase()) || 
                    c.phoneNumber.contains(searchQuery.value)
                  ).toList();
                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final customer = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: customer.id.startsWith('user_') ? Colors.orange.shade100 : Colors.blue.shade100,
                          child: Icon(
                            customer.id.startsWith('user_') ? Icons.app_registration : Icons.person,
                            color: customer.id.startsWith('user_') ? Colors.orange : Colors.blue,
                          ),
                        ),
                        title: Text(customer.name),
                        subtitle: Text('${customer.phoneNumber}\nالنقاط: ${customer.loyaltyPoints ?? 0}'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.blue),
                          onPressed: () => _showEditPointsDialog(context, ref, customer),
                          tooltip: 'تعديل النقاط',
                        ),
                        onTap: () => Navigator.pop(context, customer),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, __) => Center(child: Text('خطأ: $e')),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        TextButton(
          onPressed: () => _showAddCustomerDialog(context, ref),
          child: const Text('إضافة زبون جديد'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, sm.CustomerModel(
            id: '', 
            tenantId: '', 
            name: 'زبون نقدي',
            phoneNumber: '',
            createdAt: DateTime.now(),
          )), 
          child: const Text('زبون نقدي (Cash)'),
        ),
      ],
    );
  }

  void _showEditPointsDialog(BuildContext context, WidgetRef ref, sm.CustomerModel customer) {
    final controller = TextEditingController(text: (customer.loyaltyPoints ?? 0).toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعديل نقاط: ${customer.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'عدد النقاط الجديد', border: OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final newPts = int.tryParse(controller.text) ?? 0;
              final tenantId = ref.read(tenantIdProvider);
              await ref.read(customerRepositoryProvider).updateCustomerPoints(tenantId, customer.id, newPts);
              ref.invalidate(customersListProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('تحديث النقاط'),
          ),
        ],
      ),
    );
  }

  void _showAddCustomerDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة زبون جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم')),
            TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف'), keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final tenantId = ref.read(tenantIdProvider);
              final newCustomer = sm.CustomerModel(
                id: '',
                tenantId: tenantId,
                name: nameController.text,
                phoneNumber: phoneController.text,
                createdAt: DateTime.now(),
              );
              await ref.read(customerRepositoryProvider).addCustomer(tenantId, newCustomer);
              ref.invalidate(customersListProvider);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

}
