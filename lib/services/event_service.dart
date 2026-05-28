import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/event.dart';
import '../models/participant.dart';
import '../models/pending_request.dart';
import 'auth_service.dart';

/// Exception métier levée lors d'une erreur retournée par l'API événements.
/// Le [message] est directement affiché à l'utilisateur via SnackBar.
class EventException implements Exception {
  final String message;
  const EventException(this.message);
  @override
  String toString() => message;
}

/// Service d'accès à l'API REST pour tout ce qui concerne les événements.
/// Chaque méthode effectue un appel HTTP avec un timeout de 10 secondes
/// et lève une [EventException] si le serveur retourne un champ "error".
class EventService {
  static const _base = 'http://localhost:3000';

  /// Récupère la liste des événements publics dont la date est future.
  /// Endpoint : GET /events (pas d'authentification requise).
  Future<List<Event>> getEvents() async {
    final response = await http
        .get(Uri.parse('$_base/events'))
        .timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
    final list = body['events'] as List<dynamic>;
    return list.map((e) => Event.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Récupère les événements de l'utilisateur connecté :
  /// - 'created' : matchs dont il est l'organisateur.
  /// - 'joined'  : matchs qu'il a rejoint (statut confirmed ou pending).
  /// Endpoint : GET /events/mine (token JWT requis).
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

  /// Crée un nouvel événement pour l'utilisateur connecté.
  /// Le créateur est automatiquement inscrit en tant que participant confirmé côté serveur.
  /// Endpoint : POST /events (token JWT requis).
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

  /// Inscrit l'utilisateur connecté à l'événement [eventId].
  /// Retourne le message de confirmation du serveur ('Tu as rejoint le match !'
  /// ou 'Demande envoyée, en attente de validation.' selon le join_mode).
  /// Endpoint : POST /events/:id/join (token JWT requis).
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

  /// Retourne la liste des participants confirmés d'un événement,
  /// avec leurs informations de profil (pseudo, avatar, poste, pied préféré).
  /// Endpoint : `GET /events/:id/participants` (token JWT requis).
  Future<List<Participant>> getParticipants(int eventId) async {
    final token = await AuthService().getToken();
    if (token == null) throw const EventException('Non connecté.');
    final response = await http.get(
      Uri.parse('$_base/events/$eventId/participants'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
    return (body['participants'] as List)
        .map((e) => Participant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Retourne la composition actuelle de l'événement sous forme de `Map<userId, équipe>`.
  /// L'équipe est un entier : 1 = Équipe 1, 2 = Équipe 2.
  /// Les clés JSON sont des strings (contrainte JSON) : on les convertit en int.
  /// Endpoint : `GET /events/:id/composition` (token JWT requis).
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
    // JSON force les clés en String : on convertit chaque clé en int
    return raw.map((k, v) => MapEntry(int.parse(k), (v as num).toInt()));
  }

  /// Sauvegarde la composition manuelle définie par l'organisateur.
  /// [assignments] : `Map<userId, équipe>` où l'équipe vaut 1 ou 2.
  /// Les clés sont reconverties en String pour la sérialisation JSON.
  /// Endpoint : PUT /events/:id/composition (token JWT requis, organisateur uniquement).
  Future<void> saveComposition(int eventId, Map<int, int> assignments) async {
    final token = await AuthService().getToken();
    if (token == null) throw const EventException('Non connecté.');
    final response = await http.put(
      Uri.parse('$_base/events/$eventId/composition'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'assignments': assignments.map((k, v) => MapEntry(k.toString(), v)),
      }),
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
  }

  /// Déclenche un tirage au sort côté serveur (algorithme Fisher-Yates).
  /// Le serveur répartit aléatoirement les participants en deux équipes
  /// selon la taille déduite du match_type (ex: '5v5' → 5 par équipe).
  /// Retourne la nouvelle composition sous forme de `Map<userId, équipe>`.
  /// Endpoint : POST /events/:id/composition/random (token JWT requis, organisateur uniquement).
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

  /// Retire un participant confirmé de l'événement.
  /// Endpoint : DELETE /events/:id/participants/:userId (token JWT requis, organisateur uniquement).
  Future<void> removeParticipant(int eventId, int userId) async {
    final token = await AuthService().getToken();
    if (token == null) throw const EventException('Non connecté.');
    final response = await http.delete(
      Uri.parse('$_base/events/$eventId/participants/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
  }

  /// Retourne les demandes de participation en attente avec le profil du demandeur.
  /// Endpoint : GET /events/:id/requests (token JWT requis, organisateur uniquement).
  Future<List<PendingRequest>> getPendingRequests(int eventId) async {
    final token = await AuthService().getToken();
    if (token == null) throw const EventException('Non connecté.');
    final response = await http.get(
      Uri.parse('$_base/events/$eventId/requests'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
    return (body['requests'] as List)
        .map((e) => PendingRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Accepte ou refuse une demande de participation.
  /// [action] : 'accept' ou 'reject'.
  /// Endpoint : PATCH /events/:id/requests/:userId (token JWT requis, organisateur uniquement).
  Future<void> respondToRequest(int eventId, int userId, String action) async {
    final token = await AuthService().getToken();
    if (token == null) throw const EventException('Non connecté.');
    final response = await http.patch(
      Uri.parse('$_base/events/$eventId/requests/$userId'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'action': action}),
    ).timeout(const Duration(seconds: 10));
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
  }

  /// Upload ou remplace la photo de couverture de l'événement.
  /// Retourne l'URL relative de l'image stockée sur le serveur.
  /// Endpoint : POST /events/:id/image (token JWT requis, organisateur uniquement).
  Future<String> uploadEventImage(int eventId, File imageFile) async {
    final token = await AuthService().getToken();
    if (token == null) throw const EventException('Non connecté.');
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/events/$eventId/image'),
    )
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    final streamed = await request.send().timeout(const Duration(seconds: 30));
    final body = jsonDecode(await streamed.stream.bytesToString()) as Map<String, dynamic>;
    if (body.containsKey('error')) throw EventException(body['error'] as String);
    return body['image_url'] as String;
  }
}
