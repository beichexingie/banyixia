import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/message.dart';
import '../../providers/message_provider.dart';

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

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
            onPressed: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (ctx) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.mark_email_read, color: AppColors.primary),
                          title: const Text('全部标记已读'),
                          onTap: () {
                            final msgProvider = context.read<MessageProvider>();
                            for (final msg in msgProvider.messages) {
                              msgProvider.markAsRead(msg.id);
                            }
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('已全部标记为已读'),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary),
                          title: const Text('消息通知设置'),
                          onTap: () {
                            Navigator.pop(ctx);
                            context.push('/settings/notifications');
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<MessageProvider>(
        builder: (context, messageProvider, child) {
          if (messageProvider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final messages = messageProvider.messages;
          if (messages.isEmpty) return _buildEmpty();

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => messageProvider.loadMessages(),
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: messages.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 76, color: AppColors.divider),
              itemBuilder: (context, index) => _buildMessageItem(context, messages[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageItem(BuildContext context, Message msg) {
    return Container(
      color: Colors.white,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: msg.senderAvatar, width: 48, height: 48, fit: BoxFit.cover,
                placeholder: (context, url) => Container(width: 48, height: 48, color: AppColors.tagBackground),
                errorWidget: (context, url, error) => Container(
                  width: 48, height: 48,
                  decoration: const BoxDecoration(color: AppColors.tagBackground, shape: BoxShape.circle),
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
              ),
            ),
            if (msg.unreadCount > 0)
              Positioned(
                top: -4, right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Text('${msg.unreadCount}', textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
        title: Text(msg.senderName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(msg.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption),
        ),
        trailing: Text(msg.timeLabel, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
        onTap: () {
          // 标记已读 + 进入聊天页面
          context.read<MessageProvider>().markAsRead(msg.id);
          _openChatPage(context, msg);
        },
      ),
    );
  }

  void _openChatPage(BuildContext context, Message msg) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _ChatPage(senderName: msg.senderName, senderAvatar: msg.senderAvatar, lastMessage: msg.content),
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
          const Text('暂无消息', style: AppTextStyles.subtitle),
          const SizedBox(height: 8),
          Text('快去和搭子们聊聊吧', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// 简易聊天页面
class _ChatPage extends StatefulWidget {
  final String senderName;
  final String senderAvatar;
  final String lastMessage;

  const _ChatPage({required this.senderName, required this.senderAvatar, required this.lastMessage});

  @override
  State<_ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<_ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _chatMessages = [];

  @override
  void initState() {
    super.initState();
    // 添加初始消息
    _chatMessages.add({'isMe': false, 'text': widget.lastMessage, 'time': DateTime.now()});
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _chatMessages.add({'isMe': true, 'text': text, 'time': DateTime.now()});
      _messageController.clear();
    });

    // 模拟自动回复
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _chatMessages.add({
            'isMe': false,
            'text': '收到啦，稍等我看看~',
            'time': DateTime.now(),
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.senderName),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final msg = _chatMessages[index];
                final isMe = msg['isMe'] as bool;
                return _buildChatBubble(msg['text'] as String, isMe);
              },
            ),
          ),
          // 输入框
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, -2))],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: '输入消息...',
                        hintStyle: const TextStyle(color: AppColors.textHint),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(String text, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: widget.senderAvatar, width: 36, height: 36, fit: BoxFit.cover,
                placeholder: (context, url) => Container(width: 36, height: 36, color: AppColors.tagBackground),
                errorWidget: (context, url, error) => const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 18)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Text(
                text,
                style: TextStyle(fontSize: 15, color: isMe ? Colors.white : AppColors.textPrimary, height: 1.4),
              ),
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            const CircleAvatar(radius: 18, backgroundColor: Color(0xFFE0E0E0), child: Icon(Icons.person, size: 18, color: Colors.white)),
          ],
        ],
      ),
    );
  }
}
