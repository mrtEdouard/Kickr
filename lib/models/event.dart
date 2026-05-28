class Event {
  final int id;
  final String title;
  final String type;
  final int creatorId;
  final String? creatorPseudo;
  final String date;
  final String? createdAt;
  final String location;
  final String matchType;
  final int maxPlayers;
  final int participantsCount;
  final String? requiredLevel;
  final String? description;
  final String joinMode;
  final bool isPublic;
  final String status;
  final String? imageUrl;

  const Event({
    required this.id,
    required this.title,
    required this.type,
    required this.creatorId,
    this.creatorPseudo,
    required this.date,
    this.createdAt,
    required this.location,
    required this.matchType,
    required this.maxPlayers,
    required this.participantsCount,
    this.requiredLevel,
    this.description,
    required this.joinMode,
    required this.isPublic,
    required this.status,
    this.imageUrl,
  });

  factory Event.fromJson(Map<String, dynamic> json) => Event(
        id: (json['id'] as num).toInt(),
        title: json['title'] as String,
        type: json['type'] as String,
        creatorId: (json['creator_id'] as num).toInt(),
        creatorPseudo: json['creator_pseudo'] as String?,
        date: json['date'] as String,
        createdAt: json['created_at'] as String?,
        location: json['location'] as String,
        matchType: json['match_type'] as String,
        maxPlayers: (json['max_players'] as num).toInt(),
        participantsCount: (json['participants_count'] as num? ?? 0).toInt(),
        requiredLevel: json['required_level'] as String?,
        description: json['description'] as String?,
        joinMode: json['join_mode'] as String,
        isPublic: json['is_public'] == 1,
        status: json['status'] as String,
        imageUrl: json['image_url'] as String?,
      );
}
