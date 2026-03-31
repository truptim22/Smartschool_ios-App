// ignore_for_file: library_private_types_in_public_api, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, use_build_context_synchronously, use_key_in_widget_constructors
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/api_service.dart';
import '../models/login_request.dart';
import '../utils/session_manager.dart';
import '../utils/network_utils.dart';
import '../services/notification_service.dart';
import 'dashboard_screen.dart';
import 'student_selection_screen.dart'; 

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  
  bool _passwordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _animationController;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _logoAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _setupFCM(int studentId) async {
    try {
      print('📱 === FCM SETUP START (Background) ===');
      
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      
      // Request permission
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      print('Permission status: ${settings.authorizationStatus}');
      
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        print('❌ NOTIFICATION PERMISSION DENIED!');
        return;
      }
      
      // Get NEW FCM token
      String? token = await messaging.getToken();
      
      if (token == null) {
        print(' FCM TOKEN IS NULL!');
        return;
      }
      
      print('📱 FCM Token generated:');
      print('   Token (first 50 chars): ${token.substring(0, 50)}...');
      print('   Student ID: $studentId');
      
      // Send to backend with retry logic
      print('📤 Sending token to backend...');
      
      int retries = 3;
      bool success = false;
      
      while (retries > 0 && !success) {
        try {
          final response = await http.post(
            Uri.parse('https://lantechschools.org/student/$studentId/fcm-token'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'fcm_token': token}),
          ).timeout(Duration(seconds: 10));
          
          print('📥 Backend response: ${response.statusCode}');
          
          if (response.statusCode == 200) {
            print('✅ FCM TOKEN SAVED TO BACKEND SUCCESSFULLY!');
            success = true;
          } else {
            print('❌ FAILED TO SAVE TOKEN! Status: ${response.statusCode}');
            retries--;
            if (retries > 0) {
              await Future.delayed(Duration(seconds: 2));
            }
          }
        } catch (e) {
          print('❌ Network error saving token: $e');
          retries--;
          if (retries > 0) {
            await Future.delayed(Duration(seconds: 2));
          }
        }
      }
      
      if (!success) {
        print(' FAILED TO SAVE TOKEN AFTER ALL RETRIES');
      }
      
      print(' === FCM SETUP COMPLETE ===');
      
    } catch (e, stackTrace) {
      print(' FCM SETUP ERROR: $e');
      print('Stack trace: $stackTrace');
    }
  }

 Future<void> _attemptLogin() async {
  // Prevent double-tap
  if (_isLoading) {
    print(' Login already in progress, ignoring tap');
    return;
  }

  if (_usernameController.text.trim().isEmpty || 
      _passwordController.text.trim().isEmpty) {
    setState(() {
      _errorMessage = 'Please enter username and password';
    });
    return;
  }

  bool hasNetwork = await NetworkUtils.isNetworkAvailable();
  if (!hasNetwork) {
    _showNetworkDialog();
    setState(() {
      _errorMessage = 'No internet connection';
    });
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  FocusScope.of(context).unfocus();

  try {
    final request = LoginRequest(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    print('🔐 Attempting login for: ${request.username}');
    
    final response = await ApiService.login(request);

    print('=== RESPONSE DEBUG ===');
    print('   user.id: ${response.user?.id}');
    print('   user.studentId: ${response.user?.studentId}');
    print('   success: ${response.success}');
    print('   message: ${response.message}');
    print('   data: ${response.data}');
    print('   isParentAccount: ${response.isParentAccount}');
    print('   students count: ${response.students.length}');
    print('========================');

    // ✅ CHECK 1: Is this a PARENT ACCOUNT?
    if (response.success && response.isParentAccount) {
      print('👨‍👩‍👧 Parent account detected!');
      print('   Students: ${response.students.length}');
      
      if (response.students.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No students found for this parent account';
        });
        _showSnackBar('❌ No students linked to this account', isError: true);
        return;
      }
      
      setState(() {
        _isLoading = false;
      });

      // Navigate to student selection screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => StudentSelectionScreen(
              students: response.students,
              username: request.username,
              password: request.password,
            ),
          ),
        );
      }
      return; // ✅ STOP HERE
    }

    // ✅ CHECK 2: Regular STUDENT LOGIN
    if (response.success && response.user != null) {
      final user = response.user!;

      print('✅ Login Response:');
      print('   Username: ${user.username}');
      print('   User ID: ${user.id}');
      print('   Student ID: ${user.studentId}');

      if (user.studentId == null) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid user data: No student ID';
        });
        _showSnackBar('❌ No student ID received', isError: true);
        return;
      }

      final studentId = user.studentId ?? user.id;
      
      // ✅ Clean up old session
      print('🧹 Cleaning up old session...');
      await SessionManager.forceDeleteSession();
      
      // ✅ Delete old FCM token
      try {
        await FirebaseMessaging.instance.deleteToken();
        print('✅ Old FCM token deleted');
      } catch (e) {
        print('⚠️ Could not delete old token: $e');
      }
      
      // ✅ Save session FIRST (don't wait for FCM)
