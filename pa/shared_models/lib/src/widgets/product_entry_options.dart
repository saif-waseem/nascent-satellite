import 'package:flutter/material.dart';
import '../models/product_variant.dart';
import '../models/product_storage_location.dart';

class ProductEntryMode extends StatelessWidget {
  final bool advanced;
  final ValueChanged<bool> onChanged;
  const ProductEntryMode({
    super.key,
    required this.advanced,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 4,
    children: [
      for (final entry in {false: 'إدخال بسيط', true: 'إدخال متقدّم'}.entries)
        ChoiceChip(
          label: Text(entry.value),
          selected: advanced == entry.key,
          onSelected: (_) => onChanged(entry.key),
        ),
    ],
  );
}

class ProductOptionValues extends StatefulWidget {
  final String label;
  final List<String> values;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final ValueChanged<List<String>> onChange;
  const ProductOptionValues({
    super.key,
    required this.label,
    required this.values,
    required this.enabled,
    required this.onToggle,
    required this.onChange,
  });
  @override
  State<ProductOptionValues> createState() => _ProductOptionValuesState();
}

class _ProductOptionValuesState extends State<ProductOptionValues> {
  final input = TextEditingController();
  void add() {
    final value = input.text.trim();
    if (value.isEmpty || value == 'Default' || value == 'none') return;
    if (!widget.values.contains(value))
      widget.onChange([...widget.values, value]);
    input.clear();
  }

  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(widget.label),
        value: widget.enabled,
        onChanged: widget.onToggle,
      ),
      if (widget.enabled) ...[
        TextField(
          controller: input,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => add(),
          decoration: InputDecoration(
            labelText: 'إضافة قيمة',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'إضافة',
              icon: const Icon(Icons.add),
              onPressed: add,
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final v in widget.values)
              InputChip(
                label: Text(v),
                onDeleted: () => widget.onChange(
                  widget.values.where((x) => x != v).toList(),
                ),
              ),
          ],
        ),
      ],
    ],
  );
}

List<String> entryValues(Iterable<String> values) => values
    .where((v) => v.isNotEmpty && v != 'Default' && v != 'none')
    .toSet()
    .toList();

int entryStock(ProductVariant v) => v.storageLocations.isEmpty
    ? v.stock
    : v.storageLocations.fold(0, (sum, loc) => sum + loc.quantity);

class EntryInventoryTable extends StatelessWidget {
  final List<ProductVariant> variants;
  final ValueChanged<int> onEdit, onPrice, onRemove;
  const EntryInventoryTable({
    super.key,
    required this.variants,
    required this.onEdit,
    required this.onPrice,
    required this.onRemove,
  });
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columnSpacing: 18,
      headingRowColor: WidgetStatePropertyAll(
        Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      columns: [
        for (final title in [
          'الصنف',
          'الحجم',
          'سعر البيع',
          'المخزن',
          'الرف',
          'الصندوق',
          'الرصيد',
          'إجراءات',
        ])
          DataColumn(label: Text(title)),
      ],
      rows: [
        for (final (index, v) in variants.indexed)
          for (final loc
              in v.storageLocations.isEmpty ? [null] : v.storageLocations)
            DataRow(
              cells: [
                DataCell(Text(v.color == 'Default' ? '—' : v.color)),
                DataCell(Text(v.size == 'Default' ? '—' : v.size)),
                DataCell(
                  Text(v.price?.toString() ?? 'سعر المنتج'),
                  onTap: () => onPrice(index),
                ),
                DataCell(
                  Text(loc?.warehouseName ?? '—'),
                  onTap: () => onEdit(index),
                ),
                DataCell(Text(loc?.shelf ?? '—')),
                DataCell(Text(loc?.box ?? '—')),
                DataCell(
                  Text('${loc?.quantity ?? v.stock}'),
                  onTap: () => onEdit(index),
                ),
                DataCell(
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'تعديل مواقع التخزين',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => onEdit(index),
                      ),
                      IconButton(
                        tooltip: 'حذف التنويعة',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => onRemove(index),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      ],
    ),
  );
}

Future<void> editVariantPrice(
  BuildContext context,
  ValueNotifier<List<ProductVariant>> variants,
  int index,
) async {
  var value = variants.value[index].price?.toString() ?? '';
  final applied = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('سعر التنويعة'),
      content: TextFormField(
        initialValue: value,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'اتركه فارغًا لاستخدام سعر المنتج',
        ),
        onChanged: (v) => value = v.trim(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            if (value.isEmpty || (double.tryParse(value) ?? -1) >= 0)
              Navigator.pop(ctx, true);
          },
          child: const Text('حفظ'),
        ),
      ],
    ),
  );
  if (applied == true)
    variants.value = List.of(variants.value)
      ..[index] = variants.value[index].copyWith(
        price: double.tryParse(value),
        clearPrice: value.isEmpty,
      );
}

