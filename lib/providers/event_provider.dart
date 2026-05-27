import 'package:flutter/material.dart';
import '../models/event.dart';
import '../services/event_service.dart';

enum EventStatus { unknown, loaded, loading, error }

class EventProvider extends ChangeNotifier {
  final _service = EventService();

  EventStatus _status = EventStatus.unknown;
  List<Event> _events = [];
  String? _error;
  bool _loading = false;

  EventStatus get status => _status;
  List<Event> get events => _events;
  String? get error => _error;
  bool get loading => _loading;

  Future<void> loadEvents() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _events = await _service.getEvents();
      _status = EventStatus.loaded;
      _loading = false;
      notifyListeners();
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
      title: title,
      date: date,
      location: location,
      matchType: matchType,
      maxPlayers: maxPlayers,
      requiredLevel: requiredLevel,
      description: description,
      joinMode: joinMode,
      isPublic: isPublic,
    );
    _events.insert(0, event); // on l'ajoute en tête de liste
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

}


  
