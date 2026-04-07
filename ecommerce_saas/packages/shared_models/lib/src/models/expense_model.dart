import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'expense_model.g.dart';

@HiveType(typeId: 28)
class ExpenseModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String category;
  @HiveField(3)
  final double amount;
  @HiveField(4)
  final String description;
  @HiveField(5)
  final DateTime date;
  @HiveField(6)
  final String? recordedBy;

  const ExpenseModel({
    required this.id,
    required this.tenantId,
    required this.category,
    required this.amount,
    this.description = '',
    required this.date,
    this.recordedBy,
  });

  @override
  List<Object?> get props => [id, tenantId, category, amount, description, date, recordedBy];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'category': category,
      'amount': amount,
      'description': description,
      'date': date.toIso8601String(),
      'recordedBy': recordedBy,
    };
  }

  static DateTime _parseDate(dynamic val) {
    if (val is DateTime) return val;
    if (val is String) return DateTime.parse(val);
    if (val is Timestamp) return val.toDate();
    return DateTime.now();
  }

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      category: json['category'] as String? ?? '',
      amount: (json['amount'] as num? ?? 0.0).toDouble(),
      description: json['description'] as String? ?? '',
      date: _parseDate(json['date']),
      recordedBy: json['recordedBy'] as String?,
    );
  }

  ExpenseModel copyWith({
    String? id,
    String? tenantId,
    String? category,
    double? amount,
    String? description,
    DateTime? date,
    String? recordedBy,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      recordedBy: recordedBy ?? this.recordedBy,
    );
  }
}
