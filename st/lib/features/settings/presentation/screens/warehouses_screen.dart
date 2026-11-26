import 'package:shared_models/shared_models.dart';
import 'package:shared_models/src/widgets/stock_record_screen.dart';
import 'package:store_admin/core/services/supabase_config.dart';
import 'package:shared_models/src/widgets/inventory_balance_list.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';

class WarehousesScreen extends HookConsumerWidget {
  final bool showRecords;
  const WarehousesScreen({super.key,this.showRecords=false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final tenantId = ref.watch(currentTenantIdProvider);
    final tenant = ref.watch(tenantProvider).value;
    final advanced = useState(showRecords);
    final controller = useTextEditingController();
    final newCountry = useState(tenant?.countryCode ?? 'iq');
    final newCurrency = useState(
      CurrencyDefaults.normalizeCurrency(
        tenant?.currencyUnit ?? CurrencyDefaults.forCountry(tenant?.countryCode),
      ),
    );
    final initializedFromTenant = useRef(false);

    useEffect(() {
      if (tenant != null && !initializedFromTenant.value) {
        initializedFromTenant.value = true;
        newCountry.value = CurrencyDefaults.countries.any((c) => c.code == tenant.countryCode)
            ? tenant.countryCode
            : 'iq';
        newCurrency.value = CurrencyDefaults.normalizeCurrency(tenant.currencyUnit);
      }
      return null;
    }, [tenant]);

    Future<void> openReceiveBatchDialog(
      ProductModel product,
      List<String> warehouseNames,
    ) async {
      final qtyCtrl = TextEditingController(text: '10');
      final shelfCtrl = TextEditingController();
      final boxCtrl = TextEditingController();
      final batchCtrl = TextEditingController();
      final whOptions = <String>{'المخزن الرئيسي', ...warehouseNames}.toList();
      String selectedWh = whOptions.first;
      int selectedVariantIdx = 0;
      DateTime receivedAt = DateTime.now();
      DateTime? expiryDate;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDlg) => AlertDialog(
            title: Text('استلام دفعة - ${product.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (product.variants.isNotEmpty)
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: selectedVariantIdx,
                      decoration: const InputDecoration(labelText: 'الصنف / الحجم'),
                      items: [
                        for (int i = 0; i < product.variants.length; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              '${product.variants[i].color == 'Default' ? 'الافتراضي' : product.variants[i].color} / ${product.variants[i].size == 'Default' ? 'الافتراضي' : product.variants[i].size}',
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) setDlg(() => selectedVariantIdx = v);
                      },
                    ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedWh,
                    decoration: const InputDecoration(labelText: 'المخزن المستلم'),
                    items: whOptions
                        .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDlg(() => selectedWh = v);
                    },
                  ),
                  TextField(
                    controller: qtyCtrl,
                    decoration: const InputDecoration(labelText: 'الكمية المستلمة'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: batchCtrl,
                    decoration: const InputDecoration(labelText: 'رقم التشغيلة (اختياري)'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: shelfCtrl,
                          decoration: const InputDecoration(labelText: 'الرف (اختياري)'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: boxCtrl,
                          decoration: const InputDecoration(labelText: 'الصندوق (اختياري)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: receivedAt,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDlg(() => receivedAt = picked);
                    },
                    icon: const Icon(Icons.event_available, size: 18),
                    label: Text(
                      'تاريخ الاستلام: ${receivedAt.year}-${receivedAt.month.toString().padLeft(2, '0')}-${receivedAt.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 180)),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setDlg(() => expiryDate = picked);
                    },
                    icon: const Icon(Icons.event_busy, size: 18),
                    label: Text(
                      expiryDate == null
                          ? 'تاريخ انتهاء الصلاحية (اختياري)'
                          : 'الانتهاء: ${expiryDate!.year}-${expiryDate!.month.toString().padLeft(2, '0')}-${expiryDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('اعتماد الاستلام')),
            ],
          ),
        ),
      );

      final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
      final batchNum = batchCtrl.text.trim().isEmpty ? null : batchCtrl.text.trim();
      final shelf = shelfCtrl.text.trim().isEmpty ? null : shelfCtrl.text.trim();
      final box = boxCtrl.text.trim().isEmpty ? null : boxCtrl.text.trim();
      qtyCtrl.dispose();
      shelfCtrl.dispose();
      boxCtrl.dispose();
      batchCtrl.dispose();

      if (confirmed != true || qty <= 0) return;

      final newLoc = ProductStorageLocation(
        warehouseName: selectedWh,
        shelf: shelf,
        box: box,
        quantity: qty,
        batchNumber: batchNum,
        receivedAt: receivedAt,
        expiryDate: expiryDate,
      );

      final updatedVariants = List<ProductVariant>.from(product.variants);
      if (updatedVariants.isEmpty) {
        final locs = <ProductStorageLocation>[
          if (product.stockQuantity > 0)
            ProductStorageLocation(warehouseName: 'المخزن الرئيسي', quantity: product.stockQuantity),
          newLoc,
        ];
        updatedVariants.add(
          ProductVariant(
            color: 'Default',
            size: 'Default',
            stock: locs.fold<int>(0, (s, l) => s + l.quantity),
            storageLocations: locs,
          ),
        );
      } else {
        final v = updatedVariants[selectedVariantIdx];
        final locs = v.storageLocations.isEmpty && v.stock > 0
            ? [ProductStorageLocation(warehouseName: 'المخزن الرئيسي', quantity: v.stock)]
            : List<ProductStorageLocation>.from(v.storageLocations);
        final sameIdx = locs.indexWhere((l) => l.sameLot(newLoc));
        if (sameIdx >= 0) {
          locs[sameIdx] = locs[sameIdx].copyWith(quantity: locs[sameIdx].quantity + qty);
        } else {
          locs.add(newLoc);
        }
        updatedVariants[selectedVariantIdx] = v.copyWith(
          stock: locs.fold<int>(0, (s, l) => s + l.quantity),
          storageLocations: locs,
        );
      }

      final totalStock = updatedVariants.fold<int>(0, (s, v) => s + v.stock);
      final draft = product.copyWith(
        variants: updatedVariants,
        stockQuantity: totalStock,
        inStock: totalStock > 0,
      );
      final updatedProduct = draft.copyWith(
        expiryDate: BatchInventoryHelper.earliestValidExpiry(draft) ?? draft.expiryDate,
      );

      await ref.read(adminSupabaseServiceProvider).saveProduct(
        updatedProduct,
        tenantId,
        previousStock: product.stockQuantity,
      );
      await ref.read(localCacheServiceProvider).saveProducts([updatedProduct]);
      ref.invalidate(adminProductsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم استلام $qty قطعة في $selectedWh')),
        );
      }
    }

    Future<void> handleWarehouseCurrencyChange(
      Map<String, dynamic> warehouseDoc,
      String currentCurr,
      String nextCurr,
    ) async {
      final warehouseName = warehouseDoc['name'] as String? ?? '';
      if (nextCurr == currentCurr) return;

      final products = ref.read(adminProductsProvider).value ?? [];
      final affected = products.where((p) {
        return p.variants.any(
          (v) => v.storageLocations.any((l) => l.warehouseName == warehouseName && l.quantity > 0),
        );
      }).toList();

      if (affected.isEmpty) {
        await ref.read(adminFirestoreServiceProvider).updateWarehouse(
          tenantId,
          warehouseDoc['id'],
          {'currency': nextCurr},
        );
        return;
      }

      final rateCtrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('تأكيد تغيير عملة المخزن'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'يحتوي مخزن "$warehouseName" على ${affected.length} منتجاً. تغيير العملة من ($currentCurr) إلى ($nextCurr) سيُطبّق على هذا المخزن.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'معامل التحويل للأسعار (اختياري)',
                  hintText: 'مثال: 0.00076 لتحويل الدينار إلى دولار، أو اتركه فارغاً',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تأكيد الاعتماد')),
          ],
        ),
      );
      final rate = double.tryParse(rateCtrl.text.trim());
      rateCtrl.dispose();
      if (ok != true) return;

