// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_invoice_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PurchaseInvoiceModelAdapter extends TypeAdapter<PurchaseInvoiceModel> {
  @override
  final int typeId = 21;

  @override
  PurchaseInvoiceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PurchaseInvoiceModel(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      supplierId: fields[2] as String,
      items: (fields[3] as List).cast<InvoiceItem>(),
      totalAmount: fields[4] as double,
      paidAmount: fields[5] as double,
      date: fields[6] as DateTime,
      status: fields[7] as PurchaseInvoiceStatus,
      totalDiscount: fields[8] as double,
      sessionName: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PurchaseInvoiceModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tenantId)
      ..writeByte(2)
      ..write(obj.supplierId)
      ..writeByte(3)
      ..write(obj.items)
      ..writeByte(4)
      ..write(obj.totalAmount)
      ..writeByte(5)
      ..write(obj.paidAmount)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.totalDiscount)
      ..writeByte(9)
      ..write(obj.sessionName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseInvoiceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class InvoiceItemAdapter extends TypeAdapter<InvoiceItem> {
  @override
  final int typeId = 22;

  @override
  InvoiceItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return InvoiceItem(
      productId: fields[0] as String,
      productName: fields[1] as String,
      quantity: fields[2] as int,
      unitCost: fields[3] as double,
      discount: fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, InvoiceItem obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.unitCost)
      ..writeByte(4)
      ..write(obj.discount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InvoiceItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PurchaseInvoiceStatusAdapter extends TypeAdapter<PurchaseInvoiceStatus> {
  @override
  final int typeId = 23;

  @override
  PurchaseInvoiceStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PurchaseInvoiceStatus.draft;
      case 1:
        return PurchaseInvoiceStatus.finalized;
      default:
        return PurchaseInvoiceStatus.draft;
    }
  }

  @override
  void write(BinaryWriter writer, PurchaseInvoiceStatus obj) {
    switch (obj) {
      case PurchaseInvoiceStatus.draft:
        writer.writeByte(0);
        break;
      case PurchaseInvoiceStatus.finalized:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PurchaseInvoiceStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
