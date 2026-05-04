import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'supplier_model.g.dart';

@HiveType(typeId: 20) // Choosing 20 for Suppliers
class SupplierModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String name;
  @HiveField(3)
  final String phoneNumber;
  @HiveField(4)
  final double balance; // Positive means we owe them, negative means they owe us
  @HiveField(5)
  final DateTime createdAt;

  const SupplierModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.phoneNumber,
    this.balance = 0.0,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, tenantId, name, phoneNumber, balance, createdAt];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'name': name,
      'phoneNumber': phoneNumber,
      'balance': balance,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SupplierModel.fromJson(Map<String, dynamic> json) {
    return SupplierModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      balance: (json['balance'] as num? ?? 0.0).toDouble(),
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String) 
          : DateTime.now(),
    );
  }

  SupplierModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? phoneNumber,
    double? balance,
    DateTime? createdAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
