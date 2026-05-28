import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/notification_item.dart';
import 'auth_service.dart';

class NotificationException implements Exception {
  final String message;
  const NotificationException(this.message);
  @override
  String toString() => message;
}

class NotificationService {
  static const _base = 'http://localhost:3000';

  Future<Map<String, String>> _headers() async {
    final token = await AuthService().getToken();
    if (token == null) throw const NotificationException('Non connecté.');
    return {'Authorization': 'Bearer $token'};
  }

  Future<List<NotificationItem>> getNotifications() async {
    final response = await http.get(
      Uri.parse('$_base/notifications'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw NotificationException(body['error'] as String);
    return (body['notifications'] as List)
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final response = await http.get(
      Uri.parse('$_base/notifications/unread-count'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) return 0;
    return (body['count'] as num).toInt();
  }

  Future<void> markRead(int id) async {
    await http.patch(
      Uri.parse('$_base/notifications/$id/read'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 10));
  }

  Future<void> markAllRead() async {
    await http.patch(
      Uri.parse('$_base/notifications/read-all'),
      headers: await _headers(),
    ).timeout(const Duration(seconds: 10));
  }
}
