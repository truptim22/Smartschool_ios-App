
// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, prefer_const_constructors_in_immutables, prefer_const_constructors, deprecated_member_use, sort_child_properties_last

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import 'pdf_viewer_page.dart';
import 'download_files_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdfx/pdfx.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class NotificationsScreen extends StatefulWidget {
  final int studentId;
  
  NotificationsScreen({required this.studentId});
  
  @override
  _NotificationsScreenState createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _notifications = [];

  @override
  void initState() {
    super.initState();
    print('🔔 ============================================');
    print('🔔 NOTIFICATIONS SCREEN INITIALIZED');
    print('   Student ID: ${widget.studentId}');
    print('🔔 ============================================');
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('📱 Loading notifications for User ID: ${widget.studentId}');
      final response = await ApiService.getStudentNotifications(widget.studentId);

      print('📥 Response received:');
      print('   Success: ${response['success']}');
      print('   Message: ${response['message']}');
      print('   Data: ${response['data']}');

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        final notifications = response['data'] as List<dynamic>;
        
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
        
        print('✅ Loaded ${_notifications.length} notifications');
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load notifications';
          _isLoading = false;
        });
        print('❌ Error: ${response['message']}');
      }
    } catch (e) {
      print('❌ Notifications error: $e');
      if (!mounted) return;
      
      setState(() {
        _error = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    final title = notification['title'] ?? 'Notification Details';
    final description = notification['description'] ?? 'No description';
    final createdAt = notification['created_at'] ?? '';
    final filePath = notification['file_path'];
    final hasPDF = filePath != null && filePath.toString().isNotEmpty;

    String formattedDate = 'Unknown date';
    String formattedTime = '';
    
    if (createdAt.isNotEmpty) {
      try {
        final date = DateTime.parse(createdAt).toLocal();
        formattedDate = '${date.day}/${date.month}/${date.year}';
        final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
        final minute = date.minute.toString().padLeft(2, '0');
        final period = date.hour >= 12 ? 'PM' : 'AM';
        formattedTime = '$hour:$minute $period';
      } catch (e) {
        formattedDate = createdAt;
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: Colors.white70),
                        SizedBox(width: 6),
                        Text(formattedDate, style: TextStyle(fontSize: 13, color: Colors.white70)),
                        if (formattedTime.isNotEmpty) ...[
                          SizedBox(width: 12),
                          Icon(Icons.access_time, size: 14, color: Colors.white70),
                          SizedBox(width: 6),
                          Text(formattedTime, style: TextStyle(fontSize: 13, color: Colors.white70)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    description,
                    style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.5),
                  ),
                ),
              ),
              
              // PDF Actions Section
              if (hasPDF) _buildPDFActions(filePath, title),
              
              // Close Button
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close', style: TextStyle(color: Color(0xFF6200EE), fontSize: 16)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  
Widget _buildPDFActions(String filePath, String title) {
    // ✅ FIX: Use helper function to get correct URL
    final fullUrl = ApiService.getFileUrl(filePath);
    
    print('📄 PDF Actions:');
    print('   Original path: $filePath');
    print('   Full URL: $fullUrl');
    
    // Create a readable filename with date
    final now = DateTime.now();
    final dateStr = '${now.day}-${now.month}-${now.year}';
    final safeTitle = title.replaceAll(RegExp(r'[^\w\s-]'), '').replaceAll(' ', '_');
    final fileName = '${safeTitle}_$dateStr.pdf';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFF6200EE).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF6200EE).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Color(0xFF6200EE), size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'PDF Attachment',
                  style: TextStyle(
                    color: Color(0xFF6200EE),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PDFViewerPage(
                          filePath: fullUrl,  // ✅ Pass full URL
                          title: title,
                          isLocalFile: false,
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.visibility, size: 20),
                  label: Text('View PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6200EE),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await DownloadService.downloadFile(
                      url: fullUrl,  // ✅ Use full URL
                      fileName: fileName,
                      context: context,
                    );
                  },
                  icon: Icon(Icons.download, size: 20),
                  label: Text('Download'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF6200EE),
                    side: BorderSide(color: Color(0xFF6200EE)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }








@override
Widget build(BuildContext context) {
  return Scaffold(  // ✅ CHANGED: Removed WillPopScope
    backgroundColor: Color(0xFFF5F5F5),
    body: _buildBody(),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DownloadedFilesScreen(),
          ),
        );
      },
      backgroundColor: Color(0xFF6200EE),
      foregroundColor: Colors.white, 
      icon: Icon(Icons.folder_open),
      label: Text('My Downloads'),
    ),
  );
}

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6200EE)),
            SizedBox(height: 16),
            Text('Loading notifications...', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
            SizedBox(height: 8),
            Text('Student ID: ${widget.studentId}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
            SizedBox(height: 8),
            Text('Student ID: ${widget.studentId}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNotifications,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF6200EE)),
            ),
          ],
        ),
      );
    }

    if (_notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_off, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('No notifications', style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            SizedBox(height: 8),
            Text('Student ID: ${widget.studentId}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      color: Color(0xFF6200EE),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) => _buildNotificationCard(_notifications[index]),
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final title = notification['title'] ?? 'Untitled';
    final description = notification['description'] ?? 'No description';
    final createdAt = notification['created_at'] ?? '';
    final hasPDF = notification['file_path'] != null && 
                    notification['file_path'].toString().isNotEmpty;

    String formattedDate = 'Unknown date';
    if (createdAt.isNotEmpty) {
      try {
        final date = DateTime.parse(createdAt);
        formattedDate = '${date.day}/${date.month}/${date.year}';
      } catch (e) {
        formattedDate = createdAt;
      }
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showNotificationDetails(notification),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ),
                  if (hasPDF)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFF6200EE).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_file, size: 14, color: Color(0xFF6200EE)),
                          SizedBox(width: 4),
                          Text(
                            'PDF',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6200EE),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                  SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}