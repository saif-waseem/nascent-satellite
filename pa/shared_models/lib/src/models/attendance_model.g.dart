// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttendanceModelAdapter extends TypeAdapter<AttendanceModel> {
  @override
  final int typeId = 35;

  @override
  AttendanceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AttendanceModel(
      id: fields[0] as String,
      staffId: fields[1] as String,
      staffName: fields[2] as String,
      tenantId: fields[3] as String,
      checkIn: fields[4] as DateTime,
      checkOut: fields[5] as DateTime?,
      note: fields[6] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AttendanceModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.staffId)
      ..writeByte(2)
      ..write(obj.staffName)
      ..writeByte(3)
      ..write(obj.tenantId)
      ..writeByte(4)
      ..write(obj.checkIn)
      ..writeByte(5)
      ..write(obj.checkOut)
      ..writeByte(6)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
