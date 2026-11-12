import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'car_contract_model.g.dart';

@HiveType(typeId: 36)
class CarContractModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String sellerName;
  @HiveField(3)
  final String? sellerId;
  @HiveField(4)
  final String? sellerAddress;
  @HiveField(5)
  final String? sellerPhone;
  @HiveField(6)
  final String? sellerMukhtar;
  @HiveField(7)
  final String? sellerPhotoUrl;

  @HiveField(8)
  final String buyerName;
  @HiveField(9)
  final String? buyerId;
  @HiveField(10)
  final String? buyerAddress;
  @HiveField(11)
  final String? buyerPhone;
  @HiveField(12)
  final String? buyerMukhtar;
  @HiveField(13)
  final String? buyerPhotoUrl;

  @HiveField(14)
  final String carType;
  @HiveField(15)
  final String carModelName;
  @HiveField(16)
  final String? carYear;
  @HiveField(17)
  final String? carPlate;
  @HiveField(18)
  final String? carColor;
  @HiveField(19)
  final String? carAnnualId;
  @HiveField(20)
  final String? carChassis;

  @HiveField(21)
  final double priceTotal;
  @HiveField(22)
  final double pricePaid;
  @HiveField(23)
  final double priceRemaining;

  @HiveField(24)
  final String? notes;
  @HiveField(25)
  final DateTime createdAt;

  const CarContractModel({
    required this.id,
    required this.tenantId,
    required this.sellerName,
    this.sellerId,
    this.sellerAddress,
    this.sellerPhone,
    this.sellerMukhtar,
    this.sellerPhotoUrl,
    required this.buyerName,
    this.buyerId,
    this.buyerAddress,
    this.buyerPhone,
    this.buyerMukhtar,
    this.buyerPhotoUrl,
    this.carType = 'خصوصي',
    required this.carModelName,
    this.carYear,
    this.carPlate,
    this.carColor,
    this.carAnnualId,
    this.carChassis,
    required this.priceTotal,
    required this.pricePaid,
    required this.priceRemaining,
    this.notes,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        tenantId,
        sellerName,
        sellerId,
        sellerAddress,
        sellerPhone,
        sellerMukhtar,
        sellerPhotoUrl,
        buyerName,
        buyerId,
        buyerAddress,
        buyerPhone,
        buyerMukhtar,
        buyerPhotoUrl,
        carType,
        carModelName,
        carYear,
        carPlate,
        carColor,
        carAnnualId,
        carChassis,
        priceTotal,
        pricePaid,
        priceRemaining,
        notes,
        createdAt,
      ];

  factory CarContractModel.fromJson(Map<String, dynamic> json) {
    return CarContractModel(
      id: json['id'] as String,
      tenantId: (json['tenantId'] ?? json['tenant_id']) as String,
      sellerName: (json['sellerName'] ?? json['seller_name']) as String,
      sellerId: (json['sellerId'] ?? json['seller_id']) as String?,
      sellerAddress: (json['sellerAddress'] ?? json['seller_address']) as String?,
      sellerPhone: (json['sellerPhone'] ?? json['seller_phone']) as String?,
      sellerMukhtar: (json['sellerMukhtar'] ?? json['seller_mukhtar']) as String?,
      sellerPhotoUrl: (json['sellerPhotoUrl'] ?? json['seller_photo_url']) as String?,
      buyerName: (json['buyerName'] ?? json['buyer_name']) as String,
      buyerId: (json['buyerId'] ?? json['buyer_id']) as String?,
      buyerAddress: (json['buyerAddress'] ?? json['buyer_address']) as String?,
      buyerPhone: (json['buyerPhone'] ?? json['buyer_phone']) as String?,
      buyerMukhtar: (json['buyerMukhtar'] ?? json['buyer_mukhtar']) as String?,
      buyerPhotoUrl: (json['buyerPhotoUrl'] ?? json['buyer_photo_url']) as String?,
      carType: (json['carType'] ?? json['car_type']) as String? ?? 'خصوصي',
      carModelName: (json['carModelName'] ?? json['car_model_name']) as String,
      carYear: (json['carYear'] ?? json['car_year']) as String?,
      carPlate: (json['carPlate'] ?? json['car_plate']) as String?,
      carColor: (json['carColor'] ?? json['car_color']) as String?,
      carAnnualId: (json['carAnnualId'] ?? json['car_annual_id']) as String?,
      carChassis: (json['carChassis'] ?? json['car_chassis']) as String?,
      priceTotal: ((json['priceTotal'] ?? json['price_total']) as num?)?.toDouble() ?? 0.0,
      pricePaid: ((json['pricePaid'] ?? json['price_paid']) as num?)?.toDouble() ?? 0.0,
      priceRemaining: ((json['priceRemaining'] ?? json['price_remaining']) as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'seller_name': sellerName,
      'seller_id': sellerId,
      'seller_address': sellerAddress,
      'seller_phone': sellerPhone,
      'seller_mukhtar': sellerMukhtar,
      'seller_photo_url': sellerPhotoUrl,
      'buyer_name': buyerName,
      'buyer_id': buyerId,
      'buyer_address': buyerAddress,
      'buyer_phone': buyerPhone,
      'buyer_mukhtar': buyerMukhtar,
      'buyer_photo_url': buyerPhotoUrl,
      'car_type': carType,
      'car_model_name': carModelName,
      'car_year': carYear,
      'car_plate': carPlate,
      'car_color': carColor,
      'car_annual_id': carAnnualId,
      'car_chassis': carChassis,
      'price_total': priceTotal,
      'price_paid': pricePaid,
      'price_remaining': priceRemaining,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'sellerName': sellerName,
      'sellerId': sellerId,
      'sellerAddress': sellerAddress,
      'sellerPhone': sellerPhone,
      'sellerMukhtar': sellerMukhtar,
      'sellerPhotoUrl': sellerPhotoUrl,
      'buyerName': buyerName,
      'buyerId': buyerId,
      'buyerAddress': buyerAddress,
      'buyerPhone': buyerPhone,
      'buyerMukhtar': buyerMukhtar,
      'buyerPhotoUrl': buyerPhotoUrl,
      'carType': carType,
      'carModelName': carModelName,
      'carYear': carYear,
      'carPlate': carPlate,
      'carColor': carColor,
      'carAnnualId': carAnnualId,
      'carChassis': carChassis,
      'priceTotal': priceTotal,
      'pricePaid': pricePaid,
      'priceRemaining': priceRemaining,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  static DateTime _parseDate(dynamic val) {
    if (val is DateTime) return val;
    if (val is String) return DateTime.parse(val);
    return DateTime.now();
  }

  CarContractModel copyWith({
    String? id,
    String? tenantId,
    String? sellerName,
    String? sellerId,
    String? sellerAddress,
    String? sellerPhone,
    String? sellerMukhtar,
    String? sellerPhotoUrl,
    String? buyerName,
    String? buyerId,
    String? buyerAddress,
    String? buyerPhone,
    String? buyerMukhtar,
    String? buyerPhotoUrl,
    String? carType,
    String? carModelName,
    String? carYear,
    String? carPlate,
    String? carColor,
    String? carAnnualId,
    String? carChassis,
    double? priceTotal,
    double? pricePaid,
    double? priceRemaining,
    String? notes,
    DateTime? createdAt,
  }) {
    return CarContractModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      sellerName: sellerName ?? this.sellerName,
      sellerId: sellerId ?? this.sellerId,
      sellerAddress: sellerAddress ?? this.sellerAddress,
      sellerPhone: sellerPhone ?? this.sellerPhone,
      sellerMukhtar: sellerMukhtar ?? this.sellerMukhtar,
      sellerPhotoUrl: sellerPhotoUrl ?? this.sellerPhotoUrl,
      buyerName: buyerName ?? this.buyerName,
      buyerId: buyerId ?? this.buyerId,
      buyerAddress: buyerAddress ?? this.buyerAddress,
      buyerPhone: buyerPhone ?? this.buyerPhone,
      buyerMukhtar: buyerMukhtar ?? this.buyerMukhtar,
      buyerPhotoUrl: buyerPhotoUrl ?? this.buyerPhotoUrl,
      carType: carType ?? this.carType,
      carModelName: carModelName ?? this.carModelName,
      carYear: carYear ?? this.carYear,
      carPlate: carPlate ?? this.carPlate,
      carColor: carColor ?? this.carColor,
      carAnnualId: carAnnualId ?? this.carAnnualId,
      carChassis: carChassis ?? this.carChassis,
      priceTotal: priceTotal ?? this.priceTotal,
      pricePaid: pricePaid ?? this.pricePaid,
      priceRemaining: priceRemaining ?? this.priceRemaining,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
