import 'package:equatable/equatable.dart';

enum DiscountType { percentage, fixed }

class CouponModel extends Equatable {
  final String id;
  final String code;
  final DiscountType type;
  final double value;
  final double minPurchase;
  final int maxUsage;
  final int usageCount;
  final bool isActive;
  final DateTime? expiryDate;

  const CouponModel({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    this.minPurchase = 0.0,
    this.maxUsage = 999,
    this.usageCount = 0,
    this.isActive = true,
    this.expiryDate,
  });

  @override
  List<Object?> get props => [id, code, type, value, minPurchase, maxUsage, usageCount, isActive, expiryDate];

  CouponModel copyWith({
    String? id,
    String? code,
    DiscountType? type,
    double? value,
    double? minPurchase,
    int? maxUsage,
    int? usageCount,
    bool? isActive,
    DateTime? expiryDate,
  }) {
    return CouponModel(
      id: id ?? this.id,
      code: code ?? this.code,
      type: type ?? this.type,
      value: value ?? this.value,
      minPurchase: minPurchase ?? this.minPurchase,
      maxUsage: maxUsage ?? this.maxUsage,
      usageCount: usageCount ?? this.usageCount,
      isActive: isActive ?? this.isActive,
      expiryDate: expiryDate ?? this.expiryDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'type': type.name,
      'value': value,
      'minPurchase': minPurchase,
      'maxUsage': maxUsage,
      'usageCount': usageCount,
      'isActive': isActive,
      'expiryDate': expiryDate?.toIso8601String(),
    };
  }

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as String,
      code: json['code'] as String,
      type: DiscountType.values.byName(json['type'] as String),
      value: (json['value'] as num).toDouble(),
      minPurchase: (json['minPurchase'] as num? ?? 0.0).toDouble(),
      maxUsage: json['maxUsage'] as int? ?? 999,
      usageCount: json['usageCount'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      expiryDate: json['expiryDate'] != null ? DateTime.parse(json['expiryDate'] as String) : null,
    );
  }
}
