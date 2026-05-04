// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pos_role_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PosRoleModelAdapter extends TypeAdapter<PosRoleModel> {
  @override
  final int typeId = 32;

  @override
  PosRoleModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PosRoleModel(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      name: fields[2] as String,
      permissions: (fields[3] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, PosRoleModel obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tenantId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.permissions);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PosRoleModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
