import 'package:json_annotation/json_annotation.dart';

part 'shift_session_model.g.dart';

@JsonSerializable()
class ShiftSessionModel {
  final String id;
  final String tenantId;
  final String staffId;
  final String staffName;
  final DateTime startTime;
  final DateTime? endTime;
  final double openingBalance;
  final double? closingBalanceActual; // What the staff entered
  final double? closingBalanceExpected; // What the system calculated
  final String status; // 'open', 'closed'
  final Map<String, double> salesSummary; // e.g., {'cash': 500.0, 'credit': 200.0}

  ShiftSessionModel({
    required this.id,
    required this.tenantId,
    required this.staffId,
    required this.staffName,
    required this.startTime,
    this.endTime,
    required this.openingBalance,
    this.closingBalanceActual,
    this.closingBalanceExpected,
    this.status = 'open',
    this.salesSummary = const {},
  });

  factory ShiftSessionModel.fromJson(Map<String, dynamic> json) => _$ShiftSessionModelFromJson(json);
  Map<String, dynamic> toJson() => _$ShiftSessionModelToJson(this);

  ShiftSessionModel copyWith({
    String? id,
    String? tenantId,
    String? staffId,
    String? staffName,
    DateTime? startTime,
    DateTime? endTime,
    double? openingBalance,
    double? closingBalanceActual,
    double? closingBalanceExpected,
    String? status,
    Map<String, double>? salesSummary,
  }) {
    return ShiftSessionModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      openingBalance: openingBalance ?? this.openingBalance,
      closingBalanceActual: closingBalanceActual ?? this.closingBalanceActual,
      closingBalanceExpected: closingBalanceExpected ?? this.closingBalanceExpected,
      status: status ?? this.status,
      salesSummary: salesSummary ?? this.salesSummary,
    );
  }
}
