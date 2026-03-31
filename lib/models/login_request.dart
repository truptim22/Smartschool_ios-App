class LoginRequest {
  final String username;
  final String password;

  LoginRequest({
    required this.username,
    required this.password,
  });

  // Convert to JSON for API
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
    };
  }
}