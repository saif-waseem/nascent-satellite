import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:user_app/core/config/onesignal_config.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:user_app/features/shared/providers.dart';
import 'package:user_app/core/router/app_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:shared_models/shared_models.dart';
import 'package:user_app/core/utils/formatters.dart';

final notificationServiceProvider = Provider((ref) => UserNotificationService(ref));

class UserNotificationService {
  final Ref ref;
  UserNotificationService(this.ref);

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint('NotificationService: Skipping OneSignal/FCM init on Web for now.');
      return;
    }
    // 1. Initialize Firebase Messaging (Legacy/Complementary)
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    final token = await messaging.getToken();
    if (token != null) _saveToken(token);
    messaging.onTokenRefresh.listen(_saveToken);

    // 2. Initialize OneSignal
    await _initOneSignal();
  }

  Future<void> _initOneSignal() async {
    if (kIsWeb) return;
    
    // OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    // OneSignal.initialize(OneSignalConfig.appId);

    // Request permission
    // OneSignal.Notifications.requestPermission(true);

    // Set Tenant Tag when resolved
    ref.listen(resolvedTenantIdProvider, (previous, next) {
      next.whenData((tenantId) {
        if (tenantId.isNotEmpty) {
          // OneSignal.User.addTagWithKey("tenantId", tenantId);
          debugPrint("OneSignal: User tagged with tenantId: $tenantId");
        }
      });
    }, fireImmediately: true);

    // Set User ID when logged in
    ref.listen(userProvider, (previous, next) {
      next.whenData((user) {
        if (user != null) {
          // OneSignal.login(user.id);
          // OneSignal.User.addTagWithKey("userId", user.id);
        } else {
          // OneSignal.logout();
        }
      });
    });

    // Handle notification clicks for deep linking
    /* OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data != null) {
        final productId = data['productId'] as String?;
        final actionUrl = data['actionUrl'] as String?;
        
        if (productId != null) {
          // Navigate to product details
          _navigateToProduct(productId);
        } else if (actionUrl != null && actionUrl.isNotEmpty) {
          // Open external URL
          _openUrl(actionUrl);
        }
      }
    }); */
  }

  void _navigateToProduct(String productId) async {
    // Wait a bit for the app to be ready
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Use the global navigator key to navigate via ID-based route
    final router = ref.read(appRouterProvider);
    final context = router.routerDelegate.navigatorKey.currentContext;
    if (context != null) {
      context.push('/product/$productId');
    }
  }

  void _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Failed to open URL
    }
  }


  Future<void> _saveToken(String token) async {
    final phone = ref.read(userPhoneProvider);
    if (phone != null) {
      await FirebaseFirestore.instance.collection('users').doc(phone).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    }
  }

  void startListening(BuildContext context) async {
    final tenantId = await ref.read(resolvedTenantIdProvider.future);

    // Use a timestamp slightly in the past to avoid missing notifications due to clock skew
    final sinceTime = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(seconds: 30)),
    );

    // Legacy Firestore-based listener for marketing notices
    FirebaseFirestore.instance
        .collection('marketing_notifications')
        .where('tenantId', isEqualTo: tenantId) // Isolation filter
        .where('timestamp', isGreaterThan: sinceTime)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            _showNotificationDialog(
              context, 
              data['title'] ?? 'Notice', 
              data['body'] ?? '',
              productId: data['productId'] as String?,
              actionUrl: data['actionUrl'] as String?,
            );
          }
        }
      }
    });

    // Also listen for foreground OneSignal notifications and display in-app popup
    // Also listen for foreground OneSignal notifications and display in-app popup
    /* if (!kIsWeb) {
      OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        ...
      });
    } */
  }

  Future<bool> sendAdminNotification({
    required String tenantId,
    required String title,
    required String body,
    String? orderId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          // TODO: Move to backend for security
          'Authorization': 'Basic ${OneSignalConfig.restApiKey}',
        },
        body: jsonEncode({
          'app_id': OneSignalConfig.appId,
          'headings': {'en': title, 'ar': title},
          'contents': {'en': body, 'ar': body},
          'small_icon': 'ic_stat_onesignal_default',
          // Filter by Tag to target ONLY the admin(s) of this tenant
          'filters': [
            {'field': 'tag', 'key': 'tenantId', 'relation': '=', 'value': tenantId}
          ],
          'data': {
            'orderId': orderId,
            'tenantId': tenantId,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
        }),
      );

      return response.statusCode == 200 || response.statusCode == 400; 
    } catch (e) {
      debugPrint('OneSignal Admin Send Error: $e');
      return false;
    }
  }

  void _showNotificationDialog(
    BuildContext context, 
    String title, 
    String body, {
    String? productId,
    String? actionUrl,
  }) {
    // Try to find product details if productId is provided
    ProductModel? product;
    if (productId != null) {
      final products = ref.read(productsProvider).value;
      if (products != null) {
        try {
          product = products.firstWhere((p) => p.id == productId);
        } catch (_) {}
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.blue),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(body),
              if (product != null) ...[
                Builder(
                  builder: (context) {
                    final p = product!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Builder(
                                builder: (context) {
                                  final img = p.imageUrl;
                                  if (img != null && img.isNotEmpty) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: Image.network(
                                        img,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      formatCurrency(p.price),
                                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق / Close'),
          ),
          if (productId != null || actionUrl != null)
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                if (productId != null) {
                  // Navigate via ID-based route for reliability
                  context.push('/product/$productId');
                } else if (actionUrl != null) {
                  final url = Uri.parse(actionUrl);
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (_) {}
                }
              },
              child: const Text('عرض الآن / View Now'),
            ),
        ],
      ),
    );
  }
}
