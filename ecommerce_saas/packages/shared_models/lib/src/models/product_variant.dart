import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'product_variant.g.dart';

@HiveType(typeId: 1)
class ProductVariant extends Equatable {
  @HiveField(0)
  final String color;
  @HiveField(1)
  final String size;
  @HiveField(2)
  final int stock;
  @HiveField(3)
  final double? price; // null = use base product price

  const ProductVariant({
    required this.color,
    required this.size,
    required this.stock,
    this.price,
  });

  @override
  List<Object?> get props => [color, size, stock, price];

  Map<String, dynamic> toJson() {
    return {
      'color': color,
      'size': size,
      'stock': stock,
      if (price != null) 'price': price,
    };
  }

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      color: json['color'] as String? ?? 'Default',
      size: json['size'] as String? ?? 'Default',
      stock: json['stock'] as int? ?? 0,
      price: (json['price'] as num?)?.toDouble(),
    );
  }

  ProductVariant copyWith({
    String? color,
    String? size,
    int? stock,
    double? price,
    bool clearPrice = false,
  }) {
    return ProductVariant(
      color: color ?? this.color,
      size: size ?? this.size,
      stock: stock ?? this.stock,
      price: clearPrice ? null : (price ?? this.price),
    );
  }
}
