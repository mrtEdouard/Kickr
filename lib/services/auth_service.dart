import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  static const _base = 'http://localhost:3000';
  static const _tokenKey = 'kickr_auth_token';

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {String? token}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final response = await http
        .post(Uri.parse('$_base$path'), headers: headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<User> register({
    required String pseudo,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    final body = await _post('/auth/register', {
      'pseudo': pseudo,
      'email': email,
      'password': password,
      'confirmPassword': confirmPassword,
    });
    if (body.containsKey('error')) throw AuthException(body['error'] as String);
    await _saveToken(body['token'] as String);
    return User.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<User> login({required String email, required String password}) async {
    final body = await _post('/auth/login', {'email': email, 'password': password});
    if (body.containsKey('error')) throw AuthException(body['error'] as String);
    await _saveToken(body['token'] as String);
    return User.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<User?> getCurrentUser() async {
    final token = await getToken();
    if (token == null) return null;
    try {
      final response = await http.get(
        Uri.parse('$_base/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return User.fromJson(body['user'] as Map<String, dynamic>);
      }
      await clearToken();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<User> updateProfile({
    required String pseudo,
    String? firstName,
    String? lastName,
    String? city,
    String? nationality,
    String? position,
    String? preferredFoot,
    String? bio,
  }) async {
    final token = await getToken();
    final response = await http
        .patch(
          Uri.parse('$_base/auth/profile'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'pseudo': pseudo,
            'first_name': firstName,
            'last_name': lastName,
            'city': city,
            'nationality': nationality,
            'position': position,
            'preferred_foot': preferredFoot,
            'bio': bio,
          }),
        )
        .timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw AuthException(body['error'] as String);
    return User.fromJson(body['user'] as Map<String, dynamic>);
  }

  Future<String> uploadAvatar(Uint8List bytes, String filename) async {
    final token = await getToken();
    final request = http.MultipartRequest('POST', Uri.parse('$_base/auth/avatar'));
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(http.MultipartFile.fromBytes('avatar', bytes, filename: filename));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final body = jsonDecode(await streamed.stream.bytesToString()) as Map<String, dynamic>;
    if (body.containsKey('error')) throw AuthException(body['error'] as String);
    return body['avatar_url'] as String;
  }

  Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      try {
        await _post('/auth/logout', {}, token: token);
      } catch (_) {}
    }
    await clearToken();
  }
}
