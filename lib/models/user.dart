
class User {
  final int id;
  final String username;
  final String? email;
  final String role;
  final int? studentId;
  final String? firstName;
  final String? lastName;
  final String? rollNumber;
  final int? classId;
  final String? className;    
  final String? sectionName;  

  User({
    required this.id,
    required this.username,
    this.email,
    required this.role,
    this.studentId,
    this.firstName,
    this.lastName,
    this.rollNumber,
    this.classId,
    this.className,      // ✅ ADD THIS
    this.sectionName,    // ✅ ADD THIS
  });

  // ✅ Update fromJson to include new fields
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      role: json['role'],
      studentId: json['studentId'],
      firstName: json['firstName'],
      lastName: json['lastName'],
      rollNumber: json['rollNumber'],
      classId: json['classId'],
      className: json['className'],      // ✅ ADD THIS
      sectionName: json['sectionName'],  // ✅ ADD THIS
    );
  }

  // ✅ Update toJson to include new fields
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'studentId': studentId,
      'firstName': firstName,
      'lastName': lastName,
      'rollNumber': rollNumber,
      'classId': classId,
      'className': className,      // ✅ ADD THIS
      'sectionName': sectionName,  // ✅ ADD THIS
    };
  }
  bool isValid() => id > 0 && username.isNotEmpty;
  String getFullName() => '${firstName ?? ''} ${lastName ?? ''}'.trim();
  @override
  String toString() {
    return 'User(id: $id, username: $username, firstName: $firstName, lastName: $lastName, className: $className, sectionName: $sectionName)';
  }
}

