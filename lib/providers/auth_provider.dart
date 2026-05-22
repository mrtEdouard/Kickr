import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final _service = AuthService();

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _error;
  bool _loading = false;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get error => _error;
  bool get loading => _loading;
  bool get isLoggedIn => _status == AuthStatus.authenticated;

  Future<void> initialize() async {
    _user = await _service.getCurrentUser();
    _status = _user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _service.login(email: email, password: password);
      _status = AuthStatus.authenticated;
      _loading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Impossible de contacter le serveur.';
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  Future<bool> register(String pseudo, String email, String password, String confirmPassword) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _user = await _service.register(
        pseudo: pseudo,
        email: email,
        password: password,
        confirmPassword: confirmPassword,
      );
      _status = AuthStatus.authenticated;
      _loading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Impossible de contacter le serveur.';
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await _service.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
