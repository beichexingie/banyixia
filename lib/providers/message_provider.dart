import 'package:flutter/material.dart';
import '../models/message.dart';

/// 消息状态管理
class MessageProvider extends ChangeNotifier {
  List<Message> _messages = [];
  bool _isLoading = false;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;

  /// 总未读数
  int get totalUnread =>
      _messages.fold(0, (sum, msg) => sum + msg.unreadCount);

  /// 加载消息列表（后续替换为 API 调用）
  Future<void> loadMessages() async {
    _isLoading = true;
    notifyListeners();

    // TODO: 替换为真实 API 调用
    await Future.delayed(const Duration(milliseconds: 300));

    _messages = [
      Message(
        id: 'm1',
        senderId: 'system',
        senderName: '系统通知',
        senderAvatar: 'https://picsum.photos/seed/sys1/100/100',
        content: '欢迎加入伴一下！开启您的旅行社交之旅',
        time: DateTime.now(),
        unreadCount: 1,
        type: MessageType.system,
      ),
      Message(
        id: 'm2',
        senderId: 'helper',
        senderName: '小助手',
        senderAvatar: 'https://picsum.photos/seed/helper/100/100',
        content: '您好，有什么可以帮您的吗？',
        time: DateTime.now().subtract(const Duration(hours: 2)),
        unreadCount: 0,
      ),
      Message(
        id: 'm3',
        senderId: 'u3',
        senderName: '旅行达人',
        senderAvatar: 'https://picsum.photos/seed/traveler/100/100',
        content: '明天的行程已经为您安排好了！',
        time: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: 3,
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }

  /// 标记消息已读
  void markAsRead(String messageId) {
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      _messages[index] = Message(
        id: _messages[index].id,
        senderId: _messages[index].senderId,
        senderName: _messages[index].senderName,
        senderAvatar: _messages[index].senderAvatar,
        content: _messages[index].content,
        time: _messages[index].time,
        unreadCount: 0,
        type: _messages[index].type,
      );
      // TODO: 调用 API 同步已读状态
      notifyListeners();
    }
  }
}
