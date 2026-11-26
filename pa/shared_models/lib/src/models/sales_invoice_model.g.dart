// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sales_invoice_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SalesInvoiceModelAdapter extends TypeAdapter<SalesInvoiceModel> {
  @override
  final int typeId = 24;

  @override
  SalesInvoiceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SalesInvoiceModel(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      receiptNumber: fields[2] as String,
      items: (fields[3] as List).cast<SalesItem>(),
      totalAmount: (fields[4] as num).toDouble(),
      discountAmount: (fields[5] as num).toDouble(),
      date: fields[6] as DateTime,
      customerId: fields[7] as String?,
      customerName: fields[8] as String?,
      isReturned: fields[9] as bool,
      status: fields[10] as SalesInvoiceStatus,
      sessionName: fields[11] as String?,
      pointsRedeemed: (fields[12] as num).toInt(),
      paidAmount: (fields[13] as num).toDouble(),
      addedBy: fields[14] as String?,
      addedById: fields[15] as String?,
      shiftId: fields[16] as String?,
      currency: fields[17] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, SalesInvoiceModel obj) {
    writer
      ..writeByte(18)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tenantId)
      ..writeByte(2)
      ..write(obj.receiptNumber)
      ..writeByte(3)
      ..write(obj.items)
      ..writeByte(4)
      ..write(obj.totalAmount)
      ..writeByte(5)
      ..write(obj.discountAmount)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.customerId)
      ..writeByte(8)
      ..write(obj.customerName)
      ..writeByte(9)
      ..write(obj.isReturned)
      ..writeByte(10)
      ..write(obj.status)
      ..writeByte(11)
      ..write(obj.sessionName)
      ..writeByte(12)
      ..write(obj.pointsRedeemed)
      ..writeByte(13)
      ..write(obj.paidAmount)
      ..writeByte(14)
      ..write(obj.addedBy)
      ..writeByte(15)
      ..write(obj.addedById)
      ..writeByte(16)
      ..write(obj.shiftId)
      ..writeByte(17)
      ..write(obj.currency);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesInvoiceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SalesItemAdapter extends TypeAdapter<SalesItem> {
  @override
  final int typeId = 25;

  @override
  SalesItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SalesItem(
      productId: fields[0] as String,
      productName: fields[1] as String,
      quantity: (fields[2] as num).toInt(),
      unitPrice: (fields[3] as num).toDouble(),
      discount: (fields[4] as num).toDouble(),
      category: fields[5] as String,
      variantColor: fields[6] as String?,
      variantSize: fields[7] as String?,
      warehouseName: fields[8] as String?,
      shelf: fields[9] as String?,
      box: fields[10] as String?,
      batchNumber: fields[11] as String?,
      expiryDate: fields[12] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, SalesItem obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.productId)
      ..writeByte(1)
      ..write(obj.productName)
      ..writeByte(2)
      ..write(obj.quantity)
      ..writeByte(3)
      ..write(obj.unitPrice)
      ..writeByte(4)
      ..write(obj.discount)
      ..writeByte(5)
      ..write(obj.category)
      ..writeByte(6)
      ..write(obj.variantColor)
      ..writeByte(7)
      ..write(obj.variantSize)
      ..writeByte(8)
      ..write(obj.warehouseName)
      ..writeByte(9)
      ..write(obj.shelf)
      ..writeByte(10)
      ..write(obj.box)
      ..writeByte(11)
      ..write(obj.batchNumber)
      ..writeByte(12)
      ..write(obj.expiryDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SalesInvoiceStatusAdapter extends TypeAdapter<SalesInvoiceStatus> {
  @override
  final int typeId = 26;

  @override
  SalesInvoiceStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return SalesInvoiceStatus.draft;
      case 1:
        return SalesInvoiceStatus.finalized;
      default:
        return SalesInvoiceStatus.draft;
    }
  }

  @override
  void write(BinaryWriter writer, SalesInvoiceStatus obj) {
    switch (obj) {
      case SalesInvoiceStatus.draft:
        writer.writeByte(0);
        break;
      case SalesInvoiceStatus.finalized:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SalesInvoiceStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
