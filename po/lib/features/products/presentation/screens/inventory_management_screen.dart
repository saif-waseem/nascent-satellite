import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import 'package:intl/intl.dart';
import '../../data/product_repository.dart';
import '../../../../core/utils/printing_service.dart';
import '../providers/product_providers.dart';
import '../providers/inventory_analysis_provider.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../common/data/notification_repository.dart';
import '../../../reports/data/audit_repository.dart';
import '../../../../core/providers/permissions_provider.dart';
import 'product_form_screen.dart';
import '../providers/category_provider.dart';

enum InventoryFilter { all, lowStock, nearExpiry, slowMoving, overstocked }

class InventoryManagementScreen extends HookConsumerWidget {
  final InventoryFilter initialFilter;
  const InventoryManagementScreen({super.key, this.initialFilter = InventoryFilter.all});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pagedState = ref.watch(pagedInventoryProductsProvider);
    final products = pagedState.products;
    final analysisAsync = ref.watch(inventoryAnalysisProvider);
    final tenantId = ref.watch(tenantIdProvider);
    final searchQuery = useTextEditingController();
    final search = useValueListenable(searchQuery);
    final activeFilter = useState<InventoryFilter>(initialFilter);
    final scrollController = useScrollController();

    useEffect(() {
      void listener() {
        if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
          ref.read(pagedInventoryProductsProvider.notifier).loadMore();
        }
      }
      scrollController.addListener(listener);
      return () => scrollController.removeListener(listener);
    }, [scrollController]);

    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));

    // Apply text search & filters in-memory on the loaded chunk
    var filtered = products.where((p) {
      final query = search.text.toLowerCase();
      final nameMatch = p.name.toLowerCase().contains(query);
      final barcodeMatch = p.barcode != null && p.barcode!.toLowerCase().contains(query);
      final categoryMatch = p.category != null && p.category!.toLowerCase().contains(query);
      return nameMatch || barcodeMatch || categoryMatch;
    }).toList();

    if (activeFilter.value == InventoryFilter.lowStock) {
      filtered = filtered.where((p) {
        final threshold = p.minStockLevel ?? 5;
        return p.stockQuantity <= threshold;
      }).toList();
    } else if (activeFilter.value == InventoryFilter.nearExpiry) {
      filtered = filtered.where((p) {
        if (p.expiryDate == null) return false;
        return p.expiryDate!.isBefore(thirtyDaysLater);
      }).toList();
    } else if (activeFilter.value == InventoryFilter.slowMoving) {
      final insights = analysisAsync.value ?? [];
      final slowIds = insights.where((i) => i.isSlowMoving).map((i) => i.product.id).toSet();
      filtered = filtered.where((p) => slowIds.contains(p.id)).toList();
    } else if (activeFilter.value == InventoryFilter.overstocked) {
      final insights = analysisAsync.value ?? [];
      final overIds = insights.where((i) => i.isOverstocked).map((i) => i.product.id).toSet();
      filtered = filtered.where((p) => overIds.contains(p.id)).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المخزون (Inventory)'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: searchQuery,
                  decoration: InputDecoration(
                    hintText: 'بحث باسم المنتج أو الباركود...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                    isDense: true,
                    suffixIcon: search.text.isNotEmpty
                      ? IconButton(onPressed: () => searchQuery.clear(), icon: const Icon(Icons.clear))
                      : null,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final filter in [
                        (InventoryFilter.all, 'الكل', Icons.list),
                        (InventoryFilter.lowStock, 'نواقص', Icons.warning_amber),
                        (InventoryFilter.nearExpiry, 'صلاحية', Icons.event_busy),
                        (InventoryFilter.slowMoving, 'راكد', Icons.trending_down),
                        (InventoryFilter.overstocked, 'مشبع', Icons.warehouse),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: ChoiceChip(
                            label: Text(filter.$2),
                            avatar: Icon(filter.$3, size: 16, color: activeFilter.value == filter.$1 ? Colors.white : Colors.blueGrey),
                            selected: activeFilter.value == filter.$1,
                            onSelected: (selected) {
                              if (selected) activeFilter.value = filter.$1;
                            },
                            selectedColor: Colors.blue.shade700,
                            labelStyle: TextStyle(
                              color: activeFilter.value == filter.$1 ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          final horizontalPadding = isMobile ? 0.0 : (constraints.maxWidth - 900).clamp(16.0, 500.0);

          return products.isEmpty && pagedState.isLoadingMore 
            ? const Center(child: CircularProgressIndicator())
            : filtered.isEmpty && !pagedState.isLoadingMore
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        activeFilter.value == InventoryFilter.lowStock
                          ? 'لا توجد منتجات بمخزون منخفض 🎉'
                            : activeFilter.value == InventoryFilter.nearExpiry
                              ? 'لا توجد منتجات قرب انتهاء الصلاحية 🎉'
                              : activeFilter.value == InventoryFilter.slowMoving
                                ? 'لا توجد بضائع راكدة، المستودع نشط! 🚀'
                                : 'المستودع متوازن، لا توجد بضاعة مكدسة ⚖️',
                        style: const TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length + (pagedState.hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                if (index == filtered.length) {
                  return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
                }
                final product = filtered[index];
                final insight = analysisAsync.value?.firstWhere((i) => i.product.id == product.id, 
                    orElse: () => InventoryInsight(product: product, soldInPeriod: 0, velocityRate: 0));
                return _InventoryItemTile(product: product, tenantId: tenantId, insight: insight);
              },
            ),
          );
        },
      ),
      floatingActionButton: ref.hasPermission(PosPermission.manageProducts)
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              ),
              label: const Text('إضافة منتج جديد'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _InventoryItemTile extends ConsumerWidget {
  final ProductModel product;
  final String tenantId;
  final InventoryInsight? insight;
  const _InventoryItemTile({required this.product, required this.tenantId, this.insight});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stock = product.stockQuantity;
    final threshold = product.minStockLevel ?? 5;
    final isLow = stock > 0 && stock <= threshold;
    final isOut = stock <= 0;

    final now = DateTime.now();
    final isExpired = product.expiryDate != null && product.expiryDate!.isBefore(now);
    final isNearExpiry = product.expiryDate != null && !isExpired &&
        product.expiryDate!.isBefore(now.add(const Duration(days: 30)));

    Color statusColor = Colors.green;
    String statusText = 'متوفر';
    if (isLow) {
      statusColor = Colors.orange;
      statusText = 'كمية منخفضة';
    } else if (isOut) {
      statusColor = Colors.red;
      statusText = 'نفذ المخزون';
    }

    final isSmall = MediaQuery.of(context).size.width < 700;

    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            stock.toString(),
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: statusColor),
          ),
        ),
      ),
      title: Text(product.name, 
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(statusText, 
            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: isLow ? FontWeight.bold : FontWeight.normal),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (isLow)
            Text('نقص في المخزون! (الحد: ${product.minStockLevel ?? 5})', 
              style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            'شراء: ${product.purchasePrice ?? 0} | بيع: ${product.price}',
            style: const TextStyle(color: Colors.blueGrey, fontSize: 10, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          ref.watch(categoriesListProvider).when(
            data: (categories) {
              final cat = categories.where((c) => c.id == product.category || c.name == product.category).firstOrNull;
              return Text('القسم: ${cat?.name ?? product.category}', 
                style: const TextStyle(fontSize: 10, color: Colors.blueGrey));
            },
            loading: () => Text('القسم: ${product.category}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
            error: (_, __) => Text('القسم: ${product.category}', style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
          ),
          if (product.variants.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 4,
                runSpacing: 2,
                children: product.variants.map((v) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.blue.shade100)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${v.color}/${v.size}: ${v.stock}', style: TextStyle(fontSize: 9, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                      ...v.storageLocations.where((l) => l.quantity > 0).map((l) => Text(
                        ' • ${l.warehouseName}${l.shelf != null ? ' (رف: ${l.shelf})' : ''}: ${l.quantity}',
                        style: const TextStyle(fontSize: 8, color: Colors.blueGrey),
                      )),
                    ],
                  ),
                )).toList(),
              ),
            ),
          if (isExpired)
            Text(
              'منتهي! (${DateFormat('dd/MM/yyyy').format(product.expiryDate!)})',
              style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
            )
          else if (isNearExpiry)
            Text(
              'قرب الانتهاء: ${DateFormat('dd/MM/yyyy').format(product.expiryDate!)}',
              style: const TextStyle(color: Colors.orange, fontSize: 10),
            )
          else if (product.expiryDate != null)
            Text(
              'الصلاحية: ${DateFormat('dd/MM/yyyy').format(product.expiryDate!)}',
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          
          if (insight != null && (insight!.soldInPeriod > 0 || insight!.isSlowMoving)) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.speed, size: 10, color: insight!.velocityRate > 0 ? Colors.blue : Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'بيع منه ${insight!.soldInPeriod} خلال الفترة الماضية',
                    style: TextStyle(fontSize: 10, color: insight!.velocityRate > 0 ? Colors.blue : Colors.grey, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (insight!.isSlowMoving)
              const Text('⚠️ بضاعة راكدة', style: TextStyle(color: Colors.deepOrange, fontSize: 10, fontWeight: FontWeight.bold)),
            if (insight!.suggestedOrder > 0)
              Text('🛒 المقترح طلبه: ${insight!.suggestedOrder}', style: const TextStyle(color: Colors.teal, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
          ],
      ),
      isThreeLine: product.expiryDate != null,
      trailing: isSmall 
        ? PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 1) _showAdjustStockDialog(context, ref, 1);
              else if (value == -1) _showAdjustStockDialog(context, ref, -1);
              else if (value == 0) _showAdjustStockDialog(context, ref, 0);
              else if (value == 2) {
                 final tenant = ref.read(tenantProvider).value;
                 if (tenant != null && product.barcode != null && product.barcode!.isNotEmpty) {
                    ref.read(printingServiceProvider).printBarcodeLabel(
                      name: product.name,
                      barcode: product.barcode!,
                      price: product.price,
                      currency: tenant.currencyUnit,
                    );
                 }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 1, child: ListTile(leading: Icon(Icons.add_box_outlined, color: Colors.blue), title: Text('إضافة مخزون'))),
              const PopupMenuItem(value: -1, child: ListTile(leading: Icon(Icons.remove_circle_outline, color: Colors.red), title: Text('خصم مخزون'))),
              const PopupMenuItem(value: 0, child: ListTile(leading: Icon(Icons.edit_note, color: Colors.grey), title: Text('تعديل/ضبط'))),
              const PopupMenuItem(value: 2, child: ListTile(leading: Icon(Icons.print, color: Colors.blueGrey), title: Text('طباعة باركود'))),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isNearExpiry || isExpired)
                const Icon(Icons.event_busy, color: Colors.orange, size: 18),
              // Quick Adjustment Buttons
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16, color: Colors.red),
                      onPressed: () => _quickAdjust(ref, -1),
                      constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                    Text('${product.stockQuantity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add, size: 16, color: Colors.green),
                      onPressed: () => _quickAdjust(ref, 1),
                      constraints: const BoxConstraints(maxWidth: 32, maxHeight: 32),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.print, color: Colors.blueGrey, size: 20),
                onPressed: () {
                  final tenant = ref.read(tenantProvider).value;
                  if (tenant == null) return;
                  if (product.barcode == null || product.barcode!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('المنتج لا يحتوي على باركود')));
                    return;
                  }
                  ref.read(printingServiceProvider).printBarcodeLabel(
                    name: product.name,
                    barcode: product.barcode!,
                    price: product.price,
                    currency: tenant.currencyUnit,
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.grey, size: 20),
                onPressed: () => _showAdjustStockDialog(context, ref, 0),
              ),
            ],
          ),
    );
  }

  void _quickAdjust(WidgetRef ref, int amount) async {
    try {
      final repo = ref.read(productRepositoryProvider);
      final color = product.variants.isNotEmpty ? product.variants.first.color : null;
      final size = product.variants.isNotEmpty ? product.variants.first.size : null;
      
      await repo.updateStock(tenantId, product.id, amount, color: color, size: size);
      
      // Update local state instead of invalidating everything
      final box = repo.box; // I'll add a getter for the box in the repository
      final updated = box.get(product.id);
      if (updated != null) {
        ref.read(pagedInventoryProductsProvider.notifier).updateProductInState(updated);
        ref.read(pagedGeneralProductsProvider.notifier).updateProductInState(updated);
      }
      
      ref.invalidate(productsFutureProvider);
    } catch (e) {
      debugPrint('Quick adjust error: $e');
    }
  }

  void _showAdjustStockDialog(BuildContext context, WidgetRef ref, int initialDirection) {
    showDialog(
      context: context,
      builder: (context) => _AdjustStockDialog(
        product: product,
        tenantId: tenantId,
        initialAdjustment: initialDirection,
      ),
    );
  }
}

