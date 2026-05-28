import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/event_service.dart';

// Les différents états possibles du chargement des events
enum EventStatus { unknown, loaded, loading, error }

// Le "cerveau" des événements : il stocke toutes les données
// et prévient l'UI à chaque changement via notifyListeners().
class EventProvider extends ChangeNotifier {
  final _service = EventService();

  EventStatus _status = EventStatus.unknown;
  List<Event> _events = [];      // tous les matchs publics (accueil)
  List<Event> _myCreated = [];   // matchs que j'ai créés
  List<Event> _myJoined = [];    // matchs que j'ai rejoints
  String? _error;
  bool _loading = false;

  EventStatus get status => _status;
  List<Event> get events => _events;
  List<Event> get myCreated => _myCreated;
  List<Event> get myJoined => _myJoined;
  String? get error => _error;
  bool get loading => _loading;

  // La liste des IDs des matchs rejoints, calculée à partir de _myJoined.
  // On ne la stocke pas séparément pour éviter qu'elle se désynchronise.
  Set<int> get joinedIds => _myJoined.map((e) => e.id).toSet();

  // Remet tout à zéro quand l'utilisateur se déconnecte.
  // Sans ça, les données du compte précédent resteraient visibles.
  void reset() {
    _myCreated = [];
    _myJoined = [];
    _error = null;
    notifyListeners();
  }

  // Charge tous les matchs publics — affiché sur la page d'accueil.
  Future<void> loadEvents() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _events = await _service.getEvents();
      _status = EventStatus.loaded;
      _error = null; // efface toute erreur résiduelle d'une opération concurrente
    } on EventException catch (e) {
      _error = e.message;
      _status = EventStatus.error;
    } catch (_) {
      _error = 'Impossible de contacter le serveur.';
      _status = EventStatus.error;
    }
    _loading = false;
    notifyListeners();
  }

  // Charge les matchs de l'utilisateur connecté (créés + rejoints).
  // Appelé à l'ouverture de l'onglet "Mes matchs".
  Future<void> loadMyEvents() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _service.getMyEvents();
      _myCreated = result['created']!;
      _myJoined = result['joined']!;
    } on EventException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Impossible de contacter le serveur.';
    }
    _loading = false;
    notifyListeners();
  }

  // Crée un nouveau match et l'ajoute directement aux deux listes
  // (accueil + mes matchs) sans avoir à recharger depuis le serveur.
  Future<bool> createEvent({
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
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final event = await _service.createEvent(
        title: title, date: date, location: location,
        matchType: matchType, maxPlayers: maxPlayers,
        requiredLevel: requiredLevel, description: description,
        joinMode: joinMode, isPublic: isPublic,
      );
      _events.insert(0, event);
      _myCreated.insert(0, event);
      _loading = false;
      notifyListeners();
      return true;
    } on EventException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Impossible de contacter le serveur.';
    }
    _loading = false;
    notifyListeners();
    return false;
  }

  // Rejoint un match. Retourne le message de confirmation (ex: "Tu as rejoint le match !")
  // ou null si ça a échoué (l'erreur est alors dans _error).
  Future<String?> joinEvent(int eventId) async {
    try {
      final message = await _service.joinEvent(eventId);

      // On incrémente le compteur de participants localement
      // pour que l'UI se mette à jour sans attendre un rechargement.
      _events = _events.map((e) {
        if (e.id != eventId) return e;
        return Event.fromJson({
          'id': e.id, 'title': e.title, 'type': e.type,
          'creator_id': e.creatorId, 'date': e.date, 'location': e.location,
          'match_type': e.matchType, 'max_players': e.maxPlayers,
          // Seul un join en mode 'open' crée un participant confirmé côté serveur.
          // En mode 'validation' le statut est 'pending' → ne compte pas dans les places.
          'participants_count': e.joinMode == 'open' ? e.participantsCount + 1 : e.participantsCount,
          'required_level': e.requiredLevel, 'description': e.description,
          'join_mode': e.joinMode, 'is_public': e.isPublic ? 1 : 0,
          'status': e.status,
        });
      }).toList();

      // On l'ajoute à myJoined pour que le bouton passe à "Inscrit ✓"
      // et qu'il apparaisse dans l'onglet "Mes matchs" immédiatement.
      final joined = _events.firstWhere((e) => e.id == eventId);
      if (!_myJoined.any((e) => e.id == eventId)) {
        _myJoined.add(joined);
      }

      notifyListeners();
      return message;
    } on EventException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    } catch (_) {
      _error = 'Impossible de contacter le serveur.';
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