await SessionManager.saveUser(user);
   if (response.students.isNotEmpty) {
    await SessionManager.saveSiblings(response.students);
    print('✅ Saved ${response.students.length} sibling accounts');
  }
  
      // ✅ Verify save
      final savedUser = await SessionManager.getUser();
      if (savedUser?.username == user.username) {
        _showSnackBar('✅ Login successful! Welcome ${user.username}');
        print('🚀 Navigating to Dashboard...');
        
        setState(() {
          _isLoading = false;
        });

        if (mounted) {
        Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (context) => DashboardScreen(
        user: user,
        siblings: response.students,
      ),
    ),
  );
          print('✅ Navigation initiated!');
          
          // ✅ Setup FCM in background AFTER navigation
          // Initialize notifications in background
          try {
            final notificationService = NotificationService();
            notificationService.initialize(studentId);
            print('✅ Notifications initialized in background');
          } catch (e) {
            print('⚠️ Notification initialization failed: $e');
          }
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('❌ Session save failed', isError: true);
      }
      return; // ✅ STOP HERE
    }

    // ✅ CHECK 3: Login FAILED
    setState(() {
      _isLoading = false;
      _errorMessage = response.message ?? 'Login failed';
    });
    _showSnackBar('Login failed: ${response.message}', isError: true);

  } catch (e, stackTrace) {
    print('❌ Login error: $e');
    print('Stack trace: $stackTrace');
    setState(() {
      _isLoading = false;
      _errorMessage = 'Error: ${e.toString()}';
    });
    _showSnackBar('Login error: $e', isError: true);
  }
}

  void _showNetworkDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('No Internet Connection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Please check:'),
            SizedBox(height: 8),
            Text('• Mobile data or WiFi is enabled'),
            Text('• Airplane mode is off'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFF6B5B95),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -50,
              top: 100,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              right: -30,
              bottom: 200,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _logoAnimation,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _logoAnimation.value),
                            child: child,
                          );
                        },
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.school,
                            size: 60,
                            color: Color(0xFF6200EE),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 20),
                      
                      Text(
                        'SmartSchool',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1,
                        ),
                      ),
                      
                      SizedBox(height: 4),
                      
                      Text(
                        'School Management System',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      
                      SizedBox(height: 48),
                      
                      Card(
                        elevation: 16,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Column(
                            children: [
                              Text(
                                'Welcome Back',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF333333),
                                ),
                              ),
                              
                              SizedBox(height: 4),
                              
                              Text(
                                'Sign in to continue',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF666666),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              
                              SizedBox(height: 36),
                              
                              TextField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(
                                    Icons.person,
                                    color: Color(0xFF6200EE),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Color(0xFF6200EE),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                textInputAction: TextInputAction.next,
                                onSubmitted: (_) {
                                  _passwordFocusNode.requestFocus();
                                },
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() => _errorMessage = null);
                                  }
                                },
                              ),
                              
                              SizedBox(height: 18),
                              
                              TextField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: !_passwordVisible,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(
                                    Icons.lock,
                                    color: Color(0xFF6200EE),
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _passwordVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      color: Color(0xFF666666),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _passwordVisible = !_passwordVisible;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                      color: Color(0xFF6200EE),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _attemptLogin(),
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() => _errorMessage = null);
                                  }
                                },
                              ),
                              
                              SizedBox(height: 20),
                              
                              if (_errorMessage != null)
                                Container(
                                  padding: EdgeInsets.all(12),
                                  margin: EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error,
                                        color: Color(0xFFD32F2F),
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(
                                            color: Color(0xFFD32F2F),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              
                              SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _attemptLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF6200EE),
                                    disabledBackgroundColor: Color(0xFF6200EE).withOpacity(0.6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 4,
                                  ),
                                  child: _isLoading
                                      ? Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Signing In...',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFFFFFFF),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Sign In',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFFFFFFF),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(Icons.arrow_forward, size: 20),
                                          ],
                                        ),
                                ),
                              ),
                              
                              SizedBox(height: 20),                            
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 12),
                                    child: Text(
                                      'or',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF999999),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: Color(0xFFE0E0E0))),
                                ],
                              ),
                              
                              SizedBox(height: 16),
                              
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.help,
                                      color: Color(0xFF6200EE),
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Need Help?',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF333333),
                                          ),
                                        ),
                                        Text(
                                          'Contact your school admin',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF666666),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      
                      Column(
                        children: [
                          Text(
                            '© 2026 Smartschool',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'All rights reserved',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}