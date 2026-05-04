// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_storage_location.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ProductStorageLocationAdapter
    extends TypeAdapter<ProductStorageLocation> {
  @override
  final int typeId = 2;

  @override
  ProductStorageLocation read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ProductStorageLocation(
      warehouseName: fields[0] as String,
      shelf: fields[1] as String?,
      box: fields[2] as String?,
      quantity: (fields[3] as num).toInt(),
      priceOverride: (fields[4] as num?)?.toDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, ProductStorageLocation obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.warehouseName)
      ..writeByte(1)
      ..write(obj.shelf)
      ..writeByte(2)
      ..write(obj.box)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.priceOverride);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductStorageLocationAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
