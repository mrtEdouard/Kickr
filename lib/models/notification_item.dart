class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id:        (json['id'] as num).toInt(),
        type:      json['type'] as String,
        title:     json['title'] as String,
        body:      json['body'] as String,
        data:      (json['data'] as Map<String, dynamic>?) ?? {},
        isRead:    json['is_read'] == true || json['is_read'] == 1,
        createdAt: DateTime.tryParse(
                     (json['created_at'] as String? ?? '').replaceFirst(' ', 'T'),
                   ) ?? DateTime.now(),
      );

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id, type: type, title: title, body: body,
        data: data, createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );
}
