import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'product_storage_location.g.dart';

@HiveType(typeId: 2)
class ProductStorageLocation extends Equatable {
  @HiveField(0)
  final String warehouseName;
  @HiveField(1)
  final String? shelf;
  @HiveField(2)
  final String? box;
  @HiveField(3)
  final int quantity;
  @HiveField(4)
  final double? priceOverride;
  @HiveField(5)
  final String? batchNumber;
  @HiveField(6)
  final DateTime? receivedAt;
  @HiveField(7)
  final DateTime? expiryDate;

  const ProductStorageLocation({
    required this.warehouseName,
    this.shelf,
    this.box,
    this.quantity = 0,
    this.priceOverride,
    this.batchNumber,
    this.receivedAt,
    this.expiryDate,
  });

  bool get isExpired {
    if (expiryDate == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    return exp.isBefore(today);
  }

  bool isExpiringSoon([int warnDays = 30]) {
    if (expiryDate == null || isExpired) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate!.year, expiryDate!.month, expiryDate!.day);
    return !exp.isAfter(today.add(Duration(days: warnDays)));
  }

  static bool _sameDate(DateTime? a, DateTime? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool sameLot(ProductStorageLocation other) =>
      warehouseName == other.warehouseName &&
      (shelf ?? '') == (other.shelf ?? '') &&
      (box ?? '') == (other.box ?? '') &&
      (batchNumber ?? '') == (other.batchNumber ?? '') &&
      _sameDate(expiryDate, other.expiryDate) &&
      _sameDate(receivedAt, other.receivedAt);

  @override
  List<Object?> get props => [
        warehouseName,
        shelf,
        box,
        quantity,
        priceOverride,
        batchNumber,
        receivedAt,
        expiryDate,
      ];

  Map<String, dynamic> toJson() {
    return {
      'warehouseName': warehouseName,
      if (shelf != null) 'shelf': shelf,
      if (box != null) 'box': box,
      'quantity': quantity,
      if (priceOverride != null) 'priceOverride': priceOverride,
      if (batchNumber != null && batchNumber!.isNotEmpty) 'batchNumber': batchNumber,
      if (receivedAt != null) 'receivedAt': receivedAt!.toIso8601String(),
      if (expiryDate != null) 'expiryDate': expiryDate!.toIso8601String(),
    };
  }

  factory ProductStorageLocation.fromJson(Map<String, dynamic> json) {
    return ProductStorageLocation(
      warehouseName: json['warehouseName'] as String? ?? 'Default Warehouse',
      shelf: json['shelf'] as String?,
      box: json['box'] as String?,
      quantity: (json['quantity'] as num? ?? 0).toInt(),
      priceOverride: (json['priceOverride'] as num?)?.toDouble(),
      batchNumber: json['batchNumber'] as String?,
      receivedAt: json['receivedAt'] != null ? DateTime.tryParse(json['receivedAt'].toString()) : null,
      expiryDate: json['expiryDate'] != null ? DateTime.tryParse(json['expiryDate'].toString()) : null,
    );
  }

  ProductStorageLocation copyWith({
    String? warehouseName,
    String? shelf,
    String? box,
    int? quantity,
    double? priceOverride,
    bool clearPriceOverride = false,
    String? batchNumber,
    bool clearBatchNumber = false,
    DateTime? receivedAt,
    bool clearReceivedAt = false,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
  }) {
    return ProductStorageLocation(
      warehouseName: warehouseName ?? this.warehouseName,
      shelf: shelf ?? this.shelf,
      box: box ?? this.box,
      quantity: quantity ?? this.quantity,
      priceOverride: clearPriceOverride ? null : (priceOverride ?? this.priceOverride),
      batchNumber: clearBatchNumber ? null : (batchNumber ?? this.batchNumber),
      receivedAt: clearReceivedAt ? null : (receivedAt ?? this.receivedAt),
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
    );
  }
}