class _AdjustStockDialog extends HookConsumerWidget {
  final ProductModel product;
  final String tenantId;
  final int initialAdjustment;

  const _AdjustStockDialog({
    required this.product,
    required this.tenantId,
    required this.initialAdjustment,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = useTextEditingController(
      text: initialAdjustment == 0 ? '' : initialAdjustment.abs().toString()
    );
    final isLoading = useState(false);
    // mode: 0 = Add, 1 = Remove, 2 = Set
    final mode = useState(initialAdjustment > 0 ? 0 : (initialAdjustment < 0 ? 1 : 2));
    final selectedVariant = useState<ProductVariant?>(product.variants.isNotEmpty ? product.variants.first : null);
    final selectedLocation = useState<ProductStorageLocation?>(
      (selectedVariant.value != null && selectedVariant.value!.storageLocations.isNotEmpty) 
        ? selectedVariant.value!.storageLocations.first 
        : null
    );
    final priceOverrideController = useTextEditingController(
      text: selectedLocation.value?.priceOverride?.toString() ?? ''
    );
    final expiryDate = useState<DateTime?>(product.expiryDate);
    final minStockController = useTextEditingController(text: (product.minStockLevel ?? 5).toString());

    return AlertDialog(
      title: Text('تعديل مخزون: ${product.name}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (product.variants.isNotEmpty) ...[
              const Text('اختر المتغير (اللون/المقاس):', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              DropdownButtonFormField<ProductVariant>(
                value: selectedVariant.value,
                items: product.variants.map((v) => DropdownMenuItem(
                  value: v,
                  child: Text('${v.color} - ${v.size} (الإجمالي: ${v.stock})', style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (val) {
                   selectedVariant.value = val;
                },
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 16),
            ],
            if (selectedVariant.value != null && selectedVariant.value!.storageLocations.isNotEmpty) ...[
               const Text('اختر المخزن/الموقع:', style: TextStyle(fontSize: 12, color: Colors.grey)),
               const SizedBox(height: 8),
               DropdownButtonFormField<ProductStorageLocation>(
                 value: selectedVariant.value!.storageLocations.contains(selectedLocation.value) ? selectedLocation.value : selectedVariant.value!.storageLocations.first,
                 items: selectedVariant.value!.storageLocations.map((l) => DropdownMenuItem(
                   value: l,
                   child: Text('${l.warehouseName} (الحالي: ${l.quantity})', style: const TextStyle(fontSize: 13)),
                 )).toList(),
                 onChanged: (val) => selectedLocation.value = val,
                 decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
               ),
               const SizedBox(height: 16),
            ],
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('إضافة'), icon: Icon(Icons.add)),
                ButtonSegment(value: 1, label: Text('خصم'), icon: Icon(Icons.remove)),
                ButtonSegment(value: 2, label: Text('ضبط'), icon: Icon(Icons.pin)),
              ],
              selected: {mode.value},
              onSelectionChanged: (val) => mode.value = val.first,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: mode.value == 2 ? 'الكمية الجديدة' : 'الكمية',
                border: const OutlineInputBorder(),
                hintText: 'أدخل رقماً',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceOverrideController,
              decoration: const InputDecoration(
                labelText: 'سعر خاص لهذا المخزن (اختياري)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.sell_outlined),
                hintText: 'مثال: 50.0',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: minStockController,
              decoration: const InputDecoration(
                labelText: 'حد التنبيه (أدنى مخزون)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.warning_amber_outlined),
                hintText: 'مثال: 5',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            const SizedBox(height: 16),
            const Text('تاريخ انتهاء الصلاحية:', style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: expiryDate.value != null && expiryDate.value!.isBefore(DateTime.now().add(const Duration(days: 30)))
                    ? Colors.orange : Colors.grey.shade400),
              ),
              icon: Icon(
                Icons.calendar_month,
                color: expiryDate.value != null && expiryDate.value!.isBefore(DateTime.now())
                    ? Colors.red
                    : expiryDate.value != null && expiryDate.value!.isBefore(DateTime.now().add(const Duration(days: 30)))
                        ? Colors.orange
                        : Colors.teal,
              ),
              label: Text(
                expiryDate.value != null
                    ? DateFormat('dd/MM/yyyy').format(expiryDate.value!)
                    : 'لا يوجد تاريخ صلاحية',
                style: const TextStyle(fontSize: 13),
              ),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: expiryDate.value ?? DateTime.now().add(const Duration(days: 30)),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) expiryDate.value = picked;
              },
            ),
            if (expiryDate.value != null)
              TextButton(
                onPressed: () => expiryDate.value = null,
                child: const Text('إزالة تاريخ الصلاحية', style: TextStyle(color: Colors.red, fontSize: 12)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        FilledButton(
          onPressed: isLoading.value ? null : () async {
            final valStr = controller.text;
            final val = int.tryParse(valStr) ?? 0;
            isLoading.value = true;
            try {
              final repo = ref.read(productRepositoryProvider);
              final newMinStock = int.tryParse(minStockController.text);

              if (valStr.isNotEmpty || mode.value == 2) {
                final priceOverride = double.tryParse(priceOverrideController.text);
                if (mode.value == 0) {
                  await repo.updateStock(tenantId, product.id, val,
                      color: selectedVariant.value?.color, 
                      size: selectedVariant.value?.size,
                      warehouseName: selectedLocation.value?.warehouseName,
                      priceOverride: priceOverride);
                } else if (mode.value == 1) {
                  await repo.updateStock(tenantId, product.id, -val,
                      color: selectedVariant.value?.color, 
                      size: selectedVariant.value?.size,
                      warehouseName: selectedLocation.value?.warehouseName,
                      priceOverride: priceOverride);
                } else {
                  final currentStock = (selectedLocation.value?.quantity ?? (selectedVariant.value?.stock ?? (product.stockQuantity as num?)?.toInt())) ?? 0;
                  final adjustment = val - currentStock;
                  if (adjustment != 0 || priceOverride != null) {
                    await repo.updateStock(tenantId, product.id, adjustment,
                        color: selectedVariant.value?.color, 
                        size: selectedVariant.value?.size,
                        warehouseName: selectedLocation.value?.warehouseName,
                        priceOverride: priceOverride);
                  }
                }
              }

              // Update expiry and minStockLevel
              final extra = <String, dynamic>{};
              if (expiryDate.value != null) {
                extra['expiryDate'] = expiryDate.value!.toIso8601String();
              } else {
                extra['expiryDate'] = null;
              }
              if (newMinStock != null) extra['minStockLevel'] = newMinStock;
              if (extra.isNotEmpty) {
                await repo.updateProductFields(tenantId, product.id, extra);
              }

              // Log the action
              final staff = ref.read(currentStaffProvider);
              final actionStr = mode.value == 0 ? 'إضافة مخزون' : (mode.value == 1 ? 'خصم مخزون' : 'ضبط مخزون');
              ref.read(auditRepositoryProvider).log(
                tenantId: tenantId,
                staffId: staff?.id ?? 'system',
                staffName: staff?.name ?? 'System',
                action: 'inventory_adjustment',
                description: '$actionStr للمنتج: ${product.name} بمقدار $val',
                metadata: {
                  'productId': product.id,
                  'variant': selectedVariant.value != null ? '${selectedVariant.value!.color}/${selectedVariant.value!.size}' : 'none',
                  'adjustment': val,
                  'mode': mode.value,
                },
              );

              ref.invalidate(pagedInventoryProductsProvider);
              ref.invalidate(pagedGeneralProductsProvider);
              ref.invalidate(productsFutureProvider);

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث المخزون بنجاح')));
                Navigator.pop(context);
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ في التحديث: $e'), backgroundColor: Colors.red));
              }
            } finally {
              isLoading.value = false;
            }
          },
          child: isLoading.value
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('تحديث'),
        ),
      ],
    );
  }
}
