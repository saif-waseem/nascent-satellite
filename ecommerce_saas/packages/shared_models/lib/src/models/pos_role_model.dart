import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'pos_role_model.g.dart';

@HiveType(typeId: 32)
class PosRoleModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String name;
  @HiveField(3)
  final List<String> permissions; // Storing as list of strings (PosPermission names)

  const PosRoleModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.permissions,
  });

  @override
  List<Object?> get props => [id, tenantId, name, permissions];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'name': name,
      'permissions': permissions,
    };
  }

  factory PosRoleModel.fromJson(Map<String, dynamic> json) {
    return PosRoleModel(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      name: json['name'] as String,
      permissions: (json['permissions'] as List?)?.cast<String>() ?? [],
    );
  }

  PosRoleModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    List<String>? permissions,
  }) {
    return PosRoleModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      permissions: permissions ?? this.permissions,
    );
  }
}
