// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/user.dart';

class ApiService {
  static const String baseUrl = 'https://lantechschools.org/api';

  static String getFileUrl(String? filePath) {
    if (filePath == null || filePath.isEmpty) return '';
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) return filePath;
    final cleanPath = filePath.startsWith('/') ? filePath.substring(1) : filePath;
    return 'https://lantechschools.org/$cleanPath';
  }

  static Future<LoginResponse> login(LoginRequest request) async {
    try {
      print('🌐 Calling API: $baseUrl/login');
      print('   Username: ${request.username}');

    final response = await http.post(
  Uri.parse('$baseUrl/login'),
  headers: {'Content-Type': 'application/json'},
  body: json.encode(request.toJson()),
).timeout(
  const Duration(seconds: 15),
  onTimeout: () => http.Response('{"success":false,"message":"Login timed out. Check your connection."}', 408),
);
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('📦 Parsed data: $data');
        print('   is_parent_account: ${data['is_parent_account']}');
        print('   students: ${data['students']}');
        return LoginResponse.fromJson(data);
      } else {
        final data = json.decode(response.body);
        return LoginResponse(
          success: false,
          message: data['message'] ?? 'Login failed',
        );
      }
    } catch (e, stackTrace) {
      print('❌ API Error: $e');
      print('Stack trace: $stackTrace');
      return LoginResponse(success: false, message: 'Network error: $e');
    }
  }

  // ========================================
  // PROFILE API
  // ========================================
  static Future<Map<String, dynamic>> getStudentProfile(int studentId) async {
    try {
      print('📱 Fetching profile for user ID: $studentId');

      // ✅ FIX: Add timestamp to bust any HTTP cache layer
      final uri = Uri.parse('$baseUrl/student/profile/$studentId')
          .replace(queryParameters: {'_t': DateTime.now().millisecondsSinceEpoch.toString()});

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          // ✅ FIX: Tell every cache layer (proxy, CDN, Android) not to cache this
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      print('📥 Profile Response Status: ${response.statusCode}');
      print('📥 Profile Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          final profileData = data['data'];

          // Normalize profile_photo to full URL
          if (profileData != null && profileData['profile_photo'] != null) {
            final originalPhotoPath = profileData['profile_photo'];
            final photoUrl = getFileUrl(originalPhotoPath);
            print('📸 Original photo path: $originalPhotoPath');
            print('📸 Converted photo URL: $photoUrl');
            profileData['profile_photo_url'] = photoUrl;
          }

          return {
            'success': true,
            'data': profileData,
            'message': data['message'] ?? 'Profile loaded successfully'
          };
        }

        return data;
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Student profile not found', 'data': null};
      } else {
        return {
          'success': false,
          'message': 'Failed to load profile (${response.statusCode})',
          'data': null,
        };
      }
    } catch (e) {
      print('❌ Profile error: $e');
      return {'success': false, 'message': 'Error loading profile: ${e.toString()}', 'data': null};
    }
  }

  // ========================================
  // UPDATE PROFILE
  // ========================================
  static Future<Map<String, dynamic>> updateStudentProfile(
    int userId, {
    String? email,
    String? address,
    String? phone,
    String? bloodGroup,
    String? parentPhone,
    String? parentEmail,
  }) async {
    try {
      print('✏️ Updating profile for user ID: $userId');

      final Map<String, dynamic> body = {};
      body['phone']       = phone ?? '';
body['address']     = address ?? '';
body['bloodGroup']  = bloodGroup ?? '';
body['parentPhone'] = parentPhone ?? '';
body['parentEmail'] = parentEmail ?? '';
body['email']       = email ?? '';   
      print('✏️ Update payload: $body');

      final response = await http.put(
        Uri.parse('$baseUrl/student/profile/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Cache-Control': 'no-cache',
        },
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      print('✏️ Update Response Status: ${response.statusCode}');
      print('✏️ Update Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? 'Profile updated successfully'
        };
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Student profile not found', 'data': null};
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to update profile (${response.statusCode})',
          'data': null,
        };
      }
    } catch (e) {
      print('❌ Update error: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}', 'data': null};
    }
  }

  // ========================================
  // PROFILE PHOTO
  // ========================================
  static Future<Map<String, dynamic>> updateStudentProfileWithPhoto(
    int userId,
    String photoPath, {
    String? email,
    String? address,
    String? phone,
    String? bloodGroup,
    String? parentPhone,
    String? parentEmail,
  }) async {
    try {
      print('📷 Updating profile with photo for user ID: $userId');

      var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/student/profile/$userId'));
      var file = await http.MultipartFile.fromPath('photo', photoPath);
      request.files.add(file);

      if (email != null && email.isNotEmpty) request.fields['email'] = email;
      if (address != null && address.isNotEmpty) request.fields['address'] = address;
      if (phone != null && phone.isNotEmpty) request.fields['phone'] = phone;
      if (bloodGroup != null && bloodGroup.isNotEmpty) request.fields['bloodGroup'] = bloodGroup;
      if (parentPhone != null && parentPhone.isNotEmpty) request.fields['parentPhone'] = parentPhone;
      if (parentEmail != null && parentEmail.isNotEmpty) request.fields['parentEmail'] = parentEmail;

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Upload timeout'),
      );

      final response = await http.Response.fromStream(streamedResponse);
      print('📷 Update Response Status: ${response.statusCode}');
      print('📷 Update Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'] ?? 'Profile updated successfully'
        };
      } else {
        final errorData = json.decode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to update profile',
          'data': null,
        };
      }
    } catch (e) {
      print('❌ Update error: $e');
      return {'success': false, 'message': 'Error: ${e.toString()}', 'data': null};
    }
  }

  // ========================================
  // ASSIGNMENTS API
  // ========================================
  static Future<Map<String, dynamic>> getStudentAssignments(int studentId) async {
    try {
      print('📚 Fetching assignments for student ID: $studentId');

    final response = await http.get(
  Uri.parse('$baseUrl/student/assignments/$studentId'),
  headers: {'Content-Type': 'application/json'},
).timeout(
  const Duration(seconds: 15),
  onTimeout: () => http.Response('{"success":false,"message":"Request timed out","data":[]}', 408),
);

      print('📚 Assignments Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to load assignments (${response.statusCode})',
          'data': [],
        };
      }
    } catch (e) {
      print('❌ Assignments error: $e');
      return {'success': false, 'message': 'Error loading assignments: ${e.toString()}', 'data': []};
    }
  }

  // ========================================
  // ATTENDANCE API
  // ========================================
  static Future<Map<String, dynamic>> getStudentAttendance(int studentId) async {
    try {
      print('📋 Fetching attendance for student ID: $studentId');

      final response = await http.get(
        Uri.parse('$baseUrl/student/attendance/$studentId'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      print('📋 Attendance Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return {
          'success': true,
          'data': data['data'] ?? [],
          'message': data['message'] ?? 'Attendance loaded successfully'
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to load attendance (${response.statusCode})',
          'data': [],
        };
      }
    } catch (e) {
      print('❌ Attendance error: $e');
      return {'success': false, 'message': 'Error loading attendance: ${e.toString()}', 'data': []};
    }
  }

  // ========================================
  // NOTIFICATIONS API
  // ========================================
  static Future<Map<String, dynamic>> getStudentNotifications(int studentId) async {
    try {
      print('🔔 Fetching notifications for student ID: $studentId');

     final response = await http.get(
  Uri.parse('$baseUrl/student/notifications/$studentId'),
  headers: {'Content-Type': 'application/json'},
).timeout(
  const Duration(seconds: 15),
  onTimeout: () => http.Response('{"success":false,"message":"Request timed out","data":[]}', 408),
);

      print('🔔 Notifications Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        return {
          'success': false,
          'message': 'Failed to load notifications (${response.statusCode})',
          'data': [],
        };
      }
    } catch (e) {
      print('❌ Notifications error: $e');
      return {'success': false, 'message': 'Error loading notifications: ${e.toString()}', 'data': []};
    }
  }

  // ========================================
  // TIMETABLE API
  // ========================================
  static Future<Map<String, dynamic>> getStudentTimetable(int studentId) async {
    try {
      final url = '$baseUrl/student/timetable/$studentId';
      print('📅 Fetching timetable: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception('Connection timeout'),
      );

      print('📅 Timetable Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return {
            'success': true,
            'data': data['data'] ?? [],
            'message': data['message'] ?? 'Timetable loaded successfully'
          };
        } else {
          return {'success': false, 'message': data['message'] ?? 'Failed to load timetable', 'data': []};
        }
      } else if (response.statusCode == 404) {
        return {'success': false, 'message': 'Timetable endpoint not found: $url', 'data': []};
      } else {
        return {'success': false, 'message': 'Server error (${response.statusCode})', 'data': []};
      }
    } catch (e) {
      print('❌ Timetable error: $e');
      String errorMsg;
      if (e.toString().contains('SocketException')) {
        errorMsg = 'Cannot connect to server at $baseUrl';
      } else if (e.toString().contains('TimeoutException')) {
        errorMsg = 'Connection timeout. Server might be slow or unreachable.';
      } else {
        errorMsg = 'Error: ${e.toString()}';
      }
      return {'success': false, 'message': errorMsg, 'data': []};
    }
  }
