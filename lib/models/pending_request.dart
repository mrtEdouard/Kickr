class PendingRequest {
  final int userId;
  final String pseudo;
  final String? avatarUrl;
  final String? position;
  final String? preferredFoot;
  final String? level;
  final String? city;
  final String? bio;
  final int matchesPlayed;
  final double averageRating;
  final double presenceRate;
  final String joinedAt;

  const PendingRequest({
    required this.userId,
    required this.pseudo,
    this.avatarUrl,
    this.position,
    this.preferredFoot,
    this.level,
    this.city,
    this.bio,
    required this.matchesPlayed,
    required this.averageRating,
    required this.presenceRate,
    required this.joinedAt,
  });

  factory PendingRequest.fromJson(Map<String, dynamic> json) => PendingRequest(
        userId:        (json['user_id'] as num).toInt(),
        pseudo:        json['pseudo'] as String,
        avatarUrl:     json['avatar_url'] as String?,
        position:      json['position'] as String?,
        preferredFoot: json['preferred_foot'] as String?,
        level:         json['level'] as String?,
        city:          json['city'] as String?,
        bio:           json['bio'] as String?,
        matchesPlayed: (json['matches_played'] as num? ?? 0).toInt(),
        averageRating: (json['average_rating'] as num? ?? 0).toDouble(),
        presenceRate:  (json['presence_rate'] as num? ?? 100).toDouble(),
        joinedAt:      json['joined_at'] as String? ?? '',
      );
}
