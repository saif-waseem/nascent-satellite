import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'sales_invoice_model.g.dart';

@HiveType(typeId: 26)
enum SalesInvoiceStatus {
  @HiveField(0)
  draft,
  @HiveField(1)
  finalized,
}

@HiveType(typeId: 24)
class SalesInvoiceModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String receiptNumber;
  @HiveField(3)
  final List<SalesItem> items;
  @HiveField(4)
  final double totalAmount;
  @HiveField(5)
  final double discountAmount;
  @HiveField(6)
  final DateTime date;
  @HiveField(7)
  final String? customerId;
  @HiveField(8)
  final String? customerName;
  @HiveField(9)
  final bool isReturned;
  @HiveField(10)
  final SalesInvoiceStatus status;
  @HiveField(11)
  final String? sessionName;
  @HiveField(12)
  final int pointsRedeemed;
  @HiveField(13)
  final double paidAmount;
  @HiveField(14)
  final String? addedBy;
  @HiveField(15)
  final String? addedById;
  @HiveField(16)
  final String? shiftId;

  const SalesInvoiceModel({
    required this.id,
    required this.tenantId,
    required this.receiptNumber,
    required this.items,
    required this.totalAmount,
    this.discountAmount = 0.0,
    required this.date,
    this.customerId,
    this.customerName,
    this.isReturned = false,
    this.status = SalesInvoiceStatus.finalized,
    this.sessionName,
    this.pointsRedeemed = 0,
    this.paidAmount = 0.0,
    this.addedBy,
    this.addedById,
    this.shiftId,
  });

  @override
  List<Object?> get props => [
        id,
        tenantId,
        receiptNumber,
        items,
        totalAmount,
        discountAmount,
        date,
        customerId,
        customerName,
        isReturned,
        status,
        sessionName,
        pointsRedeemed,
        paidAmount,
        addedBy,
        addedById,
      ];

  SalesInvoiceModel copyWith({
    String? id,
    String? tenantId,
    String? receiptNumber,
    List<SalesItem>? items,
    double? totalAmount,
    double? discountAmount,
    DateTime? date,
    String? customerId,
    String? customerName,
    bool? isReturned,
    SalesInvoiceStatus? status,
    String? sessionName,
    int? pointsRedeemed,
    double? paidAmount,
    String? addedBy,
    String? addedById,
    String? shiftId,
  }) {
    return SalesInvoiceModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      date: date ?? this.date,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      isReturned: isReturned ?? this.isReturned,
      status: status ?? this.status,
      sessionName: sessionName ?? this.sessionName,
      pointsRedeemed: pointsRedeemed ?? this.pointsRedeemed,
      paidAmount: paidAmount ?? this.paidAmount,
      addedBy: addedBy ?? this.addedBy,
      addedById: addedById ?? this.addedById,
      shiftId: shiftId ?? this.shiftId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'receiptNumber': receiptNumber,
      'items': items.map((e) => e.toJson()).toList(),
      'totalAmount': totalAmount,
      'discountAmount': discountAmount,
      'date': date.toIso8601String(),
      'customerId': customerId,
      'customerName': customerName,
      'isReturned': isReturned,
      'status': status.name,
      'sessionName': sessionName,
      'pointsRedeemed': pointsRedeemed,
      'paidAmount': paidAmount,
      'addedBy': addedBy,
      'addedById': addedById,
      'shiftId': shiftId,
    };
  }

  factory SalesInvoiceModel.fromJson(Map<String, dynamic> json) {
    return SalesInvoiceModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      receiptNumber: json['receiptNumber'] as String? ?? '',
      items: (json['items'] as List?)
              ?.map((e) => SalesItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: (json['totalAmount'] as num? ?? 0.0).toDouble(),
      discountAmount: (json['discountAmount'] as num? ?? 0.0).toDouble(),
      date: _parseDate(json['date']),
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String?,
      isReturned: json['isReturned'] as bool? ?? false,
      status: SalesInvoiceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SalesInvoiceStatus.finalized,
      ),
      sessionName: json['sessionName'] as String?,
      pointsRedeemed: json['pointsRedeemed'] as int? ?? 0,
      paidAmount: (json['paidAmount'] as num? ?? 0.0).toDouble(),
      addedBy: json['addedBy'] as String?,
      addedById: json['addedById'] as String?,
      shiftId: json['shiftId'] as String?,
    );
  }

  static DateTime _parseDate(dynamic val) {
    if (val is DateTime) return val;
    if (val is String) return DateTime.parse(val);
    return DateTime.now();
  }
}

@HiveType(typeId: 25)
class SalesItem extends Equatable {
  @HiveField(0)
  final String productId;
  @HiveField(1)
  final String productName;
  @HiveField(2)
  final int quantity;
  @HiveField(3)
  final double unitPrice;
  @HiveField(4)
  final double discount;
  @HiveField(5)
  final String category;
  @HiveField(6)
  final String? variantColor;
  @HiveField(7)
  final String? variantSize;
  @HiveField(8)
  final String? warehouseName;
  @HiveField(9)
  final String? shelf;
  @HiveField(10)
  final String? box;

  const SalesItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.discount = 0.0,
    this.category = '',
    this.variantColor,
    this.variantSize,
    this.warehouseName,
    this.shelf,
    this.box,
  });

  double get totalPrice => (quantity * unitPrice) - discount;

  @override
  List<Object?> get props =>
      [productId, productName, quantity, unitPrice, discount, category, variantColor, variantSize, warehouseName, shelf, box];

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'discount': discount,
      'category': category,
      'variantColor': variantColor,
      'variantSize': variantSize,
      'warehouseName': warehouseName,
      'shelf': shelf,
      'box': box,
    };
  }

  factory SalesItem.fromJson(Map<String, dynamic> json) {
    return SalesItem(
      productId: json['productId'] as String? ?? '',
      productName: json['productName'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 0,
      unitPrice: (json['unitPrice'] as num? ?? 0.0).toDouble(),
      discount: (json['discount'] as num? ?? 0.0).toDouble(),
      category: json['category'] as String? ?? '',
      variantColor: json['variantColor'] as String?,
      variantSize: json['variantSize'] as String?,
      warehouseName: json['warehouseName'] as String?,
      shelf: json['shelf'] as String?,
      box: json['box'] as String?,
    );
  }
}
