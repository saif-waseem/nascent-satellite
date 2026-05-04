// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderModelAdapter extends TypeAdapter<OrderModel> {
  @override
  final int typeId = 5;

  @override
  OrderModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OrderModel(
      id: fields[0] as String,
      userId: fields[1] as String,
      tenantId: fields[2] as String,
      total: (fields[3] as num).toDouble(),
      items: (fields[4] as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
      status: fields[5] as OrderStatus,
      tracking: fields[6] as String,
      userName: fields[8] as String,
      userPhone: fields[9] as String,
      date: fields[7] as DateTime,
      address: fields[10] as String,
      landmark: fields[18] as String?,
      pointsAwarded: (fields[11] as num).toInt(),
      pointsRedeemed: (fields[12] as num).toInt(),
      discountAmount: (fields[13] as num).toDouble(),
      shippingCost: (fields[15] as num).toDouble(),
      couponCode: fields[14] as String?,
      isHiddenForUser: fields[16] as bool,
      isHiddenForAdmin: fields[17] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, OrderModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.tenantId)
      ..writeByte(3)
      ..write(obj.total)
      ..writeByte(4)
      ..write(obj.items)
      ..writeByte(5)
      ..write(obj.status)
      ..writeByte(6)
      ..write(obj.tracking)
      ..writeByte(7)
      ..write(obj.date)
      ..writeByte(8)
      ..write(obj.userName)
      ..writeByte(9)
      ..write(obj.userPhone)
      ..writeByte(10)
      ..write(obj.address)
      ..writeByte(11)
      ..write(obj.pointsAwarded)
      ..writeByte(12)
      ..write(obj.pointsRedeemed)
      ..writeByte(13)
      ..write(obj.discountAmount)
      ..writeByte(14)
      ..write(obj.couponCode)
      ..writeByte(15)
      ..write(obj.shippingCost)
      ..writeByte(16)
      ..write(obj.isHiddenForUser)
      ..writeByte(17)
      ..write(obj.isHiddenForAdmin)
      ..writeByte(18)
      ..write(obj.landmark);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OrderStatusAdapter extends TypeAdapter<OrderStatus> {
  @override
  final int typeId = 6;

  @override
  OrderStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OrderStatus.active;
      case 1:
        return OrderStatus.completed;
      case 2:
        return OrderStatus.cancelled;
      default:
        return OrderStatus.active;
    }
  }

  @override
  void write(BinaryWriter writer, OrderStatus obj) {
    switch (obj) {
      case OrderStatus.active:
        writer.writeByte(0);
        break;
      case OrderStatus.completed:
        writer.writeByte(1);
        break;
      case OrderStatus.cancelled:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
