import 'message.dart';

/// 聊天会话模型
class ChatRoom {
  final String id;
  final List<String> participantIds;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? orderId;
  final DateTime createdAt;

  // 扩展字段：对方信息 (用于UI显示)
  final String? otherParticipantName;
  final String? otherParticipantAvatar;
  final int unreadCount;

  ChatRoom({
    required this.id,
    required this.participantIds,
    this.lastMessage,
    this.lastMessageTime,
    this.orderId,
    required this.createdAt,
    this.otherParticipantName,
    this.otherParticipantAvatar,
    this.unreadCount = 0,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      participantIds: List<String>.from(json['participant_ids'] ?? []),
      lastMessage: json['last_message'],
      lastMessageTime: json['last_message_time'] != null 
          ? DateTime.parse(json['last_message_time']) 
          : null,
      orderId: json['order_id'],
      createdAt: DateTime.parse(json['created_at']),
      unreadCount: json['unread_count'] ?? 0,
    );
  }

  ChatRoom copyWith({
    String? otherParticipantName,
    String? otherParticipantAvatar,
    int? unreadCount,
  }) {
    return ChatRoom(
      id: id,
      participantIds: participantIds,
      lastMessage: lastMessage,
      lastMessageTime: lastMessageTime,
      orderId: orderId,
      createdAt: createdAt,
      otherParticipantName: otherParticipantName ?? this.otherParticipantName,
      otherParticipantAvatar: otherParticipantAvatar ?? this.otherParticipantAvatar,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
