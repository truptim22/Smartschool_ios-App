// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, prefer_const_constructors, use_build_context_synchronously, deprecated_member_use, prefer_const_literals_to_create_immutables, prefer_const_constructors_in_immutables
import 'class_schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user.dart';
import '../utils/session_manager.dart';
import '../services/notification_service.dart';
import 'profile_screen.dart';
import 'assignments_screen.dart';
import 'notifications_screen.dart';
import 'attendance_screen.dart';
import 'login_screen.dart';
import 'timetable_screen.dart';
import 'result_screen.dart';
import 'package:url_launcher/url_launcher.dart';
class DashboardScreen extends StatefulWidget {
  final User user;
  final List<dynamic>? siblings;
  DashboardScreen({required this.user, this.siblings});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _selectedTab = 'Dashboard';
  bool _hasNewNotifications = false;
  DateTime? _lastPressedAt;
  List<dynamic> _siblings = [];
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    print('🏠 DASHBOARD LOADED');
    print('   User ID: ${widget.user.id}');
    print('   Username: ${widget.user.username}');
    print('   Student ID: ${widget.user.studentId}');
    print('   First Name: ${widget.user.firstName}');
    print('   Last Name: ${widget.user.lastName}');
    print('   Class Name: ${widget.user.className}');
    print('   Section Name: ${widget.user.sectionName}');
    if (widget.siblings != null && widget.siblings!.isNotEmpty) {
      _siblings = widget.siblings!;
      print('✅ Loaded ${_siblings.length} sibling accounts from constructor');
    }
  }

  @override
  void dispose() {
    NotificationService().onNewNotification = null;
    super.dispose();
  }

  Future<void> _switchAccount(dynamic student) async {
    if (student['student_id'] == _currentUser?.studentId) {
      print(' Already viewing this account');
      return;
    }
    try {
      print('🔄 Switching account to: ${student['first_name']} ${student['last_name']}');
      final newUser = User(
        id: student['user_id'] ?? _currentUser!.id,
        username: _currentUser!.username,
        role: 'student',
        studentId: student['student_id'],
        firstName: student['first_name'],
        lastName: student['last_name'],
        className: student['class_name'],
        sectionName: student['section_name'],
        rollNumber: student['roll_number']?.toString(),
        email: null,
      );
      setState(() {
        _currentUser = newUser;
        _selectedTab = 'Dashboard';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 12),
              Text('Switched to ${newUser.firstName}\'s account'),
            ]),
            backgroundColor: Color(0xFF4CAF50),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      _performBackgroundSwitchOperations(newUser);
      print('✅ Account switch complete (UI updated instantly)');
    } catch (e) {
      print('❌ Error switching account: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to switch account'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _performBackgroundSwitchOperations(User newUser) async {
    print('🔧 Starting background operations...');
    try {
      await SessionManager.saveUser(newUser);
      print('✅ Session saved');
      if (_siblings.isNotEmpty) {
        await SessionManager.saveSiblings(_siblings);
        print('✅ Siblings re-saved');
      }
      _setupFCM(newUser.studentId ?? newUser.id);
      final notificationService = NotificationService();
      notificationService.initialize(newUser.studentId ?? newUser.id);
      print('✅ Notifications initialized');
      print('✅ Background operations complete');
    } catch (e) {
      print('⚠️ Background operation failed: $e');
    }
  }

  Future<void> _setupFCM(int studentId) async {
    try {
      print('📱 FCM setup (background)...');
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();
      if (token == null) {
        print('⚠️ FCM TOKEN IS NULL');
        return;
      }
      print('📱 Reusing FCM Token for Student ID: $studentId');
      http.post(
        Uri.parse('https://lantechschools.org/student/$studentId/fcm-token'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'fcm_token': token}),
      ).timeout(
        Duration(seconds: 5),
        onTimeout: () {
          print('⚠️ FCM token update timeout (continuing anyway)');
          return http.Response('Timeout', 408);
        },
      ).then((response) {
        if (response.statusCode == 200) {
          print('✅ FCM token saved');
        } else {
          print('⚠️ FCM save failed: ${response.statusCode}');
        }
      }).catchError((e) {
        print('⚠️ FCM network error: $e');
      });
    } catch (e) {
      print('⚠️ FCM setup error: $e');
    }
  }

  void _onDrawerItemTapped(String destination) {
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      Navigator.pop(context);
    }
    if (mounted) {
      setState(() {
        _selectedTab = destination;
        _lastPressedAt = null;
      });
    }
  }

  void _navigateToTab(String destination) {
    if (mounted) {
      setState(() {
        _selectedTab = destination;
        _lastPressedAt = null;
      });
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.logout, color: Colors.red),
          SizedBox(width: 12),
          Text('Logout'),
        ]),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _handleLogout();
    }
  }

  Future<void> _handleLogout() async {
    try {
      print('🚪 === LOGOUT STARTED ===');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Logging out...'),
                ],
              ),
            ),
          ),
        ),
      );
      final user = await SessionManager.getUser();
      if (user != null && user.studentId != null) {
        print('📱 Clearing FCM token for student: ${user.studentId}');
        try {
          await FirebaseMessaging.instance.deleteToken();
          print('✅ FCM token deleted from Firebase');
        } catch (e) {
          print('⚠️ Error deleting FCM token: $e');
        }
        try {
          final response = await http.post(
            Uri.parse('https://lantechschools.org/student/logout'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'studentId': user.studentId}),
          );
          if (response.statusCode == 200) {
            print('✅ FCM token cleared from backend');
          } else {
            print('⚠️ Failed to clear token from backend: ${response.statusCode}');
          }
        } catch (e) {
          print('⚠️ Error clearing token from backend: $e');
        }
      }
      await SessionManager.forceDeleteSession();
      print('✅ Local session cleared');
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginScreen()),
          (route) => false,
        );
        print('✅ Navigated to login screen');
      }
      print('🚪 === LOGOUT COMPLETE ===');
    } catch (e) {
      print('❌ Logout error: $e');
      if (mounted) Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<bool> _onWillPop() async {
    print('⬅️ Back button pressed. Current tab: $_selectedTab');
    print('   Drawer open: ${_scaffoldKey.currentState?.isDrawerOpen}');
    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
      print('   Closing drawer');
      Navigator.pop(context);
      return Future.value(false);
    }
    if (_selectedTab != 'Dashboard') {
      print('   Navigating back to Dashboard from $_selectedTab');
      if (mounted) {
        setState(() {
          _selectedTab = 'Dashboard';
          _lastPressedAt = null;
        });
      }
      return Future.value(false);
    }
    final now = DateTime.now();
    const maxDuration = Duration(seconds: 2);
    if (_lastPressedAt == null || now.difference(_lastPressedAt!) > maxDuration) {
      print('   First back press - showing warning');
      _lastPressedAt = now;
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text('Press back again to exit',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ]),
            backgroundColor: Color(0xFF6200EE),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 6,
          ),
        );
      }
      return Future.value(false);
    }
    print('   Second back press - exiting app');
    SystemNavigator.pop();
    return Future.value(true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {}
      },
      child: Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text(_selectedTab, style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Color(0xFF6200EE),
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          actions: [
            if (_siblings.length > 1) _buildAccountSwitcher(),
            SizedBox(width: 8),
          ],
        ),
        drawer: _buildDrawer(),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildAccountSwitcher() {
    return PopupMenuButton<dynamic>(
      icon: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person, size: 20, color: Colors.white),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 20, color: Colors.white),
          ],
        ),
      ),
      tooltip: 'Switch Account',
      offset: Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (BuildContext context) {
        return _siblings.map((student) {
          final isCurrentUser = student['student_id'] == _currentUser?.studentId;
          return PopupMenuItem<dynamic>(
            value: student,
            child: Container(
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Color(0xFF6200EE).withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Color(0xFF6200EE).withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${student['first_name'][0]}${student['last_name'][0]}'.toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6200EE),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${student['first_name']} ${student['last_name']}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isCurrentUser ? FontWeight.bold : FontWeight.normal,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          'Class ${student['class_name']} • ${student['section_name']}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrentUser)
                    Icon(Icons.check_circle, color: Color(0xFF6200EE), size: 20),
                ],
              ),
            ),
          );
        }).toList();
      },
      onSelected: (student) => _switchAccount(student),
    );
  }
