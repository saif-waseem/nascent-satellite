import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'purchase_invoice_model.g.dart';

@HiveType(typeId: 23)
enum PurchaseInvoiceStatus {
  @HiveField(0)
  draft,
  @HiveField(1)
  finalized,
}

@HiveType(typeId: 21)
class PurchaseInvoiceModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String supplierId;
  @HiveField(3)
  final List<InvoiceItem> items;
  @HiveField(4)
  final double totalAmount;
  @HiveField(5)
  final double paidAmount;
  @HiveField(6)
  final DateTime date;
  @HiveField(7)
  final PurchaseInvoiceStatus status;
  @HiveField(8)
  final double totalDiscount;
  @HiveField(9)
  final String? sessionName;
  // Not a Hive field — resolved from the name at save time
  final String? supplierName;

  const PurchaseInvoiceModel({
    required this.id,
    required this.tenantId,
    required this.supplierId,
    required this.items,
    required this.totalAmount,
    required this.paidAmount,
    required this.date,
    this.status = PurchaseInvoiceStatus.finalized,
    this.totalDiscount = 0.0,
    this.sessionName,
    this.supplierName,
  });

  double get remainingAmount => totalAmount - paidAmount;

  PurchaseInvoiceModel copyWith({
    String? id,
    String? tenantId,
    String? supplierId,
    List<InvoiceItem>? items,
    double? totalAmount,
    double? paidAmount,
    DateTime? date,
    PurchaseInvoiceStatus? status,
    double? totalDiscount,
    String? sessionName,
    String? supplierName,
  }) {
    return PurchaseInvoiceModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      supplierId: supplierId ?? this.supplierId,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      date: date ?? this.date,
      status: status ?? this.status,
      totalDiscount: totalDiscount ?? this.totalDiscount,
      sessionName: sessionName ?? this.sessionName,
      supplierName: supplierName ?? this.supplierName,
    );
  }

  @override
  List<Object?> get props => [id, tenantId, supplierId, items, totalAmount, paidAmount, date, status, totalDiscount, sessionName, supplierName];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'items': items.map((e) => e.toJson()).toList(),
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'date': date.toIso8601String(),
      'status': status.name,
      'totalDiscount': totalDiscount,
      'sessionName': sessionName,
    };
  }

  factory PurchaseInvoiceModel.fromJson(Map<String, dynamic> json) {
    return PurchaseInvoiceModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      supplierId: json['supplierId'] as String? ?? '',
      supplierName: json['supplierName'] as String?,
      items: (json['items'] as List?)
              ?.map((e) => InvoiceItem.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      totalAmount: (json['totalAmount'] as num? ?? 0.0).toDouble(),
      paidAmount: (json['paidAmount'] as num? ?? 0.0).toDouble(),
      date: _parseDate(json['date']),
      status: json['status'] == 'finalized' 
          ? PurchaseInvoiceStatus.finalized 
          : PurchaseInvoiceStatus.draft,
      totalDiscount: (json['totalDiscount'] as num? ?? 0.0).toDouble(),
      sessionName: json['sessionName'] as String?,
    );
  }

  static DateTime _parseDate(dynamic val) {
    if (val is DateTime) return val;
    if (val is String) return DateTime.parse(val);
    return DateTime.now();
  }
}

@HiveType(typeId: 22)
class InvoiceItem extends Equatable {
  @HiveField(0)
  final String productId;
  @HiveField(1)
  final String productName;
  @HiveField(2)
  final int quantity;
  @HiveField(3)
  final double unitCost;
  @HiveField(4)
  final double discount;

  @HiveField(5)
  final String? variantColor;
  @HiveField(6)
  final String? variantSize;

  const InvoiceItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    this.discount = 0.0,
    this.variantColor,
    this.variantSize,
  });

  double get totalCost => (quantity * unitCost) - discount;

  @override
  List<Object?> get props => [productId, productName, quantity, unitCost, discount, variantColor, variantSize];

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitCost': unitCost,
      'discount': discount,
      'variantColor': variantColor,
      'variantSize': variantSize,
    };
  }

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      quantity: (json['quantity'] as num? ?? 0).toInt(),
      unitCost: (json['unitCost'] as num? ?? 0.0).toDouble(),
      discount: (json['discount'] as num? ?? 0.0).toDouble(),
      variantColor: json['variantColor'] as String?,
      variantSize: json['variantSize'] as String?,
    );
  }
}
