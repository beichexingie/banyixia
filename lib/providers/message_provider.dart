import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_room.dart';
import '../models/message.dart';
import '../services/ecs_api_client.dart';
import '../services/session_service.dart';

class MessageProvider extends ChangeNotifier {
  final EcsApiClient _api = EcsApiClient();
  final SessionService _sessionService;

  List<ChatRoom> _rooms = [];
  List<Message> _currentRoomMessages = [];
  bool _isLoading = false;
  Timer? _pollTimer;

  List<ChatRoom> get rooms => _rooms;
  List<Message> get currentRoomMessages => _currentRoomMessages;
  bool get isLoading => _isLoading;

  int get totalUnread => _rooms.fold(0, (sum, room) => sum + room.unreadCount);

  MessageProvider({SessionService? sessionService})
      : _sessionService = sessionService ?? EcsSessionService();

  String? _token() => _sessionService.currentSession?.accessToken;

  void _startPolling(String roomId) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      enterRoom(roomId, silent: true);
    });
  }

  Future<void> loadRooms() async {
    final token = _token();
    if (token == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.get('/chat/rooms', authToken: token);
      final data = response['data'];
      if (data is List) {
        _rooms = data
            .whereType<Map<String, dynamic>>()
            .map(ChatRoom.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('Load rooms error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> enterRoom(String roomId, {bool silent = false}) async {
    final token = _token();
    if (token == null) return;
    if (!silent) {
      _currentRoomMessages = [];
      notifyListeners();
    }
    try {
      final response = await _api.get('/chat/rooms/$roomId', authToken: token);
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final messages = data['messages'];
        if (messages is List) {
          _currentRoomMessages = messages
              .whereType<Map<String, dynamic>>()
              .map(Message.fromJson)
              .toList();
          notifyListeners();
        }
      }
      _startPolling(roomId);
      await _markRoomAsRead(roomId);
    } catch (e) {
      debugPrint('Enter room error: $e');
    }
  }

  Future<void> sendMessage(String roomId, String content, {String type = 'text'}) async {
    final token = _token();
    if (token == null) return;
    await _api.post(
      '/chat/rooms/$roomId/messages',
      authToken: token,
      body: {'content': content, 'type': type},
    );
    await enterRoom(roomId);
  }

  void leaveRoom(String roomId) {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<String> getOrCreateRoom(String otherUserId) async {
    final token = _token();
    if (token == null) throw Exception('未登录');
    final response = await _api.post(
      '/chat/rooms',
      authToken: token,
      body: {'other_user_id': otherUserId},
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data['id']?.toString() ?? '';
    }
    throw Exception('无法创建会话');
  }

  Future<String> openCustomerService() async {
    final token = _token();
    if (token == null || token.isEmpty) throw Exception('请先登录');
    final response = await _api.post(
      '/customer-service/session',
      authToken: token,
    );
    final data = response['data'];
    if (data is! Map<String, dynamic>) throw Exception('客服会话创建失败');
    final roomId = data['room_id']?.toString() ?? data['id']?.toString() ?? '';
    if (roomId.isEmpty) throw Exception('客服会话缺少会话编号');
    await loadRooms();
    return roomId;
  }

  Future<void> _markRoomAsRead(String roomId) async {
    final token = _token();
    if (token == null) return;
    await _api.post('/chat/rooms/$roomId/read', authToken: token);
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx != -1) {
      _rooms[idx] = _rooms[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
