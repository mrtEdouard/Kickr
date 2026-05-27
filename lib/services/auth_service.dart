import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

// Erreur métier renvoyée par le backend (ex: "email déjà utilisé").
// Distincte des erreurs réseau pour pouvoir afficher le bon message à l'utilisateur.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  static const _base = 'http://localhost:3000';
  static const _tokenKey = 'kickr_auth_token';

  // SharedPreferences = stockage local de l'appareil (persiste entre les lancements).
  // On y stocke le token JWT pour ne pas redemander la connexion à chaque ouverture.

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

  // Méthode partagée pour tous les appels POST afin d'éviter la répétition.
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

  // Appelée au démarrage de l'app pour restaurer la session depuis le token local.
  // Retourne null si le token est absent, expiré, ou si le backend est injoignable.
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

  Future<void> logout() async {
    final token = await getToken();
    if (token != null) {
      try {
        await _post('/auth/logout', {}, token: token);
      } catch (_) {
        // Si le backend est injoignable on déconnecte quand même en local.
      }
    }
    await clearToken();
  }
}
