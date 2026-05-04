// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shift_session_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ShiftSessionModel _$ShiftSessionModelFromJson(Map<String, dynamic> json) =>
    ShiftSessionModel(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      staffId: json['staffId'] as String,
      staffName: json['staffName'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      openingBalance: (json['openingBalance'] as num).toDouble(),
      closingBalanceActual: (json['closingBalanceActual'] as num?)?.toDouble(),
      closingBalanceExpected:
          (json['closingBalanceExpected'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'open',
      salesSummary: (json['salesSummary'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toDouble()),
          ) ??
          const {},
    );

Map<String, dynamic> _$ShiftSessionModelToJson(ShiftSessionModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'staffId': instance.staffId,
      'staffName': instance.staffName,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
      'openingBalance': instance.openingBalance,
      'closingBalanceActual': instance.closingBalanceActual,
      'closingBalanceExpected': instance.closingBalanceExpected,
      'status': instance.status,
      'salesSummary': instance.salesSummary,
    };
