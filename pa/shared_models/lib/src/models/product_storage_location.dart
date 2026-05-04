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

  const ProductStorageLocation({
    required this.warehouseName,
    this.shelf,
    this.box,
    this.quantity = 0,
    this.priceOverride,
  });

  @override
  List<Object?> get props => [warehouseName, shelf, box, quantity, priceOverride];

  Map<String, dynamic> toJson() {
    return {
      'warehouseName': warehouseName,
      if (shelf != null) 'shelf': shelf,
      if (box != null) 'box': box,
      'quantity': quantity,
      if (priceOverride != null) 'priceOverride': priceOverride,
    };
  }

  factory ProductStorageLocation.fromJson(Map<String, dynamic> json) {
    return ProductStorageLocation(
      warehouseName: json['warehouseName'] as String? ?? 'Default Warehouse',
      shelf: json['shelf'] as String?,
      box: json['box'] as String?,
      quantity: (json['quantity'] as num? ?? 0).toInt(),
      priceOverride: (json['priceOverride'] as num?)?.toDouble(),
    );
  }

  ProductStorageLocation copyWith({
    String? warehouseName,
    String? shelf,
    String? box,
    int? quantity,
    double? priceOverride,
    bool clearPriceOverride = false,
  }) {
    return ProductStorageLocation(
      warehouseName: warehouseName ?? this.warehouseName,
      shelf: shelf ?? this.shelf,
      box: box ?? this.box,
      quantity: quantity ?? this.quantity,
      priceOverride: clearPriceOverride ? null : (priceOverride ?? this.priceOverride),
    );
  }
}
