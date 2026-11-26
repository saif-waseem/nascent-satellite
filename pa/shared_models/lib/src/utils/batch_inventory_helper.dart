import '../models/product_model.dart';
import '../models/product_storage_location.dart';

class BatchAlert {
  final String warehouseName;
  final String? batchNumber;
  final int quantity;
  final DateTime expiryDate;
  final DateTime? receivedAt;
  final bool isExpired;

  const BatchAlert({
    required this.warehouseName,
    this.batchNumber,
    required this.quantity,
    required this.expiryDate,
    this.receivedAt,
    required this.isExpired,
  });

  String formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String get message {
    final lot = (batchNumber != null && batchNumber!.isNotEmpty) ? ' [$batchNumber]' : '';
    if (isExpired) {
      return 'منتهية الصلاحية ($quantity قطعة في $warehouseName$lot انتهت في ${formatDate(expiryDate)})';
    }
    return 'بقيت $quantity قطعة من الدفعة ($warehouseName$lot) تنتهي في ${formatDate(expiryDate)}';
  }
}

/// Pure helpers for batch receipt, FEFO sorting/deduction, and expiry validation.
class BatchInventoryHelper {
  static DateTime _dayStart(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static bool isLocationExpired(ProductStorageLocation loc, [DateTime? now]) {
    final exp = loc.expiryDate;
    if (exp == null) return false;
    return _dayStart(exp).isBefore(_dayStart(now ?? DateTime.now()));
  }

  static bool isLocationExpiringSoon(
    ProductStorageLocation loc, {
    int warnDays = 30,
    DateTime? now,
  }) {
    final exp = loc.expiryDate;
    if (exp == null) return false;
    final current = _dayStart(now ?? DateTime.now());
    final expDay = _dayStart(exp);
    if (expDay.isBefore(current)) return false;
    return !expDay.isAfter(current.add(Duration(days: warnDays)));
  }

  static bool isDateExpired(DateTime? exp, [DateTime? now]) {
    if (exp == null) return false;
    return _dayStart(exp).isBefore(_dayStart(now ?? DateTime.now()));
  }

  /// Sorts storage batches chronologically by earliest expiryDate first (FEFO),
  /// then earliest receivedAt, putting undated rows last.
  static List<ProductStorageLocation> sortFefo(List<ProductStorageLocation> locations) {
    final sorted = List<ProductStorageLocation>.from(locations);
    sorted.sort((a, b) {
      if (a.expiryDate != null && b.expiryDate != null) {
        final cmp = a.expiryDate!.compareTo(b.expiryDate!);
        if (cmp != 0) return cmp;
      } else if (a.expiryDate != null) {
        return -1;
      } else if (b.expiryDate != null) {
        return 1;
      }
      if (a.receivedAt != null && b.receivedAt != null) {
        return a.receivedAt!.compareTo(b.receivedAt!);
      } else if (a.receivedAt != null) {
        return -1;
      } else if (b.receivedAt != null) {
        return 1;
      }
      return 0;
    });
    return sorted;
  }

  static Iterable<ProductStorageLocation> _matchingLocations(
    ProductModel product, {
    String? warehouseName,
    String? color,
    String? size,
  }) sync* {
    for (final v in product.variants) {
      if (color != null && v.color != color) continue;
      if (size != null && v.size != size) continue;
      for (final loc in v.storageLocations) {
        if (warehouseName != null &&
            warehouseName.isNotEmpty &&
            loc.warehouseName != warehouseName) {
          continue;
        }
        yield loc;
      }
    }
  }

  /// Total quantity currently valid for sale (excludes expired batches).
  static int sellableStock(
    ProductModel product, {
    String? warehouseName,
    String? color,
    String? size,
    DateTime? now,
  }) {
    final hasAnyLocations = product.variants.any((v) => v.storageLocations.isNotEmpty);
    if (!hasAnyLocations) {
      if (isDateExpired(product.expiryDate, now)) return 0;
      if (product.variants.isEmpty) return product.stockQuantity;
      return product.variants
          .where((v) => (color == null || v.color == color) && (size == null || v.size == size))
          .fold<int>(0, (sum, v) => sum + v.stock);
    }

    int sum = 0;
    for (final loc in _matchingLocations(
      product,
      warehouseName: warehouseName,
      color: color,
      size: size,
    )) {
      if (!isLocationExpired(loc, now)) {
        sum += loc.quantity;
      }
    }
    return sum;
  }

  /// Finds the next batch (with quantity > 0 and not expired) in FEFO order.
  static ProductStorageLocation? nextSellableBatch(
    ProductModel product, {
    String? warehouseName,
    String? color,
    String? size,
    DateTime? now,
  }) {
    final candidates = _matchingLocations(
      product,
      warehouseName: warehouseName,
      color: color,
      size: size,
    ).where((loc) => loc.quantity > 0 && !isLocationExpired(loc, now)).toList();

    if (candidates.isEmpty) return null;
    return sortFefo(candidates).first;
  }

  /// Deducts [qtyToDeduct] across non-expired batches in FEFO order.
  /// Leaves expired batches untouched so expired stock is never sold.
  static List<ProductStorageLocation> deductFefo(
    List<ProductStorageLocation> locations,
    int qtyToDeduct, {
    String? warehouseName,
    double? priceOverride,
    DateTime? now,
  }) {
    if (qtyToDeduct <= 0) return List<ProductStorageLocation>.from(locations);

    final updated = List<ProductStorageLocation>.from(locations);
    final indexed = <({int index, ProductStorageLocation loc})>[];
    for (int i = 0; i < updated.length; i++) {
      final loc = updated[i];
      if (warehouseName != null &&
          warehouseName.isNotEmpty &&
          loc.warehouseName != warehouseName) {
        continue;
      }
      if (loc.quantity > 0 && !isLocationExpired(loc, now)) {
        indexed.add((index: i, loc: loc));
      }
    }

    indexed.sort((a, b) {
      final expA = a.loc.expiryDate;
      final expB = b.loc.expiryDate;
      if (expA != null && expB != null) {
        final cmp = expA.compareTo(expB);
        if (cmp != 0) return cmp;
      } else if (expA != null) {
        return -1;
      } else if (expB != null) {
        return 1;
      }
      final recA = a.loc.receivedAt;
      final recB = b.loc.receivedAt;
      if (recA != null && recB != null) return recA.compareTo(recB);
      return 0;
    });

    int remaining = qtyToDeduct;
    for (final entry in indexed) {
      if (remaining <= 0) break;
      final take = remaining < entry.loc.quantity ? remaining : entry.loc.quantity;
      updated[entry.index] = entry.loc.copyWith(
        quantity: entry.loc.quantity - take,
        priceOverride: priceOverride ?? entry.loc.priceOverride,
      );
      remaining -= take;
    }

    // If warehouse-filtered valid stock wasn't enough and warehouse wasn't strictly empty,
    // allow fallback across any valid location if no specific warehouse was forced.
    if (remaining > 0 && (warehouseName == null || warehouseName.isEmpty)) {
      // Nothing else available; clamp at 0
    }
    return updated;
  }

  /// Earliest non-expired expiryDate across all variants/batches, falling back to any batch expiryDate.
  static DateTime? earliestValidExpiry(ProductModel product, {DateTime? now}) {
    final validDates = <DateTime>[];
    final allDates = <DateTime>[];
    for (final v in product.variants) {
      for (final loc in v.storageLocations) {
        final exp = loc.expiryDate;
        if (exp == null || loc.quantity <= 0) continue;
        allDates.add(exp);
        if (!isLocationExpired(loc, now)) {
          validDates.add(exp);
        }
      }
    }
    if (validDates.isNotEmpty) {
      validDates.sort();
      return validDates.first;
    }
    if (allDates.isNotEmpty) {
      allDates.sort();
      return allDates.first;
    }
    return product.expiryDate;
  }

  /// Returns alerts for every batch with quantity > 0 that is expired or expiring within [warnDays].
  static List<BatchAlert> inspectBatches(
    ProductModel product, {
    int warnDays = 30,
    DateTime? now,
  }) {
    final alerts = <BatchAlert>[];
    for (final v in product.variants) {
      for (final loc in v.storageLocations) {
        if (loc.quantity <= 0 || loc.expiryDate == null) continue;
        final expired = isLocationExpired(loc, now);
        final soon = isLocationExpiringSoon(loc, warnDays: warnDays, now: now);
        if (expired || soon) {
          alerts.add(
            BatchAlert(
              warehouseName: loc.warehouseName,
              batchNumber: loc.batchNumber,
              quantity: loc.quantity,
              expiryDate: loc.expiryDate!,
              receivedAt: loc.receivedAt,
              isExpired: expired,
            ),
          );
        }
      }
    }
    if (alerts.isEmpty && product.expiryDate != null && product.stockQuantity > 0) {
      final expired = isDateExpired(product.expiryDate, now);
      final current = _dayStart(now ?? DateTime.now());
      final expDay = _dayStart(product.expiryDate!);
      if (expired || !expDay.isAfter(current.add(Duration(days: warnDays)))) {
        alerts.add(
          BatchAlert(
            warehouseName: 'المخزن الرئيسي',
            quantity: product.stockQuantity,
            expiryDate: product.expiryDate!,
            isExpired: expired,
          ),
        );
      }
    }
    alerts.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return alerts;
  }
}
