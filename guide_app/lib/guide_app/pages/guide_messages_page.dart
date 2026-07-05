import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/message_provider.dart';
import '../../pages/messages/chat_room_page.dart';
import '../widgets/guide_app_shell.dart';

class GuideMessagesPage extends StatelessWidget {
  const GuideMessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessageProvider>();
    final rooms = provider.rooms;

    return GuideAppScaffold(
      backgroundColor: const Color(0xFFF0F1F3),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '消息',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Icon(Icons.notifications_none_rounded, size: 28),
              ],
            ),
          ),
          Expanded(
            child: rooms.isEmpty
                ? Center(
                    child: GuideSectionCard(
                      margin: const EdgeInsets.symmetric(horizontal: 18),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 58, color: AppColors.textHint),
                          SizedBox(height: 14),
                          Text(
                            '暂无消息',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '地陪端的订单沟通、系统通知都会出现在这里',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      return InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ChatRoomPage(
                                roomId: room.id,
                                otherUserName: room.otherParticipantName ?? '用户',
                                otherUserAvatar: room.otherParticipantAvatar ?? '',
                              ),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: GuideSectionCard(
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ClipOval(
                                    child: Image.network(
                                      room.otherParticipantAvatar?.isNotEmpty == true
                                          ? room.otherParticipantAvatar!
                                          : 'https://picsum.photos/seed/chat_${room.id}/100/100',
                                      width: 54,
                                      height: 54,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 54,
                                        height: 54,
                                        color: const Color(0xFFECEEF2),
                                        child: const Icon(Icons.person),
                                      ),
                                    ),
                                  ),
                                  if (room.unreadCount > 0)
                                    Positioned(
                                      right: -2,
                                      top: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          '${room.unreadCount}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            room.otherParticipantName ?? '客户',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
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
                                    Text(
                                      room.lastMessage ?? '快开始和客户沟通吧',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
