import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/message.dart';
import '../../providers/message_provider.dart';

import '../../models/chat_room.dart';
import './chat_room_page.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessageProvider>().loadRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('消息', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () {},
          ),
        ],
      ),
      body: Consumer<MessageProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.rooms.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final rooms = provider.rooms;
          if (rooms.isEmpty) return _buildEmpty();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => provider.loadRooms(),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: rooms.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 76, color: AppColors.divider),
              itemBuilder: (context, index) => _buildRoomItem(context, rooms[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoomItem(BuildContext context, ChatRoom room) {
    return Container(
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: room.otherParticipantAvatar ?? '', width: 48, height: 48, fit: BoxFit.cover,
                errorWidget: (context, url, error) => Container(
                  width: 48, height: 48, color: AppColors.tagBackground,
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
              ),
            ),
            if (room.unreadCount > 0)
              Positioned(
                top: -4, right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text('${room.unreadCount}', textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        title: Text(room.otherParticipantName ?? '未知用户', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(room.lastMessage ?? '快开始聊天吧', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
        ),
        trailing: Text(
          room.timeLabel,
          style: const TextStyle(fontSize: 12, color: AppColors.textHint)
        ),
        onTap: () {
          context.push('/chat/${room.id}?name=${Uri.encodeComponent(room.otherParticipantName ?? "用户")}&avatar=${Uri.encodeComponent(room.otherParticipantAvatar ?? "")}');
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('暂无对话', style: AppTextStyles.subtitle),
          const SizedBox(height: 8),
          Text('快去和地陪们聊聊吧', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

