// ignore_for_file: use_key_in_widget_constructors, prefer_const_constructors, library_private_types_in_public_api, use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'utils/session_manager.dart';
import 'services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'models/user.dart';  
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase MUST be before runApp - it's needed immediately
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // This is fast (just reads local storage) - ok to await
  await SessionManager.checkAndHandleReinstall();
  
  runApp(MySchoolApp());
}
class MySchoolApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'My School App',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,
      home: AppInitializer(),
    );
  }
}

class AppInitializer extends StatefulWidget {
  @override
  _AppInitializerState createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> setupFCM(int studentId) async {
    try {
      print('🔔 === FCM SETUP START ===');
      
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      print('📱 Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('❌ NOTIFICATION PERMISSION DENIED!');
        return;
      }
      
      String? token = await messaging.getToken();
      
      if (token == null) {
        print('❌ FCM TOKEN IS NULL!');
        return;
      }
      
      print('✅ FCM Token generated:');
      print('   Token (first 50 chars): ${token.substring(0, 50)}...');
      print('   Token length: ${token.length}');
      print('   Student ID: $studentId');
      
      print('📤 Sending token to backend...');
      
      final response = await http.post(
        Uri.parse('https://lantechschools.org/api/student/$studentId/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fcm_token': token}),
      );
      
      print('📥 Backend response: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        print('✅ FCM TOKEN SAVED TO BACKEND SUCCESSFULLY!');
      } else {
        print('❌ FAILED TO SAVE TOKEN! Status: ${response.statusCode}');
      }
      
      print('🔔 === FCM SETUP COMPLETE ===');
      
    } catch (e, stackTrace) {
      print('❌ FCM SETUP ERROR: $e');
      print('Stack trace: $stackTrace');
    }
  }

  void onLoginSuccess(int studentId) async {
    print('🔐 Login successful for student: $studentId');
    await setupFCM(studentId);
  }

  
Future<void> _initializeApp() async {
  final isLoggedIn = await SessionManager.isLoggedIn();
  final user = await SessionManager.getUser();

  if (!mounted) return;

  // ✅ Strict check — ALL THREE must be valid
  if (isLoggedIn && user != null && user.isValid() && user.studentId != null) {
    final studentId = user.studentId!;

    // ✅ Don't await — run in background
    NotificationService().initialize(studentId);

   // ✅ Fixed — fetch siblings BEFORE navigation
final siblings = await SessionManager.getSiblings();

Navigator.of(context).pushReplacement(
  MaterialPageRoute(
    builder: (context) => DashboardScreen(
      user: user,
      siblings: siblings,
    ),
  ),
);
  } else {
    // ✅ Always wipe if anything is invalid
    await SessionManager.forceDeleteSession();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    return SplashScreen();
  }
}