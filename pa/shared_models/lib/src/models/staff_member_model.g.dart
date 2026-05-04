// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'staff_member_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StaffMemberModelAdapter extends TypeAdapter<StaffMemberModel> {
  @override
  final int typeId = 30;

  @override
  StaffMemberModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StaffMemberModel(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      name: fields[2] as String,
      roleName: fields[3] as String,
      pinCode: fields[4] as String?,
      email: fields[5] as String?,
      isActive: fields[6] as bool,
      createdAt: fields[7] as DateTime,
      salaryAmount: (fields[8] as num).toDouble(),
      salaryCycleDays: (fields[9] as num).toInt(),
      requiredDaysForSalary: (fields[10] as num).toInt(),
      lastSalaryPaidDate: fields[11] as DateTime?,
      dailyShiftCount: (fields[12] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, StaffMemberModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tenantId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.roleName)
      ..writeByte(4)
      ..write(obj.pinCode)
      ..writeByte(5)
      ..write(obj.email)
      ..writeByte(6)
      ..write(obj.isActive)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.salaryAmount)
      ..writeByte(9)
      ..write(obj.salaryCycleDays)
      ..writeByte(10)
      ..write(obj.requiredDaysForSalary)
      ..writeByte(11)
      ..write(obj.lastSalaryPaidDate)
      ..writeByte(12)
      ..write(obj.dailyShiftCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffMemberModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
