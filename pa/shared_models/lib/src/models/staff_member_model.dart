import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'staff_member_model.g.dart';

@HiveType(typeId: 30)
// StaffRole enum is removed in favor of dynamic role names (String)

@HiveType(typeId: 31)
class StaffMemberModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String name;
  @HiveField(3)
  final String roleName;
  @HiveField(4)
  final String? pinCode;
  @HiveField(5)
  final String? email;
  @HiveField(6)
  final bool isActive;
  @HiveField(7)
  final DateTime createdAt;
  @HiveField(8)
  final double salaryAmount;
  @HiveField(9)
  final int salaryCycleDays;
  @HiveField(10)
  final int requiredDaysForSalary;
  @HiveField(11)
  final DateTime? lastSalaryPaidDate;
  @HiveField(12)
  final int dailyShiftCount;

  const StaffMemberModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.roleName,
    this.pinCode,
    this.email,
    this.isActive = true,
    required this.createdAt,
    this.salaryAmount = 0.0,
    this.salaryCycleDays = 30,
    this.requiredDaysForSalary = 20,
    this.lastSalaryPaidDate,
    this.dailyShiftCount = 1,
  });

  @override
  List<Object?> get props => [
        id,
        tenantId,
        name,
        roleName,
        pinCode,
        email,
        isActive,
        createdAt,
        salaryAmount,
        salaryCycleDays,
        requiredDaysForSalary,
        lastSalaryPaidDate,
        dailyShiftCount,
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'name': name,
      'roleName': roleName,
      'pinCode': pinCode,
      'email': email,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'salaryAmount': salaryAmount,
      'salaryCycleDays': salaryCycleDays,
      'requiredDaysForSalary': requiredDaysForSalary,
      'lastSalaryPaidDate': lastSalaryPaidDate?.toIso8601String(),
      'dailyShiftCount': dailyShiftCount,
    };
  }

  factory StaffMemberModel.fromJson(Map<String, dynamic> json) {
    return StaffMemberModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      roleName: json['roleName'] as String? ?? json['role'] as String? ?? 'cashier',
      pinCode: json['pinCode'] as String?,
      email: json['email'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : DateTime.now(),
      salaryAmount: (json['salaryAmount'] as num? ?? 0.0).toDouble(),
      salaryCycleDays: json['salaryCycleDays'] as int? ?? 30,
      requiredDaysForSalary: json['requiredDaysForSalary'] as int? ?? 20,
      lastSalaryPaidDate: json['lastSalaryPaidDate'] != null ? DateTime.parse(json['lastSalaryPaidDate'] as String) : null,
      dailyShiftCount: json['dailyShiftCount'] as int? ?? 1,
    );
  }

  StaffMemberModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? roleName,
    String? pinCode,
    String? email,
    bool? isActive,
    DateTime? createdAt,
    double? salaryAmount,
    int? salaryCycleDays,
    int? requiredDaysForSalary,
    DateTime? lastSalaryPaidDate,
    int? dailyShiftCount,
  }) {
    return StaffMemberModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      roleName: roleName ?? this.roleName,
      pinCode: pinCode ?? this.pinCode,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      salaryAmount: salaryAmount ?? this.salaryAmount,
      salaryCycleDays: salaryCycleDays ?? this.salaryCycleDays,
      requiredDaysForSalary: requiredDaysForSalary ?? this.requiredDaysForSalary,
      lastSalaryPaidDate: lastSalaryPaidDate ?? this.lastSalaryPaidDate,
      dailyShiftCount: dailyShiftCount ?? this.dailyShiftCount,
    );
  }
}