static Future<Map<String, dynamic>> getStudentClassSchedule(int studentId) async {
  try {
    final url = '$baseUrl/student/class-schedule/$studentId';
    print('📅 Fetching class schedule: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    ).timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception('Connection timeout'),
    );

    print('📅 Class Schedule Response Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return {
          'success': true,
          'data': data['data'] ?? [],
          'message': data['message'] ?? 'Schedule loaded successfully'
        };
      } else {
        return {'success': false, 'message': data['message'] ?? 'Failed to load schedule', 'data': []};
      }
    } else if (response.statusCode == 404) {
      return {'success': false, 'message': 'No schedule found', 'data': []};
    } else {
      return {'success': false, 'message': 'Server error (${response.statusCode})', 'data': []};
    }
  } catch (e) {
    print('❌ Class schedule error: $e');
    return {'success': false, 'message': 'Error: ${e.toString()}', 'data': []};
  }
}
static Future<Map<String, dynamic>> getStudentResult(int studentId) async {
  try {
    final url = '$baseUrl/student/result/$studentId';
    print('📊 Fetching result: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));

    print('📊 Result Response: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['success'] == true
          ? {'success': true, 'data': data}
          : {'success': false, 'message': data['message'] ?? 'No result found'};
    } else if (response.statusCode == 404) {
      return {'success': false, 'message': 'No marks uploaded yet for your class.'};
    } else {
      return {'success': false, 'message': 'Server error (${response.statusCode})'};
    }
  } catch (e) {
    return {'success': false, 'message': 'Error: $e'};
  }
}

}