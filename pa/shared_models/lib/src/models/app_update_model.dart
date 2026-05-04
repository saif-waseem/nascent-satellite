import 'package:equatable/equatable.dart';

class AppUpdateModel extends Equatable {
  final String id; // e.g. 'user_app_android' or 'store_admin_ios' or 'com.landan.app_android'
  final String title; // NEW: Display name for the update entry
  final int versionCode;
  final String versionName;
  final String downloadUrl;
  final String releaseNotes;
  final bool isMandatory; // Now used for showing update notification (not blocking)
  final bool isAppDisabled; // NEW: Manual control to disable app from Super Admin
  final DateTime updatedAt;

  const AppUpdateModel({
    required this.id,
    this.title = '', // Default to empty string
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    required this.releaseNotes,
    this.isMandatory = false, // Changed default to false
    this.isAppDisabled = false, // New field, defaults to false (app enabled)
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, title, versionCode, versionName, downloadUrl, releaseNotes, isMandatory, isAppDisabled, updatedAt];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'versionCode': versionCode,
      'versionName': versionName,
      'downloadUrl': downloadUrl,
      'releaseNotes': releaseNotes,
      'isMandatory': isMandatory,
      'isAppDisabled': isAppDisabled,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppUpdateModel.fromJson(Map<String, dynamic> json) {
    return AppUpdateModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      versionName: json['versionName'] as String? ?? '1.0.0',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      releaseNotes: json['releaseNotes'] as String? ?? '',
      isMandatory: json['isMandatory'] as bool? ?? false,
      isAppDisabled: json['isAppDisabled'] as bool? ?? false,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : DateTime.now(),
    );
  }
}
