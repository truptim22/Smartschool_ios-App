// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

// Global instance for background handler
final FlutterLocalNotificationsPlugin _backgroundLocalNotifications = //This is used for notification arrival when the app is closed or the phone is off 

    FlutterLocalNotificationsPlugin();
@pragma('vm:entry-point')       //Special function that Android calls when a background notification arrives.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
 
  await Firebase.initializeApp();  //Must initialize Firebase so Flutter knows how to read the notification
  
  print('🔔 ═══ BACKGROUND MESSAGE RECEIVED ═══');
  print('   Title: ${message.data['title']}');  //prints the title of the notification 
  print('   Body: ${message.data['body']}'); //prints the description
  
  // ✅ Show notification in background
  const String channelId = 'mydschool_notifications_v11';  
  const String channelName = 'MyDSchool Notifications';
  
  final title = message.data['title'] ?? 'MyDSchool';
  final body = message.data['body'] ?? message.data['message'] ?? 'New notification';
  
  await _backgroundLocalNotifications.show( //→ Actually displays notification to the user.
    DateTime.now().millisecondsSinceEpoch ~/ 1000, //→ Unique ID for the notification (based on time).
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails( //Creates an Android notification format
        channelId,
        channelName,
        channelDescription: 'School notifications with sound',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('sound'), 
        enableVibration: true, 
        vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
        icon: '@mipmap/ic_launcher',
        enableLights: true,
        color: const Color.fromARGB(255, 98, 0, 238),
      ),
    ),
    payload: json.encode(message.data), //gives you extra data when user clicks notification
  );
  
  print('✅ Background notification shown');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;  // Makes sure the same object is used everywhere.
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance; //used for receiving messages 
  final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();//Used to show pop-up notifications.

  String? _fcmToken; 
  String? get fcmToken => _fcmToken; //Stores token & active student ID.
  
  Function()? onNewNotification;
  int? _currentStudentId;

  // ✅ NEW VERSION - forces channel recreation
  static const String _channelId = 'mydschool_notifications_v11';   
  static const String _channelName = 'MyDSchool Notifications';

  Future<void> initialize(int studentId) async {
    print('🚀 ═══ INITIALIZING NOTIFICATIONS ═══');
    print('   Student ID: $studentId');
    _currentStudentId = studentId;

    // ✅ Request permission
    NotificationSettings settings = await _messaging.requestPermission(  //Asks user permission to show notifications.
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      criticalAlert: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      print('❌ Notification permission denied');
      return;
    }
    print('✅ Permission granted');

    // ✅ Initialize local notifications FIRST
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _localNotifications.initialize(  //→ Prepares local notification system.
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        print('🔔 Notification tapped');
        onNewNotification?.call();
      },
    );

    // ✅ Initialize background handler's local notifications
    await _backgroundLocalNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // ✅ DELETE old channels first
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      // Delete all old versions
      await androidPlugin.deleteNotificationChannel('mydschool_notifications_v10');
      await androidPlugin.deleteNotificationChannel('mydschool_notifications_v9');
      await androidPlugin.deleteNotificationChannel('default_notification_channel_id');
      print('🗑️ Old channels deleted');
    }

    // ✅ Create NEW channel with sound
   final AndroidNotificationChannel channel = AndroidNotificationChannel(
  _channelId,
  _channelName,
  description: 'School notifications with custom sound',
  importance: Importance.max,
  playSound: true,
  sound: RawResourceAndroidNotificationSound('sound'),
  enableVibration: true,
  vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
  enableLights: true,
  ledColor: const Color.fromARGB(255, 98, 0, 238),
);

    await androidPlugin?.createNotificationChannel(channel);
    print('✅ Channel created: $_channelId with sound.mp3');

    // ✅ Get FCM token
    _fcmToken = await _messaging.getToken();
    if (_fcmToken != null) {
      print('📱 FCM Token obtained: ${_fcmToken!.substring(0, 30)}...');
      await _sendTokenToBackend(studentId, _fcmToken!);
    }

    // Token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      print('🔄 Token refreshed');
      _fcmToken = newToken;
      if (_currentStudentId != null) {
        _sendTokenToBackend(_currentStudentId!, newToken);
      }
    });

    // ✅ Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App opened from terminated
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        print('🔔 App opened from terminated');
        onNewNotification?.call();
      }
    });

    // App opened from background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      print('🔔 App opened from background');
      onNewNotification?.call();
    });

    print('✅ Notification Service initialized successfully');
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('🔔 ═══ FOREGROUND MESSAGE ═══');

    final targetId = int.tryParse(
      message.data['student_id'] ?? message.data['studentId'] ?? ''
    );
    
    if (_currentStudentId != null && targetId != null) {
      if (_currentStudentId != targetId) {
        print('⚠️ Not for this user');
        return;
      }
    }

    final title = message.data['title'] ?? 'MyDSchool';
    final body = message.data['body'] ?? message.data['message'] ?? 'New notification';

    print('   Title: $title');
    print('   Body: $body');

    // ✅ Show with sound
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'School notifications',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('sound'), 
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
          icon: '@mipmap/ic_launcher',
          enableLights: true,
          color: const Color.fromARGB(255, 98, 0, 238),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'sound.aiff',
        ),
      ),
      payload: json.encode(message.data),
    );

    onNewNotification?.call();
    print('✅ Foreground notification shown');
  }

  Future<void> _sendTokenToBackend(int studentId, String token) async {
    try {
      const String baseUrl = 'https://lantechschools.org/api';
      final response = await http.post(
        Uri.parse('$baseUrl/student/$studentId/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fcm_token': token}),
      );
      if (response.statusCode == 200) {
        print('✅ FCM token sent to backend');
      } else {
        print('❌ Token send failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Token send error: $e');
    }
  }

  // ✅ Test notification with sound
  Future<void> showTestNotification() async {
    print('🧪 Testing notification...');
    await _localNotifications.show(
      999,
      'Test Notification 🔔',
      'If you hear sound and feel vibration, it works!',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('sound'),
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'sound.aiff',
        ),
      ),
    );
    print('✅ Test notification shown');
  }
}