Future<void> _startLiveClass() async {
  // Show loading
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Center(child: CircularProgressIndicator(color: Color(0xFF6200EE))),
  );

  try {
    final response = await http.get(
      Uri.parse('https://lantechschools.org/api/student/live-class-url/${_currentUser!.studentId}'),
    );
    if (mounted) Navigator.pop(context); // dismiss loading

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final url = data['url'];

      if (url == null || url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Live class not started yet. Check back later.'),
          backgroundColor: Colors.orange,
        ));
        return;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open Live Class link'),
          backgroundColor: Colors.red,
        ));
      }
    }
  } catch (e) {
    if (mounted) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Failed to fetch Live Class URL'),
      backgroundColor: Colors.red,
    ));
  }
}
  Widget _buildDrawer() {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(24, 60, 24, 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6200EE), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(Icons.person, size: 40, color: Color(0xFF6200EE)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    '${_currentUser?.firstName ?? ''} ${_currentUser?.lastName ?? ''}'.trim(),
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.class_, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Text('Class: ${_currentUser?.className ?? 'Not Assigned'}',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ]),
                  SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.group, color: Colors.white70, size: 16),
                    SizedBox(width: 8),
                    Text('Section: ${_currentUser?.sectionName ?? 'Not Assigned'}',
                        style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ]),
                  if (_siblings.length > 1) ...[
                    SizedBox(height: 12),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.people, color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text('${_siblings.length} accounts',
                              style: TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Menu Items ───────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    leading: Icon(Icons.dashboard_rounded, size: 28, color: Color(0xFF6200EE)),
                    title: 'Dashboard',
                    isSelected: _selectedTab == 'Dashboard',
                    onTap: () => _onDrawerItemTapped('Dashboard'),
                  ),
                  _buildDrawerItem(
                    leading: Icon(Icons.account_circle_rounded, size: 28, color: Color(0xFF6200EE)),
                    title: 'Profile',
                    isSelected: _selectedTab == 'Profile',
                    onTap: () => _onDrawerItemTapped('Profile'),
                  ),
                  _buildDrawerItem(
                    leading: Icon(Icons.event_note_rounded, size: 28, color: Color(0xFF6200EE)),
                    title: 'Exam Timetable',
                    isSelected: _selectedTab == 'Timetable',
                    onTap: () => _onDrawerItemTapped('Timetable'),
                  ),
                  _buildDrawerItem(
                    leading: Icon(Icons.calendar_month_rounded, size: 28, color: Color(0xFF6200EE)),
                    title: 'Class Timetable',
                    isSelected: _selectedTab == 'ClassSchedule',
                    onTap: () => _onDrawerItemTapped('ClassSchedule'),
                  ),
                  _buildDrawerItem(
                    leading: Icon(Icons.menu_book_rounded, size: 28, color: Color(0xFF6200EE)),
                    title: 'Classwork / Homework',
                    isSelected: _selectedTab == 'Assignments',
                    onTap: () => _onDrawerItemTapped('Assignments'),
                  ),
                  _buildDrawerItem(
                    leading: Icon(Icons.notifications_rounded, size: 28, color: Color(0xFF6200EE)),
                    title: 'Notifications',
                    isSelected: _selectedTab == 'Notifications',
                    onTap: () => _onDrawerItemTapped('Notifications'),
                  ),
                  _buildDrawerItem(
                    leading: Icon(Icons.fact_check_rounded, size: 28, color: Color(0xFF6200EE)),
                    title: 'Attendance',
                    isSelected: _selectedTab == 'Attendance',
                    onTap: () => _onDrawerItemTapped('Attendance'),
                  ),
                  _buildDrawerItem(
                    leading: Icon(Icons.bar_chart_rounded, size: 28, color: Color(0xFF6200EE)),
                    title: 'Result',
                    isSelected: _selectedTab == 'Result',
                    onTap: () => _onDrawerItemTapped('Result'),
                  ),
                  _buildDrawerItem(
  leading: Icon(Icons.live_tv_rounded, size: 32, color: Color(0xFF6200EE)),
  title: 'Live Class',
  isSelected: false,
  onTap: _startLiveClass,
),
                  Divider(height: 32),
                  _buildDrawerItem(
                    leading: Icon(Icons.logout_rounded, size: 28, color: Color(0xFFE35555)),
                    title: 'Logout',
                    isSelected: false,
                    onTap: _logout,
                  ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.all(16),
              child: Text('© 2026 SmartSchool',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required Widget leading,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Color(0xFF6200EE) : Colors.grey[800],
        ),
      ),
      selected: isSelected,
      selectedTileColor: Color(0xFF6200EE).withOpacity(0.1),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildBody() {
    switch (_selectedTab) {
      case 'Dashboard':
        return _buildDashboardContent();
      case 'Profile':
        return ProfileScreen(studentId: _currentUser!.studentId!);
      case 'Assignments':
        return AssignmentsScreen(studentId: _currentUser!.studentId!);
      case 'Notifications':
        return NotificationsScreen(studentId: _currentUser!.studentId!);
      case 'Attendance':
        return AttendanceScreen(studentId: _currentUser!.studentId!);
      case 'Timetable':
        return TimetableScreen(studentId: _currentUser!.studentId!);
      case 'Result':
        return ResultScreen(studentId: _currentUser!.studentId!);
      case 'ClassSchedule':
        return ClassScheduleScreen(studentId: _currentUser!.studentId!);
      default:
        return _buildDashboardContent();
    }
  }

  Widget _buildDashboardContent() {
    return Container(
      color: Color(0xFFF5F5F5),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Welcome Banner ───────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF6200EE).withOpacity(0.3),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome Back!',
                      style: TextStyle(
                          color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(
                    'Hello, ${_currentUser?.firstName ?? ''} ${_currentUser?.lastName ?? ''}'.trim(),
                    style: TextStyle(
                        color: Colors.white70, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  if (_currentUser?.className != null)
                    Text(
                      'Class ${_currentUser?.className} • Section ${_currentUser?.sectionName ?? "N/A"}',
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                ],
              ),
            ),
            SizedBox(height: 24),

            Text('Quick Access',
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            SizedBox(height: 16),

            // ── Grid ─────────────────────────────────────────
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildMenuCard(
                  leading: Icon(Icons.account_circle_rounded, size: 32, color: Color(0xFF6200EE)),
                  title: 'Profile',
                  isSelected: _selectedTab == 'Profile',
                  onTap: () => _navigateToTab('Profile'),
                ),
                _buildMenuCard(
                  leading: Icon(Icons.event_note_rounded, size: 32, color: Color(0xFF6200EE)),
                  title: 'Exam Timetable',
                  isSelected: _selectedTab == 'Timetable',
                  onTap: () => _navigateToTab('Timetable'),
                ),
                _buildMenuCard(
                  leading: Icon(Icons.menu_book_rounded, size: 32, color: Color(0xFF6200EE)),
                  title: 'Classwork / Homework',
                  isSelected: _selectedTab == 'Assignments',
                  onTap: () => _navigateToTab('Assignments'),
                ),
                _buildMenuCard(
                  leading: Icon(Icons.notifications_rounded, size: 32, color: Color(0xFF6200EE)),
                  title: 'Notifications',
                  isSelected: _selectedTab == 'Notifications',
                  onTap: () => _navigateToTab('Notifications'),
                ),
               _buildMenuCard(
                  leading: Icon(Icons.live_tv_rounded, size: 32, color: Color(0xFF6200EE)),
                  title: 'Live Class',
                  isSelected: false,
                  onTap: _startLiveClass,
                ),
                _buildMenuCard(
                  leading: Icon(Icons.fact_check_rounded, size: 32, color: Color(0xFF6200EE)),
                  title: 'Attendance',
                  isSelected: _selectedTab == 'Attendance',
                  onTap: () => _navigateToTab('Attendance'),
                ),
                _buildMenuCard(
                  leading: Icon(Icons.calendar_month_rounded, size: 32, color: Color(0xFF6200EE)),
                  title: 'Class Timetable',
                  isSelected: _selectedTab == 'ClassSchedule',
                  onTap: () => _navigateToTab('ClassSchedule'),
                ),
                _buildMenuCard(
                  leading: Icon(Icons.bar_chart_rounded, size: 32, color: Color(0xFF6200EE)),
                  title: 'Result',
                  isSelected: _selectedTab == 'Result',
                  onTap: () => _navigateToTab('Result'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required Widget leading,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: isSelected ? 6 : 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Color(0xFF6200EE).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(child: leading),
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}