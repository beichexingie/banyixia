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
      backgroundColor: const Color(0xFFF4F6FB),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildCategoryPanel(),
            const SizedBox(height: 12),
            Expanded(
              child: Consumer<MessageProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading && provider.rooms.isEmpty) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }

                  final rooms = provider.rooms;
                  if (rooms.isEmpty) {
                    return _buildEmpty();
                  }

                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () => provider.loadRooms(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: rooms.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildRoomCard(context, rooms[index]),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text('消息通知', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => context.push('/settings/notifications'),
            child: const Text('消息管理', style: TextStyle(color: Color(0xFF3D6CF5))),
          ),
          IconButton(
            onPressed: () => context.push('/profile/orders'),
            icon: const Icon(Icons.receipt_long_outlined, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE9ECF5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCategoryItem(Icons.receipt_long, '订单服务', () => context.push('/profile/orders')),
            _buildCategoryItem(Icons.campaign_outlined, '活动通知', () => _showMessage('活动通知暂未接入后台')),
            _buildCategoryItem(Icons.notifications_none, '系统通知', () => _showMessage('系统通知暂未接入后台')),
            _buildCategoryItem(Icons.support_agent_outlined, '在线客服', () => _showMessage('客服入口已保留，后续可接对接 API')),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: const Color(0xFF3D6CF5)),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF3D6CF5), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, ChatRoom room) {
    return InkWell(
      onTap: () {
        context.push(
          '/chat/${room.id}?name=${Uri.encodeComponent(room.otherParticipantName ?? "用户")}&avatar=${Uri.encodeComponent(room.otherParticipantAvatar ?? "")}',
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: room.otherParticipantAvatar ?? '',
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 52,
                      height: 52,
                      color: AppColors.tagBackground,
                      child: const Icon(Icons.person, color: AppColors.primary),
                    ),
                  ),
                ),
                if (room.unreadCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        '${room.unreadCount}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
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
                          room.otherParticipantName ?? '未知用户',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(room.timeLabel, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    room.lastMessage ??
                        (room.orderServiceName?.trim().isNotEmpty == true
                            ? '订单沟通: ${room.orderServiceName}'
                            : '快开始聊天吧'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          const Text('暂无会话', style: AppTextStyles.subtitle),
          const SizedBox(height: 8),
          Text('历史聊天和订单沟通都会显示在这里', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}
