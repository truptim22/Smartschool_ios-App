// ignore_for_file: library_private_types_in_public_api, prefer_const_constructors, prefer_const_literals_to_create_immutables, deprecated_member_use, use_key_in_widget_constructors, prefer_const_constructors_in_immutables

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import 'pdf_viewer_page.dart';
import 'download_files_screen.dart';

class ClassScheduleScreen extends StatefulWidget {
  final int studentId;
  ClassScheduleScreen({required this.studentId});

  @override
  _ClassScheduleScreenState createState() => _ClassScheduleScreenState();
}

class _ClassScheduleScreenState extends State<ClassScheduleScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _schedules = [];

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    if (!mounted) return;
    try {
      setState(() { _isLoading = true; _error = null; });
      final response = await ApiService.getStudentClassSchedule(widget.studentId);
      if (!mounted) return;
      if (response['success'] == true && response['data'] != null) {
        setState(() {
          _schedules = response['data'] as List<dynamic>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load class schedule';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Error: ${e.toString()}'; _isLoading = false; });
    }
  }

  void _showScheduleDetails(Map<String, dynamic> schedule) {
    final title = schedule['title'] ?? 'Schedule Details';
    final description = schedule['description'] ?? 'No description';
    final createdAt = schedule['created_at'] ?? '';
    final filePath = schedule['file_path'];
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                  colors: [Color(0xFF6200EE), Color(0xFF6200EE)],
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
                    Text(title,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.white70),
                        SizedBox(width: 6),
                        Text(formattedDate, style: TextStyle(fontSize: 14, color: Colors.white70)),
                        if (formattedTime.isNotEmpty) ...[
                          SizedBox(width: 16),
                          Icon(Icons.access_time, size: 16, color: Colors.white70),
                          SizedBox(width: 6),
                          Text(formattedTime, style: TextStyle(fontSize: 14, color: Colors.white70)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20),
                  child: Text(description,
                      style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.6)),
                ),
              ),
              if (hasPDF) _buildPDFActions(filePath, title),
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
    final fullUrl = ApiService.getFileUrl(filePath);
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
                child: Text('PDF Attachment',
                    style: TextStyle(
                        color: Color(0xFF6200EE), fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(context,
                        MaterialPageRoute(
                          builder: (context) => PDFViewerPage(
                            filePath: fullUrl,
                            title: title,
                            isLocalFile: false,
                          ),
                        ));
                  },
                  icon: Icon(Icons.visibility, size: 20),
                  label: Text('View PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF6200EE),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await DownloadService.downloadFile(
                        url: fullUrl, fileName: fileName, context: context);
                  },
                  icon: Icon(Icons.download, size: 20),
                  label: Text('Download'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF6200EE),
                    side: BorderSide(color: Color(0xFF6200EE)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    return Scaffold(
      backgroundColor: Color(0xFFF5F5F5),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (context) => const DownloadedFilesScreen())),
        backgroundColor: Color(0xFF6200EE),
        icon: Icon(Icons.folder_open),
        label: Text('My Downloads'),
        foregroundColor: Colors.white,
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
            Text('Loading class schedule...', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(_error!, style: TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadSchedules,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF6200EE)),
            ),
          ],
        ),
      );
    }

    if (_schedules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_chart_outlined, size: 80, color: Colors.grey[400]),
            SizedBox(height: 16),
            Text('No Class Schedule Yet',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            SizedBox(height: 8),
            Text('Check back later for your class schedule',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSchedules,
      color: Color(0xFF6200EE),
      child: ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: _schedules.length,
        itemBuilder: (context, index) => _buildScheduleCard(_schedules[index]),
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> schedule) {
    final title = schedule['title'] ?? 'Untitled Schedule';
    final description = schedule['description'] ?? 'No description available';
    final createdAt = schedule['created_at'] ?? '';
    final hasPDF = schedule['file_path'] != null && schedule['file_path'].toString().isNotEmpty;

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
      elevation: 3,
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showScheduleDetails(schedule),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // ✅ Green accent bar on the left
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color(0xFF6200EE),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
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
                          Text('PDF',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF6200EE), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
              SizedBox(height: 8),
              Text(description,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              SizedBox(height: 8),
              Text(formattedDate, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }
}