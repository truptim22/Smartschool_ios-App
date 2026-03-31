import 'user.dart';

class LoginResponse {
  final bool success;
  final String? message;
  final User? user;
  final Map<String, dynamic>? data;

  LoginResponse({
    required this.success,
    this.message,
    this.user,
    this.data,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    print('🔧 Creating LoginResponse from JSON');
    print('   JSON keys: ${json.keys}');
    print('   is_parent_account: ${json['is_parent_account']}');
    print('   students: ${json['students']}');
    
    return LoginResponse(
      success: json['success'] as bool? ?? false,
      message: json['message'] as String?,
      user: json['user'] != null ? User.fromJson(json['user'] as Map<String, dynamic>) : null,
      data: json, // Store the entire JSON response
    );
  }
  
  // Helper methods
  bool get isParentAccount => data?['is_parent_account'] == true;
  
  List<dynamic> get students {
    final studentsList = data?['students'];
    print('🔍 Getting students: $studentsList');
    if (studentsList == null) return [];
    if (studentsList is! List) return [];
    return studentsList;
  }
}