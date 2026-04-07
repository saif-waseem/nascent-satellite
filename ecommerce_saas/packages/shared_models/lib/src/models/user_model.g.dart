// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 4;

  @override
  UserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserModel(
      id: fields[0] as String,
      email: fields[1] as String,
      name: fields[2] as String?,
      tenantId: fields[3] as String?,
      loyaltyPoints: fields[4] as int,
      pendingPoints: fields[5] as int,
      sharesCount: fields[6] as int,
      totalSpent: fields[7] as double,
      password: fields[8] as String?,
      createdAt: fields[9] as DateTime,
      isBlocked: fields[10] as bool,
      address: fields[11] as String?,
      landmark: fields[15] as String?,
      phone: fields[16] as String?,
      lastCheckInDate: fields[12] as DateTime?,
      checkInStreak: fields[13] as int,
      purchaseCount: fields[14] as int,
      balance: fields[17] as double,
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.email)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.tenantId)
      ..writeByte(4)
      ..write(obj.loyaltyPoints)
      ..writeByte(5)
      ..write(obj.pendingPoints)
      ..writeByte(6)
      ..write(obj.sharesCount)
      ..writeByte(7)
      ..write(obj.totalSpent)
      ..writeByte(8)
      ..write(obj.password)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.isBlocked)
      ..writeByte(11)
      ..write(obj.address)
      ..writeByte(12)
      ..write(obj.lastCheckInDate)
      ..writeByte(13)
      ..write(obj.checkInStreak)
      ..writeByte(14)
      ..write(obj.purchaseCount)
      ..writeByte(15)
      ..write(obj.landmark)
      ..writeByte(16)
      ..write(obj.phone)
      ..writeByte(17)
      ..write(obj.balance);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
