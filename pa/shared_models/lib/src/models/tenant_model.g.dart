// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tenant_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TenantModelAdapter extends TypeAdapter<TenantModel> {
  @override
  final int typeId = 3;

  @override
  TenantModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TenantModel(
      id: fields[0] as String,
      name: fields[1] as String,
      adminIds: (fields[2] as List).cast<String>(),
      logoUrl: fields[3] as String?,
      description: fields[4] as String,
      whatsappNumber: fields[5] as String,
      primaryColor: fields[6] as String,
      isActive: fields[7] as bool,
      createdAt: fields[8] as DateTime,
      expiryDate: fields[9] as DateTime?,
      activationCode: fields[10] as String?,
      subscriberCount: (fields[11] as num).toInt(),
      managerName: fields[12] as String?,
      managerPhone: fields[13] as String?,
      registrationPoints: (fields[14] as num).toInt(),
      purchasePointsPercent: (fields[15] as num).toDouble(),
      pointsToCurrencyRatio: (fields[16] as num).toDouble(),
      sharesRewardPoints: (fields[17] as num).toInt(),
      reviewRewardPoints: (fields[18] as num).toInt(),
      currencyUnit: fields[19] as String,
      shippingCost: (fields[20] as num).toDouble(),
      oneSignalAppId: fields[21] as String?,
      oneSignalRestKey: fields[22] as String?,
      firstOrderDiscountEnabled: fields[23] as bool,
      firstOrderDiscountPercent: (fields[24] as num).toDouble(),
      firstOrderDiscountAmount: (fields[25] as num).toDouble(),
      maxDailyReviewPoints: (fields[26] as num).toInt(),
      maxDailySharePoints: (fields[27] as num).toInt(),
      maxDailyPurchasePoints: (fields[28] as num).toInt(),
      isStoreEnabled: fields[32] as bool,
      isPosEnabled: fields[29] as bool,
      posExpiryDate: fields[30] as DateTime?,
      posActivationCode: fields[31] as String?,
      isCarsEnabled: fields[34] as bool,
      carsExpiryDate: fields[35] as DateTime?,
      carsActivationCode: fields[36] as String?,
      appType: fields[33] as String,
    );
  }

  @override
  void write(BinaryWriter writer, TenantModel obj) {
    writer
      ..writeByte(37)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.adminIds)
      ..writeByte(3)
      ..write(obj.logoUrl)
      ..writeByte(4)
      ..write(obj.description)
      ..writeByte(5)
      ..write(obj.whatsappNumber)
      ..writeByte(6)
      ..write(obj.primaryColor)
      ..writeByte(7)
      ..write(obj.isActive)
      ..writeByte(8)
      ..write(obj.createdAt)
      ..writeByte(9)
      ..write(obj.expiryDate)
      ..writeByte(10)
      ..write(obj.activationCode)
      ..writeByte(11)
      ..write(obj.subscriberCount)
      ..writeByte(12)
      ..write(obj.managerName)
      ..writeByte(13)
      ..write(obj.managerPhone)
      ..writeByte(32)
      ..write(obj.isStoreEnabled)
      ..writeByte(29)
      ..write(obj.isPosEnabled)
      ..writeByte(30)
      ..write(obj.posExpiryDate)
      ..writeByte(31)
      ..write(obj.posActivationCode)
      ..writeByte(34)
      ..write(obj.isCarsEnabled)
      ..writeByte(35)
      ..write(obj.carsExpiryDate)
      ..writeByte(36)
      ..write(obj.carsActivationCode)
      ..writeByte(33)
      ..write(obj.appType)
      ..writeByte(14)
      ..write(obj.registrationPoints)
      ..writeByte(15)
      ..write(obj.purchasePointsPercent)
      ..writeByte(16)
      ..write(obj.pointsToCurrencyRatio)
      ..writeByte(17)
      ..write(obj.sharesRewardPoints)
      ..writeByte(18)
      ..write(obj.reviewRewardPoints)
      ..writeByte(19)
      ..write(obj.currencyUnit)
      ..writeByte(20)
      ..write(obj.shippingCost)
      ..writeByte(21)
      ..write(obj.oneSignalAppId)
      ..writeByte(22)
      ..write(obj.oneSignalRestKey)
      ..writeByte(23)
      ..write(obj.firstOrderDiscountEnabled)
      ..writeByte(24)
      ..write(obj.firstOrderDiscountPercent)
      ..writeByte(25)
      ..write(obj.firstOrderDiscountAmount)
      ..writeByte(26)
      ..write(obj.maxDailyReviewPoints)
      ..writeByte(27)
      ..write(obj.maxDailySharePoints)
      ..writeByte(28)
      ..write(obj.maxDailyPurchasePoints);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TenantModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
