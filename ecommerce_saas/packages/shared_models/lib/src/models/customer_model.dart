import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'customer_model.g.dart';

@HiveType(typeId: 27)
class CustomerModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String name;
  @HiveField(3)
  final String phoneNumber;
  @HiveField(4)
  final double balance; // Positive means they owe us, negative means we owe them (rarely)
  @HiveField(5)
  final DateTime createdAt;
  @HiveField(6)
  final String? address;
  @HiveField(7)
  final int loyaltyPoints;

  const CustomerModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.phoneNumber,
    this.balance = 0.0,
    required this.createdAt,
    this.address,
    this.loyaltyPoints = 0,
  });

  @override
  List<Object?> get props => [id, tenantId, name, phoneNumber, balance, createdAt, address, loyaltyPoints];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'name': name,
      'phoneNumber': phoneNumber,
      'balance': balance,
      'createdAt': createdAt.toIso8601String(),
      'address': address,
      'loyaltyPoints': loyaltyPoints,
    };
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      balance: (json['balance'] as num? ?? 0.0).toDouble(),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : DateTime.now(),
      address: json['address'] as String?,
      loyaltyPoints: json['loyaltyPoints'] as int? ?? 0,
    );
  }

  CustomerModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? phoneNumber,
    double? balance,
    DateTime? createdAt,
    String? address,
    int? loyaltyPoints,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      address: address ?? this.address,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
    );
  }
}
