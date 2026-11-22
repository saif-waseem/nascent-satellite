import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'product_variant.dart';

part 'product_model.g.dart';

@HiveType(typeId: 0)
class ProductModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String name;
  @HiveField(3)
  final String category;
  @HiveField(4)
  final String description;
  @HiveField(5)
  final double price;
  @HiveField(6)
  final double rating;
  @HiveField(7)
  final bool isOffer;
  @HiveField(8)
  final List<String> images;
  @HiveField(9)
  final bool inStock;
  @HiveField(10)
  final List<String> sizes;
  @HiveField(11)
  final List<String> colors;
  @HiveField(12)
  final int stockQuantity;
  @HiveField(13)
  final int salesCount;
  @HiveField(14)
  final List<ProductVariant> variants;
  @HiveField(15)
  final String? videoUrl;
  @HiveField(17)
  final bool isFeaturedDeal; // عرض كبير - shows in featured carousel
  @HiveField(18)
  final double? oldPrice; // السعر القديم - shows strikethrough
  @HiveField(19)
  final int? discountPercentage; // نسبة الخصم - auto-calculated
  @HiveField(20)
  final bool isDailyStarred; // Marked for daily check-in
  @HiveField(21)
  final String? barcode;
  @HiveField(22)
  final String? lastSupplierId;
  @HiveField(23)
  final double? wholesalePrice;
  @HiveField(24)
  final double? purchasePrice;
  @HiveField(25)
  final DateTime? expiryDate;
  @HiveField(26)
  final int? minStockLevel;
  @HiveField(27)
  final String? unit;
  @HiveField(28)
  final bool isArchived;
  @HiveField(29)
  final double? secondaryPrice;
  @HiveField(30)
  final String? secondaryCurrency;

  const ProductModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.category,
    required this.description,
    required this.price,
    this.rating = 0.0,
    this.isOffer = false,
    this.images = const [],
    this.inStock = true,
    this.sizes = const [],
    this.videoUrl, 
    this.colors = const [],
    this.stockQuantity = 0,
    this.salesCount = 0,
    this.variants = const [],
    this.isFeaturedDeal = false,
    this.oldPrice,
    this.discountPercentage,
    this.isDailyStarred = false,
    this.barcode,
    this.lastSupplierId,
    this.wholesalePrice,
    this.purchasePrice,
    this.expiryDate,
    this.minStockLevel,
    this.unit,
    this.isArchived = false,
    this.secondaryPrice,
    this.secondaryCurrency,
  });

  String formatPrices([String primaryUnit = 'د.ع']) {
    final primary = '${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)} $primaryUnit';
    if (secondaryPrice != null && secondaryPrice! > 0) {
      final secUnit = secondaryCurrency ?? '\$';
      final sec = '${secondaryPrice!.toStringAsFixed(secondaryPrice!.truncateToDouble() == secondaryPrice ? 0 : 2)} $secUnit';
      return '$primary ($sec)';
    }
    return primary;
  }

  String? get imageUrl => images.isNotEmpty ? images.first : null;

  @override
  List<Object?> get props => [
        id,
        tenantId,
        name,
        category,
        description,
        price,
        rating,
        isOffer,
        images,
        inStock,
        sizes,
        videoUrl, // Added videoUrl to props
        colors,
        stockQuantity,
        salesCount,
        variants,
        isFeaturedDeal,
        oldPrice,
        discountPercentage,
        isDailyStarred,
        barcode,
        lastSupplierId,
        wholesalePrice,
        purchasePrice,
        expiryDate,
        minStockLevel,
        unit,
        isArchived,
        secondaryPrice,
        secondaryCurrency,
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'name': name,
      'category': category,
      'description': description,
      'price': price,
      'rating': rating,
      'isOffer': isOffer,
      'images': images,
      'inStock': inStock,
      'sizes': sizes,
      'videoUrl': videoUrl,
      'colors': colors,
      'stockQuantity': stockQuantity,
      'salesCount': salesCount,
      'variants': variants.map((x) => x.toJson()).toList(),
      'isFeaturedDeal': isFeaturedDeal,
      'oldPrice': oldPrice,
      'discountPercentage': discountPercentage,
      'isDailyStarred': isDailyStarred,
      'barcode': barcode,
      'lastSupplierId': lastSupplierId,
      'wholesalePrice': wholesalePrice,
      'purchasePrice': purchasePrice,
      'expiryDate': expiryDate?.toIso8601String(),
      'minStockLevel': minStockLevel,
      'unit': unit,
      'isArchived': isArchived,
      'secondaryPrice': secondaryPrice,
      'secondaryCurrency': secondaryCurrency,
    };
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? 'landan',
      name: json['name'] as String? ?? 'Unnamed Product',
      category: json['category'] as String? ?? 'All',
      description: json['description'] as String? ?? '',
      price: (json['price'] as num? ?? 0.0).toDouble(),
      rating: (json['rating'] as num? ?? 0.0).toDouble(),
      isOffer: json['isOffer'] as bool? ?? false,
      images: (json['images'] as List?)?.map((e) => e.toString()).toList() ?? 
             (json['imageUrl'] != null ? [json['imageUrl'].toString()] : []),
      inStock: json['inStock'] as bool? ?? true,
      sizes: (json['sizes'] as List?)?.map((e) => e.toString()).toList() ?? [],
      videoUrl: json['videoUrl'] as String?,
      colors: (json['colors'] as List?)?.map((e) => e.toString()).toList() ?? [],
      stockQuantity: (json['stockQuantity'] as num? ?? 0).toInt(),
      salesCount: (json['salesCount'] as num? ?? 0).toInt(),
      variants: (json['variants'] as List?)
              ?.map((e) => e is Map<String, dynamic> ? ProductVariant.fromJson(e) : null)
              .whereType<ProductVariant>()
              .toList() ??
          [],
      isFeaturedDeal: json['isFeaturedDeal'] as bool? ?? false,
      oldPrice: (json['oldPrice'] as num?)?.toDouble(),
      discountPercentage: (json['discountPercentage'] as num?)?.toInt(),
      isDailyStarred: json['isDailyStarred'] as bool? ?? false,
      barcode: json['barcode'] as String?,
      lastSupplierId: json['lastSupplierId'] as String?,
      wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble(),
      purchasePrice: (json['purchasePrice'] as num?)?.toDouble(),
      expiryDate: json['expiryDate'] != null ? DateTime.tryParse(json['expiryDate'].toString()) : null,
      minStockLevel: (json['minStockLevel'] as num?)?.toInt(),
      unit: json['unit'] as String?,
      isArchived: json['isArchived'] as bool? ?? false,
      secondaryPrice: (json['secondaryPrice'] as num?)?.toDouble() ?? (json['secondary_price'] as num?)?.toDouble(),
      secondaryCurrency: json['secondaryCurrency'] as String? ?? json['secondary_currency'] as String?,
    );
  }

  ProductModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? category,
    String? description,
    double? price,
    double? rating,
    bool? isOffer,
    List<String>? images,
    bool? inStock,
    List<String>? sizes,
    String? videoUrl,
    List<String>? colors,
    int? stockQuantity,
    int? salesCount,
    List<ProductVariant>? variants,
    bool? isFeaturedDeal,
    double? oldPrice,
    int? discountPercentage,
    bool? isDailyStarred,
    String? barcode,
    String? lastSupplierId,
    double? wholesalePrice,
    double? purchasePrice,
    DateTime? expiryDate,
    int? minStockLevel,
    String? unit,
    bool? isArchived,
    double? secondaryPrice,
    String? secondaryCurrency,
  }) {
    return ProductModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      category: category ?? this.category,
      description: description ?? this.description,
      price: price ?? this.price,
      rating: rating ?? this.rating,
      isOffer: isOffer ?? this.isOffer,
      images: images ?? this.images,
      inStock: inStock ?? this.inStock,
      sizes: sizes ?? this.sizes,
      videoUrl: videoUrl ?? this.videoUrl,
      colors: colors ?? this.colors,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      salesCount: salesCount ?? this.salesCount,
      variants: variants ?? this.variants,
      isFeaturedDeal: isFeaturedDeal ?? this.isFeaturedDeal,
      oldPrice: oldPrice ?? this.oldPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      isDailyStarred: isDailyStarred ?? this.isDailyStarred,
      barcode: barcode ?? this.barcode,
      lastSupplierId: lastSupplierId ?? this.lastSupplierId,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      expiryDate: expiryDate ?? this.expiryDate,
      minStockLevel: minStockLevel ?? this.minStockLevel,
      unit: unit ?? this.unit,
      isArchived: isArchived ?? this.isArchived,
      secondaryPrice: secondaryPrice ?? this.secondaryPrice,
      secondaryCurrency: secondaryCurrency ?? this.secondaryCurrency,
    );
  }

  double getPriceForCurrency(String? targetCurrency) {
    if (targetCurrency != null &&
        targetCurrency.isNotEmpty &&
        secondaryCurrency == targetCurrency &&
        secondaryPrice != null &&
        secondaryPrice! > 0) {
      return secondaryPrice!;
    }
    return price;
  }

  String formatPriceForCurrency(String? targetCurrency, {String defaultUnit = 'د.ع'}) {
    if (targetCurrency != null &&
        targetCurrency.isNotEmpty &&
        secondaryCurrency == targetCurrency &&
        secondaryPrice != null &&
        secondaryPrice! > 0) {
      final s = secondaryPrice! % 1 == 0
          ? secondaryPrice!.toInt().toString()
          : secondaryPrice!.toStringAsFixed(2);
      return '$s $targetCurrency';
    }
    final p = price % 1 == 0
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
    return '$p ${targetCurrency?.isNotEmpty == true ? targetCurrency! : defaultUnit}';
  }
}


