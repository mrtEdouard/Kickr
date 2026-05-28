/// Représente un joueur inscrit à un événement.
/// Utilisé pour afficher la composition des équipes dans [EventDetailScreen].
class Participant {
  /// Identifiant unique du joueur (correspond à users.id en base).
  final int id;

  /// Pseudo affiché dans l'interface.
  final String pseudo;

  /// URL relative de l'avatar (ex: /uploads/avatars/photo.jpg). Null si aucun avatar.
  final String? avatarUrl;

  /// Poste du joueur : 'goalkeeper' | 'defender' | 'midfielder' | 'forward'. Nullable.
  final String? position;

  /// Pied préféré : 'left' | 'right' | 'both'. Nullable.
  final String? preferredFoot;

  /// Statut de la participation : 'confirmed' | 'pending' | 'refused'.
  final String status;

  const Participant({
    required this.id,
    required this.pseudo,
    this.avatarUrl,
    this.position,
    this.preferredFoot,
    required this.status,
  });

  /// Construit un [Participant] depuis un objet JSON renvoyé par l'API.
  /// Le champ [status] est défini à 'confirmed' par défaut si absent.
  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        id: (json['id'] as num).toInt(),
        pseudo: json['pseudo'] as String,
        avatarUrl: json['avatar_url'] as String?,
        position: json['position'] as String?,
        preferredFoot: json['preferred_foot'] as String?,
        status: json['status'] as String? ?? 'confirmed',
      );
}
