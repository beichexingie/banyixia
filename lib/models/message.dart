/// 消息模型
class Message {
  final String id;
  final String roomId;
  final String senderId;
  final String content;
  final String type; // text, image, order_card
  final bool isRead;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.content,
    this.type = 'text',
    this.isRead = false,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      roomId: json['room_id'],
      senderId: json['sender_id'],
      content: json['content'],
      type: json['type'] ?? 'text',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'room_id': roomId,
      'sender_id': senderId,
      'content': content,
      'type': type,
    };
  }

  bool get isSystem => senderId == 'system';
  
  String get timeLabel {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${createdAt.hour}:${createdAt.minute.toString().padLeft(2, "0")}';
    return '${createdAt.month}/${createdAt.day}';
  }
}

/// 消息类型枚举
enum MessageType {
  text,   // 文字消息
  image,  // 图片消息
  system, // 系统通知
}