      if (rate != null && rate > 0) {
        for (final p in affected) {
          final updatedVariants = p.variants.map((v) {
            final updatedLocs = v.storageLocations.map((l) {
              if (l.warehouseName != warehouseName) return l;
              final basePrice = l.priceOverride ?? v.price ?? p.price;
              return l.copyWith(priceOverride: double.parse((basePrice * rate).toStringAsFixed(2)));
            }).toList();
            return v.copyWith(storageLocations: updatedLocs);
          }).toList();
          final updatedP = p.copyWith(variants: updatedVariants);
          await ref.read(adminSupabaseServiceProvider).saveProduct(updatedP, tenantId);
        }
        ref.invalidate(adminProductsProvider);
      }

      await ref.read(adminFirestoreServiceProvider).updateWarehouse(
        tenantId,
        warehouseDoc['id'],
        {'currency': nextCurr},
      );
    }

    return Scaffold(
      appBar: AppBar(
        actions: [
          TextButton(
            onPressed: () => advanced.value = !advanced.value,
            child: Text(advanced.value ? 'العودة إلى المبسّط' : 'المخزون المتقدّم'),
          ),
        ],
        title: Text(lang == 'ar' ? 'إدارة المخازن والفروع' : 'Warehouses & Branches'),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: ref.read(adminFirestoreServiceProvider).getWarehouses(tenantId),
        builder: (context, snapshot) {
          final data = snapshot.data ?? [];
          final whNames = data
              .map((w) => w['name'] as String? ?? '')
              .where((w) => w.isNotEmpty)
              .toList();

          if (advanced.value) {
            return ref.watch(adminProductsProvider).when(
              data: (products) => InventoryBalanceList(
                products: products,
                showCost: true,
                onReceiveBatch: (p) => openReceiveBatchDialog(p, whNames),
                onOpenRecord: (p) => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StockRecordScreen(
                      product: p,
                      url: SupabaseConfig.url,
                      publishableKey: SupabaseConfig.anonKey,
                      allowCount: true,
                    ),
                  ),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: controller,
                            decoration: InputDecoration(
                              hintText: lang == 'ar' ? 'اسم المخزن أو الفرع الجديد' : 'New Branch / Warehouse Name',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: newCountry.value,
                            decoration: InputDecoration(
                              labelText: lang == 'ar' ? 'الدولة' : 'Country',
                              border: const OutlineInputBorder(),
                            ),
                            items: CurrencyDefaults.countries
                                .map((c) => DropdownMenuItem(value: c.code, child: Text(c.nameAr, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                newCountry.value = val;
                                newCurrency.value = CurrencyDefaults.forCountry(val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: CurrencyDefaults.currencies.any((c) => c.code == newCurrency.value)
                                ? newCurrency.value
                                : 'د.ع',
                            decoration: InputDecoration(
                              labelText: lang == 'ar' ? 'عملة المخزن' : 'Currency',
                              border: const OutlineInputBorder(),
                            ),
                            items: CurrencyDefaults.currencies
                                .map((c) => DropdownMenuItem(value: c.code, child: Text(c.label, style: const TextStyle(fontSize: 12))))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) newCurrency.value = val;
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                          onPressed: () async {
                            final multiAllowed = tenant?.isPosMultiBranchAllowed ?? false;
                            if (!multiAllowed && data.isNotEmpty) {
                              showTierLockedMessage(
                                context,
                                tenant: tenant,
                                featureName: 'تعدد الفروع والمخازن',
                                minimumTier: 'D',
                              );
                              return;
                            }
                            if (controller.text.trim().isNotEmpty) {
                              await ref.read(adminFirestoreServiceProvider).addWarehouse(
                                tenantId,
                                controller.text.trim(),
                                currency: newCurrency.value,
                                countryCode: newCountry.value,
                              );
                              controller.clear();
                            }
                          },
                          icon: Icon(
                            ((tenant?.isPosMultiBranchAllowed ?? false) || data.isEmpty)
                                ? Icons.add
                                : Icons.lock_outline,
                          ),
                          label: Text(lang == 'ar' ? 'إضافة' : 'Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final rawCurr = item['currency'] as String? ?? 'د.ع';
                    final currentItemCurrency = CurrencyDefaults.normalizeCurrency(rawCurr);
                    final itemCountry = CurrencyDefaults.countryNameAr(item['countryCode'] as String?);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade50,
                          child: const Icon(Icons.storefront, color: Colors.blue),
                        ),
                        title: Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الدولة: $itemCountry', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            Row(
                              children: [
                                Text(lang == 'ar' ? 'العملة المعتمدة: ' : 'Currency: ', style: const TextStyle(fontSize: 12)),
                                Flexible(
                                  child: DropdownButton<String>(
                                    value: CurrencyDefaults.currencies.any((c) => c.code == currentItemCurrency)
                                        ? currentItemCurrency
                                        : 'د.ع',
                                    isDense: true,
                                    underline: const SizedBox(),
                                    items: CurrencyDefaults.currencies
                                        .map((c) => DropdownMenuItem(value: c.code, child: Text(c.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))))
                                        .toList(),
                                    onChanged: (newVal) {
                                      if (newVal != null) {
                                        handleWarehouseCurrencyChange(item, currentItemCurrency, newVal);
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => ref.read(adminFirestoreServiceProvider).deleteWarehouse(tenantId, item['id']),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