// Project disabled options onto the remaining dimensions without discarding stock.
List<ProductVariant> entryVariants(
  List<ProductVariant> source,
  bool colors,
  bool sizes,
) {
  final groups = <(String, String), ProductVariant>{};
  for (final original in source) {
    final key = (
      colors ? original.color : 'Default',
      sizes ? original.size : 'Default',
    );
    final v = original.copyWith(
      color: key.$1,
      size: key.$2,
      stock: entryStock(original),
    );
    final previous = groups[key];
    if (previous == null) {
      groups[key] = v;
      continue;
    }
    if (previous.price != v.price)
      throw const FormatException(
        'وحّد أسعار التنويعات قبل إغلاق الخيار الذي يميّزها.',
      );
    final locations = <ProductStorageLocation>[];
    for (final part in [previous, v]) {
      final rows = part.storageLocations.isEmpty
          ? [
              ProductStorageLocation(
                warehouseName: 'المخزن الرئيسي',
                quantity: part.stock,
              ),
            ]
          : part.storageLocations;
      for (final row in rows) {
        final i = locations.indexWhere(
          (r) =>
              r.warehouseName == row.warehouseName &&
              r.shelf == row.shelf &&
              r.box == row.box &&
              r.priceOverride == row.priceOverride,
        );
        if (i < 0) {
          locations.add(row);
        } else {
          locations[i] = locations[i].copyWith(
            quantity: locations[i].quantity + row.quantity,
          );
        }
      }
    }
    groups[key] = v.copyWith(
      stock: previous.stock + v.stock,
      storageLocations: locations,
    );
  }
  return groups.values.toList();
}

