import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notification_item.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final _service = NotificationService();

  List<NotificationItem> _notifications = [];
  int _unreadCount = 0;
  Timer? _timer;

  List<NotificationItem> get notifications => _notifications;
  int get unreadCount => _unreadCount;

  /// Démarre le polling toutes les 30 secondes.
  /// Appelé quand l'utilisateur se connecte.
  void start() {
    _load();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadCount());
  }

  /// Arrête le polling et réinitialise l'état.
  /// Appelé à la déconnexion.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _notifications = [];
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> _load() async {
    try {
      final list = await _service.getNotifications();
      _notifications  = list;
      _unreadCount    = list.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadCount() async {
    try {
      final count = await _service.getUnreadCount();
      if (count != _unreadCount) {
        _unreadCount = count;
        notifyListeners();
        // Si de nouvelles notifs sont arrivées, recharge la liste complète
        if (count > 0) _load();
      }
    } catch (_) {}
  }

  /// Force un rechargement immédiat (ex: après navigation vers l'écran).
  Future<void> refresh() => _load();

  Future<void> markRead(int id) async {
    try {
      await _service.markRead(id);
      _notifications = _notifications
          .map((n) => n.id == id ? n.copyWith(isRead: true) : n)
          .toList();
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _service.markAllRead();
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
      _unreadCount = 0;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
