import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import 'auth_service.dart';

class ChatException implements Exception {
  final String message;
  const ChatException(this.message);
  @override
  String toString() => message;
}

class ChatService {
  static const _base = 'http://localhost:3000';

  Future<String> _token() async {
    final t = await AuthService().getToken();
    if (t == null) throw const ChatException('Non connecté.');
    return t;
  }

  Future<List<Message>> getMessages(int eventId) async {
    final response = await http.get(
      Uri.parse('$_base/events/$eventId/messages'),
      headers: {'Authorization': 'Bearer ${await _token()}'},
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw ChatException(body['error'] as String);
    return (body['messages'] as List)
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Message> sendMessage(int eventId, String content) async {
    final response = await http.post(
      Uri.parse('$_base/events/$eventId/messages'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${await _token()}',
      },
      body: jsonEncode({'content': content}),
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw ChatException(body['error'] as String);
    return Message.fromJson(body['message'] as Map<String, dynamic>);
  }
}
