// ignore_for_file: library_private_types_in_public_api, prefer_const_constructors, use_key_in_widget_constructors
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AttendanceScreen extends StatefulWidget {
  final int studentId;

  AttendanceScreen({required this.studentId});

  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  List<dynamic> attendanceList = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    print('📅 Attendance Screen Loaded for Student ID: ${widget.studentId}');
    fetchAttendance();
  }

  Future<void> fetchAttendance() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await ApiService.getStudentAttendance(widget.studentId);

      if (response['success'] == true) {
        setState(() {
          attendanceList = response['data'] ?? [];
          isLoading = false;
        });
        print('✅ Loaded ${attendanceList.length} attendance records');
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load attendance';
          isLoading = false;
        });
        print('❌ Failed to load attendance: $errorMessage');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading attendance';
        isLoading = false;
      });
      print('❌ Error: $e');
    }
  }

 @override
Widget build(BuildContext context) {
  return Container(  
    color: Color(0xFFF5F5F5),
    child: isLoading
        ? Center(child: CircularProgressIndicator())
        : errorMessage.isNotEmpty
            ? _buildErrorView()
            : attendanceList.isEmpty
                ? _buildEmptyView()
                : _buildAttendanceList(),
  );
}

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            errorMessage,
            style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: fetchAttendance,
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6200EE),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No attendance records found',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
          SizedBox(height: 8),
          Text(
            'Check back later for updates',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceList() {
    // Get today's attendance first
    final today = DateTime.now();
    final todayAttendance = attendanceList.firstWhere(
      (attendance) {
        try {
          final date = DateTime.parse(attendance['date']);
          return date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;
        } catch (e) {
          return false;
        }
      },
      orElse: () => null,
    );

    return RefreshIndicator(
      onRefresh: fetchAttendance,
      child: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Today's Status Card (if exists)
          if (todayAttendance != null) ...[
            _buildTodayStatusCard(todayAttendance),
            SizedBox(height: 24),
          ],

          // Attendance Statistics
          _buildAttendanceStats(),
          SizedBox(height: 24),

          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Attendance History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                '${attendanceList.length} records',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Attendance Records
          ...attendanceList.map((attendance) => _buildAttendanceCard(attendance)).toList(),
        ],
      ),
    );
  }

  Widget _buildTodayStatusCard(Map<String, dynamic> attendance) {
    final status = attendance['status']?.toString().toLowerCase() ?? 'unknown';
    final isPresent = status == 'present';

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPresent
              ? [Color(0xFF4CAF50), Color(0xFF66BB6A)]
              : [Color(0xFFEF5350), Color(0xFFE57373)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isPresent ? Colors.green : Colors.red).withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            isPresent ? Icons.check_circle : Icons.cancel,
            size: 64,
            color: Colors.white,
          ),
          SizedBox(height: 16),
          Text(
            'Today\'s Status',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            isPresent
                ? 'Your child was Present today!'
                : 'Your child was Absent today',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _formatDate(attendance['date']),
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (attendance['class_name'] != null) ...[
            SizedBox(height: 8),
            Text(
              'Class: ${attendance['class_name']}',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttendanceStats() {
    final totalDays = attendanceList.length;
    final presentDays = attendanceList.where((a) => 
      a['status']?.toString().toLowerCase() == 'present'
    ).length;
    final absentDays = totalDays - presentDays;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Total Days', totalDays.toString()),
              _buildStatItem('Present', presentDays.toString()),
              _buildStatItem('Absent', absentDays.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> attendance) {
    final status = attendance['status']?.toString().toLowerCase() ?? 'unknown';
    final isPresent = status == 'present';
    final date = attendance['date'] ?? '';
    final className = attendance['class_name'] ?? 'N/A';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: isPresent ? Color(0xFF4CAF50) : Color(0xFFEF5350),
              width: 4,
            ),
          ),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.all(16),
          leading: Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (isPresent ? Color(0xFF4CAF50) : Color(0xFFEF5350)).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPresent ? Icons.check : Icons.close,
              color: isPresent ? Color(0xFF4CAF50) : Color(0xFFEF5350),
              size: 24,
            ),
          ),
         title: Text(
  isPresent ? 'Present' : 'Absent',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: isPresent ? Color(0xFF4CAF50) : Color(0xFFEF5350),
  ),
),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 6),
                  Text(
                    _formatDate(date),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
              SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.class_, size: 14, color: Colors.grey[600]),
                  SizedBox(width: 6),
                  Text(
                    className,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ],
          ),
       
        ),
      ),
    );
  }

 String _formatDate(String date) {
  try {
    // ✅ Parse as local date, not UTC
    final parts = date.split('T')[0].split('-');
    final dateTime = DateTime(
      int.parse(parts[0]), // year
      int.parse(parts[1]), // month
      int.parse(parts[2]), // day
    );
    
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    return '${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}';
  } catch (e) {
    return date;
  }
}}