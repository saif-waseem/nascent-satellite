// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audit_log_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AuditLogModel _$AuditLogModelFromJson(Map<String, dynamic> json) =>
    AuditLogModel(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      staffId: json['staffId'] as String,
      staffName: json['staffName'] as String,
      action: json['action'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$AuditLogModelToJson(AuditLogModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'staffId': instance.staffId,
      'staffName': instance.staffName,
      'action': instance.action,
      'description': instance.description,
      'timestamp': instance.timestamp.toIso8601String(),
      'metadata': instance.metadata,
    };
