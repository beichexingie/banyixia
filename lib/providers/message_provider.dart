import 'dart:async';

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
  late final StreamSubscription<dynamic> _authSubscription;

  List<ChatRoom> get rooms => _rooms;
  List<Message> get currentRoomMessages => _currentRoomMessages;
  bool get isLoading => _isLoading;

  int get totalUnread => _rooms.fold(0, (sum, room) => sum + room.unreadCount);

  MessageProvider() {
    _authSubscription = _client.auth.onAuthStateChange.listen((data) {
      final userId = data.session?.user.id;
      if (userId == null) {
        _rooms = [];
        _currentRoomMessages = [];
        notifyListeners();
        return;
      }
      loadRooms();
    });
  }

  Future<void> _backfillOrderRooms(String userId) async {
    try {
      final orders = await _client
          .from('orders')
          .select('id, user_id, guide_id')
          .or('user_id.eq.$userId,guide_id.eq.$userId')
          .inFilter('status', [0, 1, 2, 3]);

      for (final item in orders) {
        final orderId = item['id']?.toString();
        final orderUserId = item['user_id']?.toString();
        final guideId = item['guide_id']?.toString();

        if (orderId == null ||
            orderId.isEmpty ||
            orderUserId == null ||
            orderUserId.isEmpty ||
            guideId == null ||
            guideId.isEmpty) {
          continue;
        }

        final existing = await _client
            .from('chat_rooms')
            .select('id')
            .eq('order_id', orderId)
            .maybeSingle();

        if (existing != null) {
          continue;
        }

        await _client.from('chat_rooms').insert({
          'participant_ids': [orderUserId, guideId],
          'order_id': orderId,
        });
      }
    } catch (e) {
      debugPrint('Backfill order rooms error: $e');
    }
  }

  /// 加载会话列表
  Future<void> loadRooms() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _backfillOrderRooms(userId);

      final response = await _client
          .from('chat_rooms')
          .select()
          .contains('participant_ids', [userId])
          .order('last_message_time', ascending: false);

      final List<ChatRoom> loadedRooms = [];
      for (var roomData in response) {
        try {
          var room = ChatRoom.fromJson(roomData);

          if (room.participantIds.length < 2) {
            continue;
          }

          final otherCandidates = room.participantIds.where((id) => id != userId);
          if (otherCandidates.isEmpty) {
            continue;
          }
          final otherId = otherCandidates.first;
          final otherUser = await _client
              .from('users')
              .select('nickname, avatar')
              .eq('id', otherId)
              .maybeSingle();

          Map<String, dynamic>? orderData;
          if (room.orderId != null && room.orderId!.isNotEmpty) {
            orderData = await _client
                .from('orders')
                .select('guide_id, guide_name, guide_avatar, service_name')
                .eq('id', room.orderId!)
                .maybeSingle();
          }

          final guideIdFromOrder = orderData == null
              ? null
              : orderData['guide_id']?.toString();
          final showGuideFromOrder =
              guideIdFromOrder != null && guideIdFromOrder == otherId;
          final displayName = showGuideFromOrder
              ? orderData!['guide_name']?.toString()
              : (otherUser == null ? null : otherUser['nickname']?.toString());
          final displayAvatar = showGuideFromOrder
              ? orderData!['guide_avatar']?.toString()
              : (otherUser == null ? null : otherUser['avatar']?.toString());
          final serviceName = orderData == null
              ? null
              : orderData['service_name']?.toString();

          final unreadCount = await _client
              .from('messages')
              .count()
              .eq('room_id', room.id)
              .eq('is_read', false)
              .neq('sender_id', userId);

          loadedRooms.add(room.copyWith(
            otherParticipantName:
                (displayName != null && displayName.trim().isNotEmpty)
                ? displayName
                : '神秘用户',
            otherParticipantAvatar:
                (displayAvatar != null && displayAvatar.trim().isNotEmpty)
                ? displayAvatar
                : 'https://picsum.photos/seed/user/100/100',
            orderServiceName: serviceName,
            unreadCount: unreadCount,
          ));
        } catch (roomError) {
          debugPrint('Load single room error: $roomError');
        }
      }
      loadedRooms.sort((a, b) {
        final aTime = a.lastMessageTime ?? a.createdAt;
        final bTime = b.lastMessageTime ?? b.createdAt;
        return bTime.compareTo(aTime);
      });
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
      final roomAccess = await _client
          .from('chat_rooms')
          .select('id, order_id, participant_ids')
          .eq('id', roomId)
          .maybeSingle();

      if (roomAccess == null) {
        throw Exception('会话不存在');
      }

      final response = await _client
          .from('messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: true);

      _currentRoomMessages = (response as List)
          .map((m) => Message.fromJson(m))
          .toList();
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
      final roomAccess = await _client
          .from('chat_rooms')
          .select('id, order_id')
          .eq('id', roomId)
          .maybeSingle();

      if (roomAccess == null) {
        throw Exception('当前会话不存在，不能发送消息');
      }

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
    if (otherUserId == userId) {
      throw Exception('不能和自己聊天');
    }

    final orderResponse = await _client
        .from('orders')
        .select('id, user_id, guide_id, status, created_at')
        .or(
          'and(user_id.eq.$userId,guide_id.eq.$otherUserId),and(user_id.eq.$otherUserId,guide_id.eq.$userId)',
        )
        .inFilter('status', [0, 1, 2, 3])
        .order('created_at', ascending: false)
        .limit(1);

    if (orderResponse.isEmpty) {
      throw Exception('请先下单，创建订单后即可联系地陪');
    }

    final orderId = orderResponse.first['id']?.toString();
    if (orderId == null || orderId.isEmpty) {
      throw Exception('订单信息异常，暂时无法建立聊天');
    }

    final response = await _client
        .from('chat_rooms')
        .select('id')
        .eq('order_id', orderId)
        .maybeSingle();

    if (response != null) return response['id'];

    // 2. 如果不存在，创建订单绑定会话
    final newRoom = await _client.from('chat_rooms').insert({
      'participant_ids': [userId, otherUserId],
      'order_id': orderId,
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
    _authSubscription.cancel();
    _messageSubscription?.unsubscribe();
    super.dispose();
  }
}
