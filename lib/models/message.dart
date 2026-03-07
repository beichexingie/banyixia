/// 消息模型
class Message {
  final String id;
  final String senderId;
  final String senderName;
  final String senderAvatar;
  final String content;
  final DateTime time;
  final int unreadCount;
  final MessageType type;

  Message({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar = '',
    required this.content,
    DateTime? time,
    this.unreadCount = 0,
    this.type = MessageType.text,
  }) : time = time ?? DateTime.now();

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName'] ?? json['name'] ?? '',
      senderAvatar: json['senderAvatar'] ?? json['avatar'] ?? '',
      content: json['content'] ?? json['lastMessage'] ?? '',
      time: json['time'] is String
          ? DateTime.tryParse(json['time']) ?? DateTime.now()
          : DateTime.now(),
      unreadCount: json['unreadCount'] ?? json['unread'] ?? 0,
      type: MessageType.values[json['type'] ?? 0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'content': content,
      'time': time.toIso8601String(),
      'unreadCount': unreadCount,
      'type': type.index,
    };
  }

  /// 格式化时间显示
  String get timeLabel {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 2) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}

/// 消息类型枚举
enum MessageType {
  text,   // 文字消息
  image,  // 图片消息
  system, // 系统通知
}
