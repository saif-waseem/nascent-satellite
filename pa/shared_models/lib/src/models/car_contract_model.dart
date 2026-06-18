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
      tenantId: json['tenantId'] as String,
      sellerName: json['sellerName'] as String,
      sellerId: json['sellerId'] as String?,
      sellerAddress: json['sellerAddress'] as String?,
      sellerPhone: json['sellerPhone'] as String?,
      sellerMukhtar: json['sellerMukhtar'] as String?,
      sellerPhotoUrl: json['sellerPhotoUrl'] as String?,
      buyerName: json['buyerName'] as String,
      buyerId: json['buyerId'] as String?,
      buyerAddress: json['buyerAddress'] as String?,
      buyerPhone: json['buyerPhone'] as String?,
      buyerMukhtar: json['buyerMukhtar'] as String?,
      buyerPhotoUrl: json['buyerPhotoUrl'] as String?,
      carType: json['carType'] as String? ?? 'خصوصي',
      carModelName: json['carModelName'] as String,
      carYear: json['carYear'] as String?,
      carPlate: json['carPlate'] as String?,
      carColor: json['carColor'] as String?,
      carAnnualId: json['carAnnualId'] as String?,
      carChassis: json['carChassis'] as String?,
      priceTotal: (json['priceTotal'] as num?)?.toDouble() ?? 0.0,
      pricePaid: (json['pricePaid'] as num?)?.toDouble() ?? 0.0,
      priceRemaining: (json['priceRemaining'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      createdAt: _parseDate(json['createdAt']),
    );
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
