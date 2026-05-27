class Participant {
  final int id;
  final String pseudo;
  final String? avatarUrl;
  final String? position;
  final String? preferredFoot;
  final String status;

  const Participant({
    required this.id,
    required this.pseudo,
    this.avatarUrl,
    this.position,
    this.preferredFoot,
    required this.status,
  });

  factory Participant.fromJson(Map<String, dynamic> json) => Participant(
        id: (json['id'] as num).toInt(),
        pseudo: json['pseudo'] as String,
        avatarUrl: json['avatar_url'] as String?,
        position: json['position'] as String?,
        preferredFoot: json['preferred_foot'] as String?,
        status: json['status'] as String? ?? 'confirmed',
      );
}