Future<void> editEntryLocations(
  BuildContext context,
  ValueNotifier<List<ProductVariant>> variants,
  int index,
) async {
  final variant = variants.value[index];
  final rows = [...variant.storageLocations];
  if (rows.isEmpty && variant.stock > 0)
    rows.add(
      ProductStorageLocation(
        warehouseName: 'المخزن الرئيسي',
        quantity: variant.stock,
      ),
    );
  final keys = [for (final _ in rows) UniqueKey()];
  final form = GlobalKey<FormState>();
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, update) => AlertDialog(
        title: const Text('توزيع المخزون'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 12,
                      columns: [
                        for (final title in [
                          'المخزن',
                          'الرف',
                          'الصندوق',
                          'الكمية',
                          'السعر الخاص',
                          '',
                        ])
                          DataColumn(label: Text(title)),
                      ],
                      rows: [
                        for (final (i, row) in rows.indexed)
                          DataRow(
                            key: keys[i],
                            cells: [
                              DataCell(
                                SizedBox(
                                  width: 125,
                                  child: TextFormField(
                                    initialValue: row.warehouseName,
                                    validator: (v) => (v ?? '').trim().isEmpty
                                        ? 'مطلوب'
                                        : null,
                                    onChanged: (v) => rows[i] = rows[i]
                                        .copyWith(warehouseName: v.trim()),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 72,
                                  child: TextFormField(
                                    initialValue: row.shelf,
                                    onChanged: (v) =>
                                        rows[i] = rows[i].copyWith(shelf: v),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 72,
                                  child: TextFormField(
                                    initialValue: row.box,
                                    onChanged: (v) =>
                                        rows[i] = rows[i].copyWith(box: v),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 72,
                                  child: TextFormField(
                                    initialValue: '${row.quantity}',
                                    keyboardType: TextInputType.number,
                                    validator: (v) =>
                                        (int.tryParse(v ?? '') ?? -1) < 0
                                        ? 'كمية غير صالحة'
                                        : null,
                                    onChanged: (v) =>
                                        rows[i] = rows[i].copyWith(
                                          quantity: int.tryParse(v) ?? 0,
                                        ),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 90,
                                  child: TextFormField(
                                    initialValue: row.priceOverride?.toString(),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    validator: (v) =>
                                        (v ?? '').isNotEmpty &&
                                            (double.tryParse(v!) ?? -1) < 0
                                        ? 'سعر غير صالح'
                                        : null,
                                    onChanged: (v) =>
                                        rows[i] = rows[i].copyWith(
                                          priceOverride: double.tryParse(v),
                                          clearPriceOverride: v.isEmpty,
                                        ),
                                  ),
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  tooltip: 'حذف الموقع',
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => update(() {
                                    rows.removeAt(i);
                                    keys.removeAt(i);
                                  }),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => update(() {
                      rows.add(
                        const ProductStorageLocation(
                          warehouseName: '',
                          quantity: 0,
                        ),
                      );
                      keys.add(UniqueKey());
                    }),
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة موقع'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('حفظ التوزيع'),
          ),
        ],
      ),
    ),
  );
  if (result == true)
    variants.value = List.of(variants.value)
      ..[index] = variant.copyWith(
        stock: rows.fold<int>(0, (n, r) => n + r.quantity),
        storageLocations: rows,
      );
}

void changeEntryOption(
  BuildContext context,
  bool isColor,
  List<String> next, {
  required ValueNotifier<List<String>> colors,
  required ValueNotifier<List<String>> sizes,
  required ValueNotifier<List<ProductVariant>> variants,
  required bool useColors,
  required bool useSizes,
  required int baseStock,
}) {
  final option = isColor ? colors : sizes;
  final removed = option.value.where((v) => !next.contains(v)).toSet();
  bool removedRow(ProductVariant v) =>
      removed.contains(isColor ? v.color : v.size);
  if (variants.value.any(
    (v) =>
        removedRow(v) &&
        (entryStock(v) != 0 ||
            v.price != null ||
            v.storageLocations.isNotEmpty),
  )) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'هذه القيمة مرتبطة بصف مخزون. راجع الصف في الإدخال المتقدّم قبل حذفه.',
        ),
      ),
    );
    return;
  }
  option.value = next;
  final rows = variants.value.where((v) => !removedRow(v)).toList();
  final colorValues = useColors && colors.value.isNotEmpty
      ? colors.value
      : ['Default'];
  final sizeValues = useSizes && sizes.value.isNotEmpty
      ? sizes.value
      : ['Default'];
  rows.removeWhere(
    (v) =>
        entryStock(v) == 0 &&
        v.storageLocations.isEmpty &&
        v.price == null &&
        ((!colorValues.contains('Default') && v.color == 'Default') ||
            (!sizeValues.contains('Default') && v.size == 'Default')),
  );
  if (colorValues.first != 'Default' || sizeValues.first != 'Default') {
    for (final c in colorValues) {
      for (final s in sizeValues) {
        if (!rows.any((v) => v.color == c && v.size == s))
          rows.add(ProductVariant(color: c, size: s, stock: 0));
      }
    }
  }
  variants.value = rows;
}

/// Adds a warehouse storage row (and variant if colors/sizes are enabled) cleanly,
/// merging into an existing variant/location when matching instead of blocking edits.
Future<void> showAddWarehouseRowDialog(
  BuildContext context, {
  required ValueNotifier<List<ProductVariant>> variants,
  required bool useColors,
  required bool useSizes,
  required ValueNotifier<List<String>> colors,
  required ValueNotifier<List<String>> sizes,
}) async {
  final colorController = TextEditingController();
  final sizeController = TextEditingController();
  final warehouseController = TextEditingController(text: 'المخزن الرئيسي');
  final shelfController = TextEditingController();
  final boxController = TextEditingController();
  final quantityController = TextEditingController(text: '0');

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('إضافة إلى المخزون'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (useColors)
              TextField(
                controller: colorController,
                decoration: const InputDecoration(labelText: 'الصنف / اللون'),
              ),
            if (useSizes)
              TextField(
                controller: sizeController,
                decoration: const InputDecoration(labelText: 'الحجم'),
              ),
            TextField(
              controller: warehouseController,
              decoration: const InputDecoration(labelText: 'المخزن'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: shelfController,
                    decoration: const InputDecoration(labelText: 'الرف (اختياري)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: boxController,
                    decoration: const InputDecoration(labelText: 'الصندوق (اختياري)'),
                  ),
                ),
              ],
            ),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(labelText: 'الكمية'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            final qty = int.tryParse(quantityController.text.trim());
            final rawColor = colorController.text.trim();
            final rawSize = sizeController.text.trim();
            final warehouse = warehouseController.text.trim().isEmpty
                ? 'المخزن الرئيسي'
                : warehouseController.text.trim();
            final shelf = shelfController.text.trim().isEmpty
                ? null
                : shelfController.text.trim();
            final box = boxController.text.trim().isEmpty
                ? null
                : boxController.text.trim();

            if (qty == null ||
                qty < 0 ||
                (useColors && rawColor.isEmpty) ||
                (useSizes && rawSize.isEmpty)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('يرجى إدخال كمية صحيحة وإكمال الحقول المطلوبة.'),
                ),
              );
              return;
            }

            final targetColor = useColors && rawColor.isNotEmpty ? rawColor : 'Default';
            final targetSize = useSizes && rawSize.isNotEmpty ? rawSize : 'Default';
            if (useColors && rawColor.isNotEmpty) {
              colors.value = entryValues([...colors.value, rawColor]);
            }
            if (useSizes && rawSize.isNotEmpty) {
              sizes.value = entryValues([...sizes.value, rawSize]);
            }

            final list = List<ProductVariant>.from(variants.value);
            final existingIdx = list.indexWhere(
              (v) => v.color == targetColor && v.size == targetSize,
            );

            final newLoc = ProductStorageLocation(
              warehouseName: warehouse,
              shelf: shelf,
              box: box,
              quantity: qty,
            );

            if (existingIdx >= 0) {
              final existing = list[existingIdx];
              final locs = existing.storageLocations.isEmpty && existing.stock > 0
                  ? [
                      ProductStorageLocation(
                        warehouseName: 'المخزن الرئيسي',
                        quantity: existing.stock,
                      ),
                    ]
                  : List<ProductStorageLocation>.from(existing.storageLocations);
              final sameLocIdx = locs.indexWhere(
                (l) =>
                    l.warehouseName == warehouse &&
                    l.shelf == shelf &&
                    l.box == box,
              );
              if (sameLocIdx >= 0) {
                locs[sameLocIdx] = locs[sameLocIdx].copyWith(
                  quantity: locs[sameLocIdx].quantity + qty,
                );
              } else {
                locs.add(newLoc);
              }
              final updatedStock = locs.fold<int>(0, (s, l) => s + l.quantity);
              list[existingIdx] = existing.copyWith(
                stock: updatedStock,
                storageLocations: locs,
              );
            } else {
              list.add(
                ProductVariant(
                  color: targetColor,
                  size: targetSize,
                  stock: qty,
                  storageLocations: [newLoc],
                ),
              );
            }

            variants.value = list;
            Navigator.pop(ctx);
          },
          child: const Text('إضافة'),
        ),
      ],
    ),
  );

  for (final c in [
    colorController,
    sizeController,
    warehouseController,
    shelfController,
    boxController,
    quantityController,
  ]) {
    c.dispose();
  }
}
