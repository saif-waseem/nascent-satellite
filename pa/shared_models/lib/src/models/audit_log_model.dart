import 'package:json_annotation/json_annotation.dart';

part 'audit_log_model.g.dart';

@JsonSerializable()
class AuditLogModel {
  final String id;
  final String tenantId;
  final String staffId;
  final String staffName;
  final String action; // e.g., 'delete_item', 'apply_discount', 'void_invoice'
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic> metadata; // e.g., {'invoiceId': '...', 'itemId': '...', 'amount': 10.0}

  AuditLogModel({
    required this.id,
    required this.tenantId,
    required this.staffId,
    required this.staffName,
    required this.action,
    required this.description,
    required this.timestamp,
    this.metadata = const {},
  });

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      staffId: json['staffId'] as String? ?? '',
      staffName: json['staffName'] as String? ?? 'System',
      action: json['action'] as String? ?? '',
      description: json['description'] as String? ?? '',
      timestamp: _parseDate(json['timestamp']),
      metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
    );
  }

  Map<String, dynamic> toJson() => _$AuditLogModelToJson(this);

  static DateTime _parseDate(dynamic val) {
    if (val is DateTime) return val;
    if (val is String) return DateTime.parse(val);
    try {
      // Handle Firebase Timestamp
      return (val as dynamic).toDate();
    } catch (_) {
      return DateTime.now();
    }
  }
}
