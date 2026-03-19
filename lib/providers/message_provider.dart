import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/message.dart';
import '../models/chat_room.dart';

class MessageProvider extends ChangeNotifier {
  final _client = supabase.Supabase.instance.client;
  
  List<ChatRoom> _rooms = [];
  List<Message> _currentRoomMessages = [];
  bool _isLoading = false;
  
  supabase.RealtimeChannel? _messageSubscription;

  List<ChatRoom> get rooms => _rooms;
  List<Message> get currentRoomMessages => _currentRoomMessages;
  bool get isLoading => _isLoading;

  int get totalUnread => _rooms.fold(0, (sum, room) => sum + room.unreadCount);

  /// 加载会话列表
  Future<void> loadRooms() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _client
          .from('chat_rooms')
          .select()
          .contains('participant_ids', [userId])
          .order('last_message_time', ascending: false);

      final List<ChatRoom> loadedRooms = [];
      for (var roomData in response) {
        var room = ChatRoom.fromJson(roomData);
        
        // 获取对方信息 (由于暂无复杂的关联查询，简单获取一次)
        final otherId = room.participantIds.firstWhere((id) => id != userId);
        final otherUser = await _client.from('users').select('nickname, avatar').eq('id', otherId).maybeSingle();
        
        // 计算未读数
        final unreadCount = await _client
            .from('messages')
            .count()
            .eq('room_id', room.id)
            .eq('is_read', false)
            .neq('sender_id', userId);
        
        loadedRooms.add(room.copyWith(
          otherParticipantName: otherUser?['nickname'] ?? '神秘用户',
          otherParticipantAvatar: otherUser?['avatar'] ?? 'https://picsum.photos/seed/user/100/100',
          unreadCount: unreadCount,
        ));
      }
      _rooms = loadedRooms;
    } catch (e) {
      debugPrint('Load rooms error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 进入聊天室并开启实时监听
  Future<void> enterRoom(String roomId) async {
    _currentRoomMessages = [];
    notifyListeners();

    // 1. 加载历史消息
    try {
      final response = await _client
          .from('messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: true);
      
      _currentRoomMessages = (response as List).map((m) => Message.fromJson(m)).toList();
      notifyListeners();
      
      // 2. 停止旧监听
      await _messageSubscription?.unsubscribe();

      // 3. 开启实时监听新消息
      _messageSubscription = _client
          .channel('room_$roomId')
          .onPostgresChanges(
            event: supabase.PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: supabase.PostgresChangeFilter(
              type: supabase.PostgresChangeFilterType.eq, 
              column: 'room_id', 
              value: roomId
            ),
            callback: (payload) {
              debugPrint('Realtime message received: ${payload.newRecord}');
              try {
                final newMessage = Message.fromJson(payload.newRecord);
                // 避免重复
                if (!_currentRoomMessages.any((m) => m.id == newMessage.id)) {
                  _currentRoomMessages.add(newMessage);
                  notifyListeners();
                }
              } catch (e) {
                debugPrint('Error parsing realtime message: $e');
              }
            },
          )
          .subscribe((status, [error]) {
            debugPrint('Realtime status for room $roomId: $status');
            if (error != null) {
              debugPrint('Realtime subscription error: $error');
            }
          });

      // 4. 清除未读状态
      _markRoomAsRead(roomId);
    } catch (e) {
      debugPrint('Enter room error: $e');
    }
  }

  /// 发送消息
  Future<void> sendMessage(String roomId, String content, {String type = 'text'}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client.from('messages').insert({
        'room_id': roomId,
        'sender_id': userId,
        'content': content,
        'type': type,
      });
      // 消息会通过实时监听自动回来，或者在这里手动 load 一下
    } catch (e) {
      debugPrint('Send message error: $e');
      throw Exception('发送失败');
    }
  }

  /// 获取或创建会话
  Future<String> getOrCreateRoom(String otherUserId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('未登录');

    // 1. 查找是否存在两人的会话
    final response = await _client
        .from('chat_rooms')
        .select('id')
        .contains('participant_ids', [userId, otherUserId])
        .maybeSingle();

    if (response != null) return response['id'];

    // 2. 如果不存在，创建新会话
    final newRoom = await _client.from('chat_rooms').insert({
      'participant_ids': [userId, otherUserId],
    }).select('id').single();

    return newRoom['id'];
  }

  Future<void> _markRoomAsRead(String roomId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('messages')
        .update({'is_read': true})
        .eq('room_id', roomId)
        .neq('sender_id', userId);
    
    // 更新本地未读数
    final idx = _rooms.indexWhere((r) => r.id == roomId);
    if (idx != -1) {
      _rooms[idx] = _rooms[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _messageSubscription?.unsubscribe();
    super.dispose();
  }
}
