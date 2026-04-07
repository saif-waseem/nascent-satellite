// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductModelAdapter extends TypeAdapter<ProductModel> {
  @override
  final int typeId = 0;

  @override
  ProductModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductModel(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      name: fields[2] as String,
      category: fields[3] as String,
      description: fields[4] as String,
      price: fields[5] as double,
      rating: fields[6] as double,
      isOffer: fields[7] as bool,
      images: (fields[8] as List).cast<String>(),
      inStock: fields[9] as bool,
      sizes: (fields[10] as List).cast<String>(),
      videoUrl: fields[15] as String?,
      colors: (fields[11] as List).cast<String>(),
      stockQuantity: fields[12] as int,
      salesCount: fields[13] as int,
      variants: (fields[14] as List).cast<ProductVariant>(),
      isFeaturedDeal: fields[17] as bool,
      oldPrice: fields[18] as double?,
      discountPercentage: fields[19] as int?,
      isDailyStarred: fields[20] as bool,
      barcode: fields[21] as String?,
      lastSupplierId: fields[22] as String?,
      wholesalePrice: fields[23] as double?,
      purchasePrice: fields[24] as double?,
      expiryDate: fields[25] as DateTime?,
      minStockLevel: fields[26] as int?,
      unit: fields[27] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ProductModel obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tenantId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.category)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.price)
      ..writeByte(6)
      ..write(obj.rating)
      ..writeByte(7)
      ..write(obj.isOffer)
      ..writeByte(8)
      ..write(obj.images)
      ..writeByte(9)
      ..write(obj.inStock)
      ..writeByte(10)
      ..write(obj.sizes)
      ..writeByte(11)
      ..write(obj.colors)
      ..writeByte(12)
      ..write(obj.stockQuantity)
      ..writeByte(13)
      ..write(obj.salesCount)
      ..writeByte(14)
      ..write(obj.variants)
      ..writeByte(15)
      ..write(obj.videoUrl)
      ..writeByte(17)
      ..write(obj.isFeaturedDeal)
      ..writeByte(18)
      ..write(obj.oldPrice)
      ..writeByte(19)
      ..write(obj.discountPercentage)
      ..writeByte(20)
      ..write(obj.isDailyStarred)
      ..writeByte(21)
      ..write(obj.barcode)
      ..writeByte(22)
      ..write(obj.lastSupplierId)
      ..writeByte(23)
      ..write(obj.wholesalePrice)
      ..writeByte(24)
      ..write(obj.purchasePrice)
      ..writeByte(25)
      ..write(obj.expiryDate)
      ..writeByte(26)
      ..write(obj.minStockLevel)
      ..writeByte(27)
      ..write(obj.unit);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
