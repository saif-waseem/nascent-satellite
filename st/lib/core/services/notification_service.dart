import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:store_admin/core/utils/onesignal_config.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  // Use Object? for native-only plugin types to avoid instantiation crashes on Web
  // final Object? _localNotifications = kIsWeb ? null : FlutterLocalNotificationsPlugin();
  final Object? _localNotifications = null;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Callback for handling notification clicks (deep linking)
  Function(String orderId)? onNotificationClick;

  Future<void> initialize(String tenantId) async {
    if (kIsWeb) {
      debugPrint('NotificationService: Skipping OneSignal/FCM init on Web for now.');
      return;
    }
    // 0. Initialize OneSignal
    // OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(OneSignalConfig.appId);
    OneSignal.Notifications.requestPermission(true);
    OneSignal.User.addTagWithKey("tenantId", tenantId);

    // Handle OneSignal Notification Click
    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      if (data != null) {
        final orderId = data['orderId'] as String?;
        if (orderId != null) {
          _handleNotificationClick(orderId);
        }
      }
    });

    // 1. Request permissions (FCM)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // 2. Get token and save to Firestore
      String? token = await _fcm.getToken();
      if (token != null) {
        await _saveToken(tenantId, token);
      }
      
      if (!kIsWeb) {
        // 3. Setup Local Notifications (Native only for now)
        // const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
        // const InitializationSettings initSettings = InitializationSettings(android: androidSettings);
        // final plugin = _localNotifications as FlutterLocalNotificationsPlugin;
        // await plugin.initialize(
        //   settings: initSettings,
        //   onDidReceiveNotificationResponse: (NotificationResponse response) {
        //     // Handle notification click for deep linking
        //     final orderId = response.payload;
        //     if (orderId != null && orderId.isNotEmpty) {
        //       _handleNotificationClick(orderId);
        //     }
        //   },
        // );
      }

      // 4. Handle Foreground Messages (Real FCM)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (!kIsWeb) _showLocalNotification(message);
      });

      // 5. Setup Background Interaction
      await setupInteractedMessage();

      // 6. Setup Firestore Watcher (Simulated Push) - Disabled to avoid duplicates with OneSignal
      // _startFirestoreListener(tenantId);
    }
  }

  Future<void> setupInteractedMessage() async {
    // Get any messages which caused the application to open from a terminated state.
    RemoteMessage? initialMessage = await _fcm.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    // Also handle any interaction when the app is in the background via a Stream listener
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
     final orderId = message.data['orderId'] as String?;
     if (orderId != null) {
       _handleNotificationClick(orderId);
     }
  }


  Future<void> _saveToken(String tenantId, String token) async {
    await _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('adminTokens')
        .doc(token)
        .set({
      'token': token,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  void _showLocalNotification(dynamic message) {
    if (kIsWeb) return;
    
    // const androidDetails = AndroidNotificationDetails(
    //   'orders_channel',
    //   'New Orders',
    //   importance: Importance.max,
    //   priority: Priority.high,
    // );
    // const details = NotificationDetails(android: androidDetails);

    // (_localNotifications as FlutterLocalNotificationsPlugin).show(
    //   id: message.hashCode,
    //   title: 'New Order',
    //   body: 'A new order has been placed!',
    //   notificationDetails: details,
    // );
  }

  // --- OneSignal Sending (REST API) ---
  Future<bool> sendOneSignalNotification({
    required String tenantId,
    required String title,
    required String body,
    String? productId,
    String? actionUrl,
    String? storeName,
    String? logoUrl,
    String? appId,
    String? restApiKey,
  }) async {
    final finalAppId = appId ?? OneSignalConfig.appId;
    final finalRestKey = restApiKey ?? OneSignalConfig.restApiKey;

    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $finalRestKey',
        },
        body: jsonEncode({
          'app_id': finalAppId,
          'headings': {'en': storeName ?? title, 'ar': storeName ?? title},
          'contents': {'en': body, 'ar': body},
          'chrome_web_icon': logoUrl,
          'large_icon': logoUrl,
          'small_icon': 'ic_stat_onesignal_default',
          // Filter by Tag to target ONLY this tenant's users
          'filters': [
            {'field': 'tag', 'key': 'tenantId', 'relation': '=', 'value': tenantId}
          ],
          'data': {
            'type': 'advertisement',
            'productId': productId,
            'actionUrl': actionUrl,
            'tenantId': tenantId,
            'storeName': storeName,
            'logoUrl': logoUrl,
          },
        }),
      );

      debugPrint('OneSignal Response Status: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 400; 
    } catch (e) {
      debugPrint('OneSignal Send Error: $e');
      return false;
    }
  }

  Future<bool> sendOneSignalNotificationToUser({
    required String tenantId,
    required String userId,
    required String title,
    required String body,
    String? orderId,
    String? storeName,
    String? logoUrl,
    String? appId,
    String? restApiKey,
  }) async {
    final finalAppId = appId ?? OneSignalConfig.appId;
    final finalRestKey = restApiKey ?? OneSignalConfig.restApiKey;

    try {
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $finalRestKey',
        },
        body: jsonEncode({
          'app_id': finalAppId,
          'headings': {'en': storeName ?? title, 'ar': storeName ?? title},
          'contents': {'en': body, 'ar': body},
          'chrome_web_icon': logoUrl,
          'large_icon': logoUrl,
          'small_icon': 'ic_stat_onesignal_default',
          'filters': [
            {'field': 'tag', 'key': 'tenantId', 'relation': '=', 'value': tenantId},
            {'operator': 'AND'},
            {'field': 'tag', 'key': 'userId', 'relation': '=', 'value': userId},
          ],
          'data': {
            'orderId': orderId,
            'tenantId': tenantId,
            'storeName': storeName,
            'logoUrl': logoUrl,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK', 
          },
        }),
      );

      debugPrint('OneSignal User Response Status: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 400; 
    } catch (e) {
      debugPrint('OneSignal User Send Error: $e');
      return false;
    }
  }

  // Handle notification click for deep linking
  void _handleNotificationClick(String orderId) {
    if (onNotificationClick != null) {
      onNotificationClick!(orderId);
    }
  }
}
