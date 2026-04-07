import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:shared_models/shared_models.dart';
import 'package:intl/intl.dart';
import '../../data/product_repository.dart';
import '../../../../core/utils/printing_service.dart';
import '../providers/product_providers.dart';
import '../../../../core/providers/tenant_provider.dart';

enum InventoryFilter { all, lowStock, nearExpiry }

class InventoryManagementScreen extends HookConsumerWidget {
  final InventoryFilter initialFilter;
  const InventoryManagementScreen({super.key, this.initialFilter = InventoryFilter.all});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsStreamProvider);
    final tenantId = ref.watch(tenantIdProvider);
    final searchQuery = useTextEditingController();
    final search = useValueListenable(searchQuery);
    final activeFilter = useState<InventoryFilter>(initialFilter);

    final now = DateTime.now();
    final thirtyDaysLater = now.add(const Duration(days: 30));

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
                child: SegmentedButton<InventoryFilter>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: InventoryFilter.all, label: Text('الكل'), icon: Icon(Icons.list, size: 14)),
                    ButtonSegment(value: InventoryFilter.lowStock, label: Text('مخزون منخفض'), icon: Icon(Icons.warning_amber, size: 14)),
                    ButtonSegment(value: InventoryFilter.nearExpiry, label: Text('قرب انتهاء'), icon: Icon(Icons.event_busy, size: 14)),
                  ],
                  selected: {activeFilter.value},
                  onSelectionChanged: (s) => activeFilter.value = s.first,
                ),
              ),
            ],
          ),
        ),
      ),
      body: productsAsync.when(
        data: (products) {
          // Apply text search
          var filtered = products.where((p) {
            final query = search.text.toLowerCase();
            return p.name.toLowerCase().contains(query) ||
                   (p.barcode != null && p.barcode!.contains(query));
          }).toList();

          // Apply filter chip
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
          }

          if (filtered.isEmpty) {
            return Center(
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
                        : 'لا توجد منتجات مطابقة',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final product = filtered[index];
              return _InventoryItemTile(product: product, tenantId: tenantId);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _InventoryItemTile extends ConsumerWidget {
  final ProductModel product;
  final String tenantId;
  const _InventoryItemTile({required this.product, required this.tenantId});

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

    final isSmall = MediaQuery.of(context).size.width < 500;

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
      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(statusText, style: TextStyle(color: statusColor, fontSize: 11)),
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
              IconButton(
                icon: const Icon(Icons.add_box_outlined, color: Colors.blue),
                onPressed: () => _showAdjustStockDialog(context, ref, 1),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                onPressed: () => _showAdjustStockDialog(context, ref, -1),
              ),
              IconButton(
                icon: const Icon(Icons.print, color: Colors.blueGrey),
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
                icon: const Icon(Icons.edit_note, color: Colors.grey),
                onPressed: () => _showAdjustStockDialog(context, ref, 0),
              ),
            ],
          ),
    );
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
                  child: Text('${v.color} - ${v.size} (الحالي: ${v.stock})', style: const TextStyle(fontSize: 13)),
                )).toList(),
                onChanged: (val) => selectedVariant.value = val,
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
                if (mode.value == 0) {
                  await repo.updateStock(tenantId, product.id, val,
                      color: selectedVariant.value?.color, size: selectedVariant.value?.size);
                } else if (mode.value == 1) {
                  await repo.updateStock(tenantId, product.id, -val,
                      color: selectedVariant.value?.color, size: selectedVariant.value?.size);
                } else {
                  final currentStock = (selectedVariant.value?.stock ?? (product.stockQuantity as num?)?.toInt()) ?? 0;
                  final adjustment = val - currentStock;
                  if (adjustment != 0) {
                    await repo.updateStock(tenantId, product.id, adjustment,
                        color: selectedVariant.value?.color, size: selectedVariant.value?.size);
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
