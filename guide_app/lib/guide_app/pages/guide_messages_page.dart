import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/chat_room.dart';
import 'package:flutter_application_1/pages/messages/chat_room_page.dart';
import 'package:flutter_application_1/pages/profile/notification_settings_page.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/message_provider.dart';
import '../widgets/guide_app_shell.dart';
import '../widgets/guide_design_icon.dart';

class GuideMessagesPage extends StatelessWidget {
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenActivities;
  final VoidCallback onOpenSystemNotifications;
  final VoidCallback onOpenOperations;

  const GuideMessagesPage({
    super.key,
    required this.onOpenOrders,
    required this.onOpenActivities,
    required this.onOpenSystemNotifications,
    required this.onOpenOperations,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessageProvider>();
    return GuideAppScaffold(
      backgroundColor: const Color(0xFFF0F1F3),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '消息通知',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2B3B5B),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: provider.totalUnread == 0
                      ? null
                      : () => provider.markAllRoomsAsRead(),
                  icon: const Icon(Icons.delete_outline, size: 17),
                  label: const Text('消息清除'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textHint,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationSettingsPage(),
                    ),
                  ),
                  icon: const Icon(Icons.settings_outlined, size: 17),
                  label: const Text('消息管理'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          _QuickActions(
            onOpenOrders: onOpenOrders,
            onOpenActivities: onOpenActivities,
            onOpenSystemNotifications: onOpenSystemNotifications,
            onOpenOperations: onOpenOperations,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: provider.isLoading && provider.rooms.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryDeep,
                    ),
                  )
                : provider.rooms.isEmpty
                ? const _EmptyMessages()
                : RefreshIndicator(
                    color: AppColors.primaryDeep,
                    onRefresh: provider.loadRooms,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(10, 0, 10, 20),
                      itemCount: provider.rooms.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 68,
                        color: Color(0xFFE8E9EC),
                      ),
                      itemBuilder: (context, index) {
                        return _RoomTile(room: provider.rooms[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onOpenOrders;
  final VoidCallback onOpenActivities;
  final VoidCallback onOpenSystemNotifications;
  final VoidCallback onOpenOperations;

  const _QuickActions({
    required this.onOpenOrders,
    required this.onOpenActivities,
    required this.onOpenSystemNotifications,
    required this.onOpenOperations,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: AspectRatio(
        aspectRatio: 376 / 72,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final itemWidth = constraints.maxWidth / 4;
            final actions = [
              onOpenOrders,
              onOpenActivities,
              onOpenSystemNotifications,
              onOpenOperations,
            ];
            return Stack(
              children: [
                const Positioned.fill(
                  child: GuideDesignIcon(
                    'Frame_1739336927',
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.fill,
                  ),
                ),
                for (var index = 0; index < actions.length; index++)
                  Positioned(
                    left: itemWidth * index,
                    top: 0,
                    bottom: 0,
                    width: itemWidth,
                    child: InkWell(
                      onTap: actions[index],
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final ChatRoom room;

  const _RoomTile({required this.room});

  @override
  Widget build(BuildContext context) {
    final name = room.otherParticipantName?.trim().isNotEmpty == true
        ? room.otherParticipantName!
        : '客户';
    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ChatRoomPage(
              roomId: room.id,
              otherUserName: name,
              otherUserAvatar: room.otherParticipantAvatar ?? '',
            ),
          ),
        );
        if (context.mounted) {
          await context.read<MessageProvider>().loadRooms();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Row(
          children: [
            ClipOval(
              child: room.otherParticipantAvatar?.isNotEmpty == true
                  ? Image.network(
                      room.otherParticipantAvatar!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _AvatarFallback(),
                    )
                  : _AvatarFallback(),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2B3B5B),
                          ),
                        ),
                      ),
                      Text(
                        room.timeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          room.lastMessage?.trim().isNotEmpty == true
                              ? room.lastMessage!
                              : '暂无新的聊天内容',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                      if (room.unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 20),
                          height: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFF6D6B),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            room.unreadCount > 9 ? '9+' : '${room.unreadCount}',
                            style: const TextStyle(
                              fontSize: 10,
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
}

class _AvatarFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: AppColors.textHint),
    );
  }
}

class _EmptyMessages extends StatelessWidget {
  const _EmptyMessages();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GuideSectionCard(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 46,
              color: AppColors.textHint,
            ),
            SizedBox(height: 10),
            Text(
              '暂无会话',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 5),
            Text(
              '订单沟通和客服消息会显示在这里',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
