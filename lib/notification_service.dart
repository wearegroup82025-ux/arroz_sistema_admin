import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// 🔴 TOP-LEVEL BACKGROUND HANDLER
// Tumatakbo ito sa background o kapag patay/terminated ang app.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Background Notification Received: ${message.messageId}");
}

class NotificationService {
  // ===========================================================================
  // 🔘 TOGGLE SWITCH (TRUE / FALSE)
  // Gawing 'true' para sa active notifications, o 'false' kung ayaw mong gumana.
  // ===========================================================================
  static bool enableNotifications = true;

  // Singleton Instance
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();

  // ===========================================================================
  // 🟢 STATIC WRAPPERS (Para sa dashboard_page.dart at main.dart compatibility)
  // ===========================================================================
  
  /// Tinatawag ng main.dart
  static Future<void> initNotification() async {
    if (!enableNotifications) return;
    await NotificationService().initialize();
  }

  /// Tinatawag ng dashboard_page.dart
  /// May optional 'id' parameter na ngayon para HINDI MAG-ERROR kahit mag-pasa ng 'id' ang dashboard.
  static Future<void> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!enableNotifications) return;

    final int targetId = id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);

    await NotificationService().displayLocalNotification(
      id: targetId,
      title: title,
      body: body,
      payload: payload,
    );
  }

  // ===========================================================================
  // ⚙️ CORE NOTIFICATION LOGIC
  // ===========================================================================

  Future<void> initialize() async {
    // 1. Notification Permission Request
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('User denied notification permissions');
      return;
    }

    // 2. Set Background Messaging Handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Local Notifications Config
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(),
    );

    await _localNotifs.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationClick(details.payload);
      },
    );

    // Android High Importance Channel Setup
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'Used for important notifications and alerts.',
      importance: Importance.high,
    );

    await _localNotifs
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 4. Listen sa Foreground Messages (kapag bukas ang app)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (!enableNotifications) return;

      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        displayLocalNotification(
          id: notification.hashCode,
          title: notification.title ?? '',
          body: notification.body ?? '',
          payload: message.data['type'],
        );
      }
    });

    // 5. Save FCM Token sa Database
    await saveDeviceToken();
  }

  Future<void> saveDeviceToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? token = await _fcm.getToken();
    if (token != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': token,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    _fcm.onTokenRefresh.listen((newToken) async {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': newToken,
      }, SetOptions(merge: true));
    });
  }

  Future<void> displayLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifs.show(id, title, body, platformDetails, payload: payload);
  }

  void _handleNotificationClick(String? payload) {
    if (payload == null) return;
    debugPrint("Notification clicked with payload: $payload");
  }
}