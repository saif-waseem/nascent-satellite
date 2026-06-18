// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'car_contract_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CarContractModelAdapter extends TypeAdapter<CarContractModel> {
  @override
  final int typeId = 36;

  @override
  CarContractModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CarContractModel(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      sellerName: fields[2] as String,
      sellerId: fields[3] as String?,
      sellerAddress: fields[4] as String?,
      sellerPhone: fields[5] as String?,
      sellerMukhtar: fields[6] as String?,
      sellerPhotoUrl: fields[7] as String?,
      buyerName: fields[8] as String,
      buyerId: fields[9] as String?,
      buyerAddress: fields[10] as String?,
      buyerPhone: fields[11] as String?,
      buyerMukhtar: fields[12] as String?,
      buyerPhotoUrl: fields[13] as String?,
      carType: fields[14] as String,
      carModelName: fields[15] as String,
      carYear: fields[16] as String?,
      carPlate: fields[17] as String?,
      carColor: fields[18] as String?,
      carAnnualId: fields[19] as String?,
      carChassis: fields[20] as String?,
      priceTotal: (fields[21] as num).toDouble(),
      pricePaid: (fields[22] as num).toDouble(),
      priceRemaining: (fields[23] as num).toDouble(),
      notes: fields[24] as String?,
      createdAt: fields[25] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, CarContractModel obj) {
    writer
      ..writeByte(26)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tenantId)
      ..writeByte(2)
      ..write(obj.sellerName)
      ..writeByte(3)
      ..write(obj.sellerId)
      ..writeByte(4)
      ..write(obj.sellerAddress)
      ..writeByte(5)
      ..write(obj.sellerPhone)
      ..writeByte(6)
      ..write(obj.sellerMukhtar)
      ..writeByte(7)
      ..write(obj.sellerPhotoUrl)
      ..writeByte(8)
      ..write(obj.buyerName)
      ..writeByte(9)
      ..write(obj.buyerId)
      ..writeByte(10)
      ..write(obj.buyerAddress)
      ..writeByte(11)
      ..write(obj.buyerPhone)
      ..writeByte(12)
      ..write(obj.buyerMukhtar)
      ..writeByte(13)
      ..write(obj.buyerPhotoUrl)
      ..writeByte(14)
      ..write(obj.carType)
      ..writeByte(15)
      ..write(obj.carModelName)
      ..writeByte(16)
      ..write(obj.carYear)
      ..writeByte(17)
      ..write(obj.carPlate)
      ..writeByte(18)
      ..write(obj.carColor)
      ..writeByte(19)
      ..write(obj.carAnnualId)
      ..writeByte(20)
      ..write(obj.carChassis)
      ..writeByte(21)
      ..write(obj.priceTotal)
      ..writeByte(22)
      ..write(obj.pricePaid)
      ..writeByte(23)
      ..write(obj.priceRemaining)
      ..writeByte(24)
      ..write(obj.notes)
      ..writeByte(25)
      ..write(obj.createdAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CarContractModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
