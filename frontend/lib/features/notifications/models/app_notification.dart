import 'dart:convert';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // 'ambient', 'face', 'daily', 'system'
  final DateTime timestamp;
  bool isRead;
  final String? payload;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.payload,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'type': type,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'payload': payload,
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'system',
      timestamp: map['timestamp'] != null ? DateTime.tryParse(map['timestamp']) ?? DateTime.now() : DateTime.now(),
      isRead: map['isRead'] ?? false,
      payload: map['payload'],
    );
  }

  String toJson() => json.encode(toMap());

  factory AppNotification.fromJson(String source) => AppNotification.fromMap(json.decode(source));
}
