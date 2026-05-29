class Message {
  final int id;
  final int eventId;
  final int userId;
  final String pseudo;
  final String? avatarUrl;
  final String content;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.pseudo,
    this.avatarUrl,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id:        (json['id'] as num).toInt(),
        eventId:   (json['event_id'] as num).toInt(),
        userId:    (json['user_id'] as num).toInt(),
        pseudo:    json['pseudo'] as String,
        avatarUrl: json['avatar_url'] as String?,
        content:   json['content'] as String,
        createdAt: DateTime.tryParse(
                     (json['created_at'] as String? ?? '').replaceFirst(' ', 'T'),
                   ) ?? DateTime.now(),
      );
}
