import 'package:equatable/equatable.dart';
import 'package:hive_ce/hive.dart';

part 'attendance_model.g.dart';

@HiveType(typeId: 35)
class AttendanceModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String staffId;
  @HiveField(2)
  final String staffName;
  @HiveField(3)
  final String tenantId;
  @HiveField(4)
  final DateTime checkIn;
  @HiveField(5)
  final DateTime? checkOut;
  @HiveField(6)
  final String? note;

  const AttendanceModel({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.tenantId,
    required this.checkIn,
    this.checkOut,
    this.note,
  });

  @override
  List<Object?> get props => [id, staffId, staffName, tenantId, checkIn, checkOut, note];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'staffName': staffName,
      'tenantId': tenantId,
      'checkIn': checkIn.toIso8601String(),
      'checkOut': checkOut?.toIso8601String(),
      'note': note,
    };
  }

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    return AttendanceModel(
      id: json['id'] as String? ?? '',
      staffId: json['staffId'] as String? ?? '',
      staffName: json['staffName'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      checkIn: json['checkIn'] != null 
          ? DateTime.parse(json['checkIn'] as String) 
          : DateTime.now(),
      checkOut: json['checkOut'] != null 
          ? DateTime.parse(json['checkOut'] as String) 
          : null,
      note: json['note'] as String?,
    );
  }

  AttendanceModel copyWith({
    String? id,
    String? staffId,
    String? staffName,
    String? tenantId,
    DateTime? checkIn,
    DateTime? checkOut,
    String? note,
  }) {
    return AttendanceModel(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      tenantId: tenantId ?? this.tenantId,
      checkIn: checkIn ?? this.checkIn,
      checkOut: checkOut ?? this.checkOut,
      note: note ?? this.note,
    );
  }
}
