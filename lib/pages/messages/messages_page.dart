import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/chat_room.dart';
import '../../providers/message_provider.dart';

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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildQuickActions(),
            const Divider(height: 1, color: Color(0xFFF1F1F1)),
            Expanded(
              child: Consumer<MessageProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading && provider.rooms.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (provider.rooms.isEmpty) {
                    return _buildEmptyState();
                  }

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () => provider.loadRooms(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 96),
                      itemCount: provider.rooms.length,
                      itemBuilder: (context, index) =>
                          _buildRoomTile(provider.rooms[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          const Expanded(
            child: Row(
              children: [
                Text(
                  '消息通知',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2B3B5B),
                  ),
                ),
                SizedBox(width: 10),
                Icon(Icons.delete_outline, size: 18, color: AppColors.textHint),
                SizedBox(width: 4),
                Text(
                  '消息清除',
                  style: TextStyle(fontSize: 13, color: AppColors.textHint),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/settings/notifications'),
            child: const Row(
              children: [
                Icon(
                  Icons.settings_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                SizedBox(width: 4),
                Text(
                  '消息管理',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      child: Row(
        children: [
          Expanded(
            child: _quickAction(
              icon: Icons.receipt_long_outlined,
              label: '订单服务',
              onTap: () => context.push('/profile/orders'),
            ),
          ),
          Expanded(
            child: _quickAction(
              icon: Icons.campaign_outlined,
              label: '活动通知',
              onTap: () => _showMessage('活动通知稍后接入'),
            ),
          ),
          Expanded(
            child: _quickAction(
              icon: Icons.notifications_none,
              label: '系统通知',
              onTap: () => _showMessage('系统通知稍后接入'),
            ),
          ),
          Expanded(
            child: _quickAction(
              icon: Icons.headset_mic_outlined,
              label: '在线客服',
              onTap: () => _showMessage('在线客服稍后接入'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF9B8),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.textPrimary, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomTile(ChatRoom room) {
    final shortSeed = room.participantIds.isNotEmpty
        ? room.participantIds.first.substring(
            0,
            room.participantIds.first.length.clamp(0, 4).toInt(),
          )
        : '';
    final displayName = room.otherParticipantName?.trim().isNotEmpty == true
        ? room.otherParticipantName!
        : '用户$shortSeed';
    final subtitle = room.lastMessage?.trim().isNotEmpty == true
        ? room.lastMessage!
        : '这里是聊天内容，这里是聊天内容';

    return InkWell(
      onTap: () {
        context.push(
          '/chat/${room.id}?name=${Uri.encodeComponent(displayName)}&avatar=${Uri.encodeComponent(room.otherParticipantAvatar ?? '')}',
        );
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          children: [
            ClipOval(
              child: (room.otherParticipantAvatar?.isNotEmpty ?? false)
                  ? CachedNetworkImage(
                      imageUrl: room.otherParticipantAvatar!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2B3B5B),
                          ),
                        ),
                      ),
                      Text(
                        room.timeLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                      if (room.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6D6B),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            room.unreadCount > 9 ? '9+' : '${room.unreadCount}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 56,
      height: 56,
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: AppColors.textHint),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 34,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '暂无会话',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '聊天消息和订单沟通都会显示在这里',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
