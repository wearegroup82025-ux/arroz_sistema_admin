import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

// 🌐 Coordinates para sa Capalangan, Apalit, Pampanga
const double capalanganLat = 14.9540;
const double capalanganLng = 120.7594;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Background Notification ID: ${message.messageId}");
}

// ⏰ Background Task Dispatcher para sa WorkManager (Kada 2 Oras)
@pragma('vm:entry-point')
void callbackDispatcher() {
  if (kIsWeb) return; // Pigilan ang pagtakbo sa web runtime background
  Workmanager().executeTask((task, inputData) async {
    await Firebase.initializeApp();
    await NotificationService.checkAndSendPeriodicWeatherAlert();
    return Future.value(true);
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Ginawang nullable ang native background instances para ligtas sa web execution
  final FirebaseMessaging? _fcm = kIsWeb ? null : FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin? _localNotifs = kIsWeb ? null : FlutterLocalNotificationsPlugin();

  static const String channelAlerts = 'stock_alerts_channel';
  static const String channelOrders = 'orders_channel';
  static const String channelUsers = 'users_channel';
  static const String channelWeather = 'weather_channel';
  static const String channelTyphoonSOS = 'typhoon_sos_channel';

  static Future<void> initNotification() async {
    await NotificationService().initialize();
  }

  Future<void> initialize() async {
    // Laktawan ang device-specific layout hooks kung ito ay nasa web ecosystem
    if (kIsWeb) {
      debugPrint("Web Runtime: Nilaktawan ang native background system setup.");
      return;
    }

    await _fcm?.requestPermission(
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

    await _localNotifs?.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        _handleNotificationClick(details.payload);
      },
    );

    await _createChannel(channelOrders, 'Admin Order Alerts', 'Notifications for incoming orders', Importance.high);
    await _createChannel(channelAlerts, 'Inventory & Stock Alerts', 'Low stock & critical warnings', Importance.high);
    await _createChannel(channelUsers, 'User Account Activity', 'New user registrations', Importance.defaultImportance);
    await _createChannel(channelWeather, 'Weather Forecasts & Disasters', 'Weather, typhoon, flood & dam alerts', Importance.high);

    await _saveFCMToken();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final data = message.data;

      String title = notification?.title ?? data['title'] ?? 'System Notification';
      String body = notification?.body ?? data['body'] ?? '';
      String type = data['type'] ?? 'general';

      String channelId = _getChannelIdByType(type);

      triggerThrottledNotification(
        title: title,
        body: body,
        channelId: channelId,
        type: type,
        payload: 'weather_page',
      );
    });
  }

  /// ⏰ Setup Background Periodic Weather Checker (Magsisimula sa 5:00 PM, then every 2 Hours)
  static Future<void> setupPeriodicWeatherCheck() async {
    if (kIsWeb) {
      debugPrint("Web Runtime: Hindi pinagana ang background Workmanager tasks.");
      return;
    }

    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    final now = DateTime.now();
    DateTime target = DateTime(now.year, now.month, now.day, 17, 0, 0);

    while (target.isBefore(now)) {
      target = target.add(const Duration(hours: 2));
    }

    final initialDelay = target.difference(now);

    await Workmanager().registerPeriodicTask(
      "capalangan_weather_check",
      "fetchWeatherPeriodic",
      frequency: const Duration(hours: 2),
      initialDelay: initialDelay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }

  /// 🌧️ Real Live Weather Fetcher para sa Capalangan
  static Future<void> checkAndSendPeriodicWeatherAlert() async {
    try {
      final url = Uri.parse(
        'https://open-meteo.com',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final currentWeather = data['current_weather'];

        final double temp = (currentWeather['temperature'] as num).toDouble();
        final double windSpeed = (currentWeather['windspeed'] as num).toDouble();
        final int weatherCode = currentWeather['weathercode'];

        String title = "🌤️ Capalangan Weather Update";
        String body = "Ulat Panahon (Capalangan): $temp°C ang temperatura. Normal ang kalagayan sa bukid.";
        String subCategory = "general";
        String severity = "info";

        if (weatherCode >= 51 && weatherCode <= 99) {
          title = "🌧️ Babala: May Ulan sa Capalangan";
          body = "Nagtala ng ulan ($temp°C). Agad na takpan ang mga nakabilad na palay at ihanda ang drainage sa bukid.";
          subCategory = "rain";
          severity = "warning";
        } else if (temp >= 35) {
          title = "☀️ Warning: Mataas na Heat Index ($temp°C)";
          body = "Mainit ang panahon sa Capalangan. Siguraduhing sapat ang patubig sa mga pilapil para hindi matuyo ang tanim.";
          subCategory = "heatindex";
          severity = "warning";
        } else if (windSpeed > 30) {
          title = "💨 Weather Alert: Malakas na Hangin";
          body = "Nagtala ng $windSpeed km/h na hangin sa Capalangan. Iligtas ang mga kagamitan at imbakan ng ani.";
          subCategory = "storm";
          severity = "warning";
        }

        final user = FirebaseAuth.instance.currentUser;
        final userId = user?.uid ?? 'system_broadcast';

        await createWeatherNotification(
          userId: userId,
          title: title,
          body: body,
          subCategory: subCategory,
          severity: severity,
        );
      }
    } catch (e) {
      debugPrint("Error fetching live weather: $e");
    }
  }

  static Future<void> triggerThrottledNotification({
    required String title,
    required String body,
    required String channelId,
    required String type,
    String? payload,
    int cooldownSeconds = 5,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSentTime = prefs.getInt('last_notif_$type') ?? 0;
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    if (currentTime - lastSentTime < (cooldownSeconds * 1000)) {
      debugPrint("Notification suppressed for channel $type to prevent fatigue.");
      return;
    }

    await prefs.setInt('last_notif_$type', currentTime);

    // Patakbuhin lang ang physical device local popups kung hindi web environment
    if (!kIsWeb) {
      await showNotification(
        title: title,
        body: body,
        channelId: channelId,
        payload: payload,
      );
    } else {
      debugPrint("Web Application Notification Output -> [$title]: $body");
    }
  }

  Future<void> _saveFCMToken() async {
    if (kIsWeb) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String? token = await _fcm?.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }
  }

  static String _getChannelIdByType(String type) {
    final cleanType = type.toLowerCase().trim();

    final weatherKeywords = [
      'weather', 'rain', 'typhoon', 'bagyo', 'habagat', 'amihan', 'monsoon',
      'hightide', 'lowtide', 'tide', 'flood', 'baha', 'dam', 'spillway',
      'landslide', 'storm', 'thunderstorm', 'lightning', 'cyclone', 'tsunami',
      'stormsurge', 'heatindex', 'heatwave', 'drought', 'elprino', 'lanina',
      'wind', 'gale', 'volcano', 'ashfall', 'earthquake', 'fog', 'cloud',
      'humidity', 'uv', 'airquality'
    ];

    if (weatherKeywords.contains(cleanType)) {
      return channelWeather;
    }

    switch (cleanType) {
      case 'order':
      case 'orders':
        return channelOrders;
      case 'user':
      case 'users':
        return channelUsers;
      case 'stock':
      case 'stocks':
        return channelAlerts;
      default:
        return channelAlerts;
    }
  }

  static Future<void> createWeatherNotification({
    required String userId,
    required String title,
    required String body,
    String subCategory = 'general',
    String severity = 'info',
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': 'weather',
      'subCategory': subCategory.toLowerCase().trim(),
      'severity': severity.toLowerCase().trim(),
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await triggerThrottledNotification(
      title: title,
      body: body,
      channelId: channelWeather,
      type: 'weather',
      payload: 'weather_page',
    );
  }

  static Future createOrderNotification({
    required String userId,
    required String orderId,
    required double totalAmount,
  }) async {
    final title = "New Order Received (#$orderId)";
    final body = "A new order worth ₱${totalAmount.toStringAsFixed(2)} was placed. Please process for fulfillment.";
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': 'order',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await triggerThrottledNotification(
      title: title,
      body: body,
      channelId: channelOrders,
      type: 'order',
    );
  }

  Future _createChannel(String id, String name, String desc, Importance importance) async {
    if (kIsWeb) return;
    final AndroidNotificationChannel channel = AndroidNotificationChannel(
      id,
      name,
      description: desc,
      importance: importance,
      playSound: true,
      enableVibration: true,
    );
    await _localNotifs
      ?.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
  }

  static Future showNotification({
    int? id,
    required String title,
    required String body,
    String? payload,
    String channelId = channelAlerts,
  }) async {
    if (kIsWeb) return;
    final int targetId = id ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      'Admin System Notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(body),
    );
    NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(
        presentSound: true,
        presentBanner: true,
        presentList: true,
      ),
    );
    await NotificationService()._localNotifs?.show(targetId, title, body, platformDetails, payload: payload);
  }

  void _handleNotificationClick(String? payload) {
    if (payload == 'weather_page') {
      debugPrint("Directing user to Weather Page");
    }
  }
}