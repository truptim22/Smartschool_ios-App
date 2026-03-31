import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user.dart';
import '../utils/session_manager.dart';
import 'dashboard_screen.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/notification_service.dart';

class StudentSelectionScreen extends StatefulWidget {
  final List<dynamic> students;
  final String username;
  final String password;

  const StudentSelectionScreen({
    Key? key,
    required this.students,
    required this.username,
    required this.password,
  }) : super(key: key);

  @override
  _StudentSelectionScreenState createState() => _StudentSelectionScreenState();
}

class _StudentSelectionScreenState extends State<StudentSelectionScreen> {
  bool _isLoading = false;

 Future<void> _selectStudent(dynamic student) async {
  setState(() {
    _isLoading = true;
  });

  try {
    print('✅ Student selected: ${student['first_name']} ${student['last_name']}');
    
    final user = User(
      id: student['user_id'] ?? 0,
      username: widget.username,
      role: 'student',
      studentId: student['student_id'],
      firstName: student['first_name'],
      lastName: student['last_name'],
      className: student['class_name'],
      sectionName: student['section_name'],
      rollNumber: student['roll_number']?.toString(),
      email: null,
    );

    // Save to session
    await SessionManager.saveUser(user);
    await SessionManager.saveSiblings(widget.students);
    print('✅ Saved ${widget.students.length} sibling accounts');

    final studentId = user.studentId ?? user.id;
    
    // Clean up old session
    print('🧹 Cleaning up old session...');
    
    try {
      await FirebaseMessaging.instance.deleteToken();
      print('✅ Old FCM token deleted');
      await Future.delayed(Duration(milliseconds: 500));
    } catch (e) {
      print('⚠️ Could not delete old token: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Welcome ${user.firstName}!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });

    // Navigate to Dashboard WITH siblings list
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            user: user,
            siblings: widget.students,
          ),
        ),
      );
      
      // ✅ NEW: Setup FCM for ALL siblings in background
      _setupFCMForAllSiblings(widget.students);
    }
  } catch (e, stackTrace) {
    print('❌ Error selecting student: $e');
    print('Stack trace: $stackTrace');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to select student: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    setState(() {
      _isLoading = false;
    });
  }
}
// ✅ NEW: Setup FCM for ALL siblings
Future<void> _setupFCMForAllSiblings(List<dynamic> students) async {
  try {
    print('📱 === FCM SETUP FOR ALL SIBLINGS START ===');
    
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    
    // Request permission
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      print('❌ NOTIFICATION PERMISSION DENIED!');
      return;
    }
    
    // Get ONE FCM token for this device
    String? token = await messaging.getToken();
    
    if (token == null) {
      print('❌ FCM TOKEN IS NULL!');
      return;
    }
    
    print('📱 FCM Token generated (will be used for all siblings):');
    print('   Token (first 50 chars): ${token.substring(0, 50)}...');
    
    // ✅ Register this token for ALL siblings
    for (var student in students) {
      final studentId = student['student_id'];
      print('📤 Registering token for: ${student['first_name']} (ID: $studentId)');
      
      try {
        final response = await http.post(
          Uri.parse('https://lantechschools.org/student/$studentId/fcm-token'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'fcm_token': token}),
        ).timeout(Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          print('✅ Token registered for ${student['first_name']}');
        } else {
          print('⚠️ Failed for ${student['first_name']}: ${response.statusCode}');
        }
      } catch (e) {
        print('⚠️ Network error for ${student['first_name']}: $e');
      }
      
      // Small delay to avoid rate limiting
      await Future.delayed(Duration(milliseconds: 200));
    }
    
    // Initialize notifications for current student
    final notificationService = NotificationService();
    final currentStudentId = students.first['student_id'];
    notificationService.initialize(currentStudentId);
    
    print('📱 === FCM SETUP FOR ALL SIBLINGS COMPLETE ===');
    
  } catch (e, stackTrace) {
    print('❌ FCM SETUP ERROR: $e');
    print('Stack trace: $stackTrace');
  }
}

  // ✅ ADD THIS: Same FCM setup function as in login_screen.dart
  Future<void> _setupFCM(int studentId) async {
    try {
      print('📱 === FCM SETUP START (Parent Account) ===');
      
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
        print('❌ FCM TOKEN IS NULL!');
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
        print('❌ FAILED TO SAVE TOKEN AFTER ALL RETRIES');
      }
      
      print('📱 === FCM SETUP COMPLETE ===');
      
    } catch (e, stackTrace) {
      print('❌ FCM SETUP ERROR: $e');
      print('Stack trace: $stackTrace');
    }
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
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.family_restroom,
                      size: 80,
                      color: Colors.white,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Select Student',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Choose which student to continue as',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // Student Cards
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Loading...'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(24),
                          itemCount: widget.students.length,
                          itemBuilder: (context, index) {
                            final student = widget.students[index];
                            return _buildStudentCard(student);
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(dynamic student) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: () => _selectStudent(student),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Color(0xFF6200EE).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${student['first_name'][0]}${student['last_name'][0]}'
                        .toUpperCase(),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6200EE),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),

              // Student Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student['first_name']} ${student['last_name']}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Class ${student['class_name']} • ${student['section_name']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (student['roll_number'] != null)
                      Text(
                        'Roll No: ${student['roll_number']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF6200EE),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}