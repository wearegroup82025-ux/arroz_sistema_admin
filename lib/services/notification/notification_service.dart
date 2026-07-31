import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Background Notification: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifs = FlutterLocalNotificationsPlugin();

  static const String channelAlerts = 'stock_alerts_channel';
  static const String channelOrders = 'orders_channel';
  static const String channelUsers = 'users_channel';
  static const String channelWeather = 'weather_channel';
  static const String channelTyphoonSOS = 'typhoon_sos_channel';

  static Future<void> initNotification() async {
    await NotificationService().initialize();
  }

  Future<void> initialize() async {
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: DarwinInitializationSettings(
        requestCriticalPermission: true,
        requestSoundPermission: true,
      ),
    );

    await _localNotifs.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationClick(details.payload);
      },
    );

    await _createChannel(channelAlerts, 'Inventory Alerts', 'Stock warnings', Importance.high);
    await _createChannel(channelOrders, 'Orders & Cancellations', 'Realtime client orders', Importance.high);
    await _createChannel(channelUsers, 'New User Registrations', 'New user accounts created', Importance.defaultImportance);
    await _createChannel(channelWeather, 'Weather Updates', 'Daily forecast alerts', Importance.defaultImportance);

    // 🚨 Emergency Siren Channel
    const AndroidNotificationChannel sosChannel = AndroidNotificationChannel(
      channelTyphoonSOS,
      '🚨 EMERGENCY TYPHOON ALERTS',
      description: 'Critical disaster warnings with continuous siren sound',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      sound: RawResourceAndroidNotificationSound('typhoon_siren'),
    );

    await _localNotifs
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(sosChannel);
  }

  Future<void> _createChannel(String id, String name, String desc, Importance importance) async {
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      id,
      name,
      description: desc,
      importance: importance,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifs
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
    String channelId = channelAlerts,
    bool isOngoing = false,
  }) async {
    final int targetId = id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final bool isSOS = channelId == channelTyphoonSOS;

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      isSOS ? '🚨 EMERGENCY ALERTS' : 'ArrozSistema System',
      importance: isSOS ? Importance.max : Importance.high,
      priority: isSOS ? Priority.max : Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
      ongoing: isOngoing || isSOS,
      autoCancel: !isSOS,
      fullScreenIntent: isSOS,
      sound: isSOS ? const RawResourceAndroidNotificationSound('typhoon_siren') : null,
    );

    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: isSOS ? InterruptionLevel.critical : InterruptionLevel.active,
      ),
    );

    await NotificationService()._localNotifs.show(targetId, title, body, platformDetails, payload: payload);
  }

  static Future<void> dismissNotification(int id) async {
    await NotificationService()._localNotifs.cancel(id);
  }

  void _handleNotificationClick(String? payload) {
    if (payload == null) return;
    debugPrint("Clicked notification payload: $payload");
  }
}