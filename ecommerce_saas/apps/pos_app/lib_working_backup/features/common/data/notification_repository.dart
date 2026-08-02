import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';

enum NotificationType { info, warning, error, success }
enum NotificationCategory { stock, expiry, sales, system }

class NotificationModel {
  final String id;
  final String tenantId;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationCategory category;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedId; // e.g. productId

  NotificationModel({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.message,
    required this.type,
    required this.category,
    required this.createdAt,
    this.isRead = false,
    this.relatedId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'title': title,
      'message': message,
      'type': type.name,
      'category': category.name,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'relatedId': relatedId,
    };
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: NotificationType.values.firstWhere((e) => e.name == json['type'], orElse: () => NotificationType.info),
      category: NotificationCategory.values.firstWhere((e) => e.name == json['category'], orElse: () => NotificationCategory.system),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool? ?? false,
      relatedId: json['relatedId'] as String?,
    );
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      tenantId: tenantId,
      title: title,
      message: message,
      type: type,
      category: category,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      relatedId: relatedId,
    );
  }
}

class NotificationRepository {
  final FirestoreRestService _restService;
  NotificationRepository(this._restService);

  Future<List<NotificationModel>> getNotifications(String tenantId) async {
    final query = {
      'where': {
        'fieldFilter': {
          'field': {'fieldPath': 'tenantId'},
          'op': 'EQUAL',
          'value': {'stringValue': tenantId}
        }
      },
      'limit': 50,
    };

    final results = await _restService.runQuery('notifications', query);
    final list = results.map((data) => NotificationModel.fromJson(data)).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> addNotification(NotificationModel notification) async {
    await _restService.setDocument('notifications/${notification.id}', notification.toJson());
  }

  Future<void> markAsRead(String notificationId) async {
    await _restService.setDocument('notifications/$notificationId', {'isRead': true}, isUpdate: true);
  }

  Future<void> clearAll(String tenantId) async {
    final notifications = await getNotifications(tenantId);
    for (var n in notifications) {
      await _restService.deleteDocument('notifications/${n.id}');
    }
  }
}

final notificationRepositoryProvider = Provider((ref) => NotificationRepository(ref.watch(firestoreRestServiceProvider)));

final notificationsFutureProvider = FutureProvider.family<List<NotificationModel>, String>((ref, tenantId) {
  return ref.watch(notificationRepositoryProvider).getNotifications(tenantId);
});
