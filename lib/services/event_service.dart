import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/event.dart';
import '../models/participant.dart';
import 'auth_service.dart';

class EventException implements Exception {
  final String message;
  const EventException(this.message);
  @override
  String toString() => message;
}

class EventService {
  static const _base = 'http://localhost:3000';

  Future<List<Event>> getEvents() async {
    final response = await http
        .get(Uri.parse('$_base/events'))
        .timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
    final list = body['events'] as List<dynamic>;
    return list.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<String, List<Event>>> getMyEvents() async {
    final token = await AuthService().getToken();
    if (token == null) throw const EventException('Non connecté.');
    final response = await http.get(
      Uri.parse('$_base/events/mine'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
    return {
      'created': (body['created'] as List).map((e) => Event.fromJson(e)).toList(),
      'joined': (body['joined'] as List).map((e) => Event.fromJson(e)).toList(),
    };
  }

  Future<Event> createEvent({
    required String title,
    required String date,
    required String location,
    required String matchType,
    required int maxPlayers,
    String? requiredLevel,
    String? description,
    String joinMode = 'open',
    bool isPublic = true,
  }) async {
    final token = await AuthService().getToken();
    if (token == null) throw const EventException('Tu dois être connecté pour créer un événement.');
    final response = await http.post(
      Uri.parse('$_base/events'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'title': title,
        'date': date,
        'location': location,
        'match_type': matchType,
        'max_players': maxPlayers,
        'required_level': requiredLevel,
        'description': description,
        'join_mode': joinMode,
        'is_public': isPublic ? 1 : 0,
      }),
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
    return Event.fromJson(body['event'] as Map<String, dynamic>);
  }

  // Retourne le message de confirmation ou lance une EventException.
  Future<String> joinEvent(int eventId) async {
    final token = await AuthService().getToken();
    if (token == null) throw const EventException('Tu dois être connecté pour rejoindre un match.');
    final response = await http.post(
      Uri.parse('$_base/events/$eventId/join'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
    return body['message'] as String;
  }

  Future<List<Participant>> getParticipants(int eventId) async {
    final token = await AuthService().getToken();
    if (token == null) throw const EventException('Non connecté.');
    final response = await http.get(
      Uri.parse('$_base/events/$eventId/participants'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
    return (body['participants'] as List).map((e) => Participant.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Map<int, int>> getComposition(int eventId) async {
    final token = await AuthService().getToken();
    if (token == null) throw const EventException('Non connecté.');
    final response = await http.get(
      Uri.parse('$_base/events/$eventId/composition'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
    final raw = body['composition'] as Map<String, dynamic>;
    return raw.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
  }

  Future<void> saveComposition(int eventId, Map<int, int> assignments) async {
    final token = await AuthService().getToken();
    if (token == null) throw const EventException('Non connecté.');
    final response = await http.put(
      Uri.parse('$_base/events/$eventId/composition'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'assignments': assignments.map((k, v) => MapEntry(k.toString(), v))}),
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
  }

  Future<Map<int, int>> randomizeComposition(int eventId) async {
    final token = await AuthService().getToken();
    if (token == null) throw const EventException('Non connecté.');
    final response = await http.post(
      Uri.parse('$_base/events/$eventId/composition/random'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
    final raw = body['composition'] as Map<String, dynamic>;
    return raw.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
  }
}
