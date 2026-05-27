class User {
  final int id;
  final String pseudo;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? city;
  final String? nationality;
  final String? position;
  final String? preferredFoot;
  final String? bio;
  final int matchesPlayed;
  final double averageRating;
  final double presenceRate;

  const User({
    required this.id,
    required this.pseudo,
    required this.email,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.city,
    this.nationality,
    this.position,
    this.preferredFoot,
    this.bio,
    this.matchesPlayed = 0,
    this.averageRating = 0.0,
    this.presenceRate = 100.0,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: (json['id'] as num).toInt(),
        pseudo: json['pseudo'] as String,
        email: json['email'] as String,
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        city: json['city'] as String?,
        nationality: json['nationality'] as String?,
        position: json['position'] as String?,
        preferredFoot: json['preferred_foot'] as String?,
        bio: json['bio'] as String?,
        matchesPlayed: (json['matches_played'] as num? ?? 0).toInt(),
        averageRating: (json['average_rating'] as num? ?? 0.0).toDouble(),
        presenceRate: (json['presence_rate'] as num? ?? 100.0).toDouble(),
      );

  User copyWith({String? avatarUrl}) => User(
        id: id,
        pseudo: pseudo,
        email: email,
        firstName: firstName,
        lastName: lastName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        city: city,
        nationality: nationality,
        position: position,
        preferredFoot: preferredFoot,
        bio: bio,
        matchesPlayed: matchesPlayed,
        averageRating: averageRating,
        presenceRate: presenceRate,
      );
}
