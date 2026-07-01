import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/post_comment.dart';
import '../../models/travel_post.dart';
import '../../providers/post_provider.dart';
import '../../providers/user_provider.dart';

class PostDetailPage extends StatefulWidget {
  final TravelPost post;

  const PostDetailPage({super.key, required this.post});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  bool _isLoadingComments = false;
  int _currentImageIndex = 0;
  List<PostComment> _comments = [];
  PostComment? _replyingToComment;
  final Set<String> _expandedThreadIds = <String>{};
  final TextEditingController _commentController = TextEditingController();
  final PageController _imageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadComments();
    _checkFollowStatus();
    context.read<PostProvider>().recordFootprint(widget.post.id);
  }

  @override
  void dispose() {
    _commentController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _checkFollowStatus() async {
    final following = await context.read<UserProvider>().isFollowing(
      widget.post.authorId,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isFollowing = following);
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) {
      return;
    }
    setState(() => _isFollowLoading = true);
    try {
      final userProvider = context.read<UserProvider>();
      if (_isFollowing) {
        await userProvider.unfollowUser(widget.post.authorId);
      } else {
        await userProvider.followUser(widget.post.authorId);
      }
      await _checkFollowStatus();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    final comments = await context.read<PostProvider>().loadComments(
      widget.post.id,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _comments = comments;
      _isLoadingComments = false;
    });
  }

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '分享到',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _shareItem(
                    Icons.chat_bubble_outline,
                    '微信好友',
                    const Color(0xFF28C445),
                  ),
                  _shareItem(
                    Icons.camera_alt_outlined,
                    '朋友圈',
                    const Color(0xFF66C95E),
                  ),
                  _shareItem(
                    Icons.link_rounded,
                    '复制链接',
                    const Color(0xFF4A8BFF),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _shareItem(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _showCommentSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: _replyingToComment == null
                          ? '请输入内容...'
                          : '回复 ${_replyingToComment!.userName}...',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textHint,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF6F6F6),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => _submitComment(sheetContext),
                  child: const Text(
                    '发送',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitComment(BuildContext sheetContext) async {
    final content = _commentController.text.trim();
    if (content.isEmpty) {
      return;
    }

    Navigator.pop(sheetContext);
    _commentController.clear();

    try {
      final replyTarget = _replyingToComment;
      await context.read<PostProvider>().addComment(
        widget.post.id,
        content,
        parentCommentId: replyTarget == null
            ? null
            : _threadRootId(replyTarget),
        replyToCommentId: replyTarget?.id,
      );
      await _loadComments();
      if (!mounted) {
        return;
      }
      setState(() {
        _replyingToComment = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评论成功')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  List<String> _resolveImages(TravelPost post) {
    final images = (post.images ?? <String>[])
        .where((url) => url.trim().isNotEmpty)
        .toList();
    if (images.isNotEmpty) {
      return images;
    }
    if (post.coverImage.trim().isNotEmpty) {
      return [post.coverImage];
    }
    return const [''];
  }

  int _displayCommentCount(TravelPost post) {
    if (_comments.isNotEmpty) {
      return _comments.length;
    }
    return max(post.commentCount, 0);
  }

  List<_CommentThreadData> _resolveCommentThreads(TravelPost post) {
    if (_comments.isEmpty) {
      return const [];
    }

    final rootComments = _comments
        .where((comment) => comment.parentCommentId.trim().isEmpty)
        .toList();
    final repliesByRoot = <String, List<PostComment>>{};

    for (final comment in _comments) {
      final parentId = comment.parentCommentId.trim();
      if (parentId.isEmpty) {
        continue;
      }
      repliesByRoot.putIfAbsent(parentId, () => <PostComment>[]).add(comment);
    }

    return rootComments.map((root) {
      final replies = repliesByRoot[root.id] ?? const <PostComment>[];
      final isExpanded = _expandedThreadIds.contains(root.id);
      final visibleReplies = isExpanded || replies.length <= 2
          ? replies
          : replies.take(2).toList();
      final hiddenReplyCount = max(replies.length - visibleReplies.length, 0);

      return _CommentThreadData.fromComment(
        root,
        isAuthor: root.userId == post.authorId,
        likeCount: root.likeCount,
        replies: visibleReplies
            .map(
              (reply) => _CommentReplyData.fromComment(
                reply,
                isAuthor: reply.userId == post.authorId,
                likeCount: reply.likeCount,
              ),
            )
            .toList(),
        showExpandHint: hiddenReplyCount > 0,
        hiddenReplyCount: hiddenReplyCount,
        isExpanded: isExpanded,
      );
    }).toList();
  }

  String _threadRootId(PostComment comment) {
    final parentId = comment.parentCommentId.trim();
    return parentId.isEmpty ? comment.id : parentId;
  }

  Future<void> _toggleCommentLike(PostComment comment) async {
    final original = comment;
    final optimistic = comment.copyWith(
      isLiked: !comment.isLiked,
      likeCount: comment.isLiked
          ? max(comment.likeCount - 1, 0)
          : comment.likeCount + 1,
    );

    setState(() {
      _comments = _comments
          .map((item) => item.id == comment.id ? optimistic : item)
          .toList();
    });

    try {
      final updated = await context.read<PostProvider>().toggleCommentLike(
        comment,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _comments
            .map((item) => item.id == comment.id ? updated : item)
            .toList();
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _comments = _comments
            .map((item) => item.id == comment.id ? original : item)
            .toList();
      });
    }
  }

  void _startReply(PostComment comment) {
    setState(() {
      _replyingToComment = comment;
    });
    _commentController.clear();
    _showCommentSheet();
  }

  void _toggleThreadExpanded(String rootId) {
    setState(() {
      if (_expandedThreadIds.contains(rootId)) {
        _expandedThreadIds.remove(rootId);
      } else {
        _expandedThreadIds.add(rootId);
      }
    });
  }

  String _formatCommentTime(DateTime time) {
    final now = DateTime.now();
    final local = time.toLocal();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) {
      return '刚刚';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    }
    if (diff.inDays == 1) {
      return '昨天';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    }
    return '${local.year}年${local.month}月${local.day}日';
  }

  @override
  Widget build(BuildContext context) {
    final isSelfPost =
        context.read<UserProvider>().user.id == widget.post.authorId;

    return Consumer<PostProvider>(
      builder: (context, provider, _) {
        final post = provider.posts.firstWhere(
          (item) => item.id == widget.post.id,
          orElse: () => widget.post,
        );
        final images = _resolveImages(post);

        return Scaffold(
          backgroundColor: Colors.white,
          bottomNavigationBar: _buildBottomBar(post),
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildHeader(post, isSelfPost),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [_buildGallery(images), _buildBody(post)],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(TravelPost post, bool isSelfPost) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(20),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 22,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/user/${post.authorId}'),
              child: Row(
                children: [
                  _buildAvatar(post.authorAvatar, 44),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            post.authorName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.female_rounded,
                          size: 17,
                          color: Color(0xFFE27BFF),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isSelfPost) ...[
            const SizedBox(width: 12),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: _isFollowLoading ? null : _toggleFollow,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                child: _isFollowLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textPrimary,
                        ),
                      )
                    : Text(
                        _isFollowing ? '已关注' : '关注',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ],
          const SizedBox(width: 14),
          InkWell(
            onTap: _showShareSheet,
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: const Color(0xFFE7E7E7)),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.reply_rounded,
                size: 24,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallery(List<String> images) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final galleryHeight = (screenWidth * 1.24).clamp(420.0, 620.0);

    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        SizedBox(
          height: galleryHeight,
          width: double.infinity,
          child: PageView.builder(
            controller: _imageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() => _currentImageIndex = index);
            },
            itemBuilder: (context, index) {
              final imageUrl = images[index];
              if (imageUrl.isEmpty) {
                return Container(
                  color: const Color(0xFFF1F1F1),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_outlined,
                    size: 44,
                    color: AppColors.textHint,
                  ),
                );
              }
              return CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) =>
                    Container(color: const Color(0xFFF1F1F1)),
                errorWidget: (context, url, error) => Container(
                  color: const Color(0xFFF1F1F1),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 44,
                    color: AppColors.textHint,
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 18,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              images.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: index == _currentImageIndex ? 12 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: index == _currentImageIndex ? 1 : 0.66,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(TravelPost post) {
    final title = post.title.trim();
    final content = post.content?.trim() ?? '';
    final threads = _resolveCommentThreads(post);

    return Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty) ...[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  height: 1.28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (content.isNotEmpty) ...[
              Text(
                content,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.56,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 22),
            ],
            const Divider(height: 1, color: Color(0xFFF1F1F1)),
            const SizedBox(height: 22),
            Text(
              '评论 ${_displayCommentCount(post)}',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF444444),
              ),
            ),
            const SizedBox(height: 18),
            if (_isLoadingComments)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else
              Column(
                children: threads
                    .map((thread) => _buildCommentThread(thread))
                    .toList(),
              ),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentThread(_CommentThreadData thread) {
    final comment = thread.comment;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.push('/user/${comment.userId}'),
            child: _buildAvatar(thread.userAvatar, 38),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                context.push('/user/${comment.userId}'),
                            child: Text(
                              thread.userName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF9A9A9A),
                              ),
                            ),
                          ),
                          if (thread.isAuthor) _buildAuthorBadge(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildLikeColumn(thread.comment),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  thread.content,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.45,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      thread.timeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9F9F9F),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _startReply(thread.comment),
                      child: const Text(
                        '回复',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7F7F7F),
                        ),
                      ),
                    ),
                  ],
                ),
                if (thread.replies.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  ...thread.replies.map(_buildReplyItem),
                ],
                if (thread.showExpandHint || thread.isExpanded) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _toggleThreadExpanded(thread.comment.id),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2),
                      child: Text(
                        thread.isExpanded
                            ? '收起回复'
                            : '展开${thread.hiddenReplyCount}条回复',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5D78A8).withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyItem(_CommentReplyData reply) {
    final comment = reply.comment;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.push('/user/${comment.userId}'),
            child: _buildAvatar(reply.userAvatar, 30),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          GestureDetector(
                            onTap: () =>
                                context.push('/user/${comment.userId}'),
                            child: Text(
                              reply.userName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF9A9A9A),
                              ),
                            ),
                          ),
                          if (reply.isAuthor) _buildAuthorBadge(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildLikeColumn(reply.comment, iconSize: 24),
                  ],
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      if (reply.replyToUserName.trim().isNotEmpty)
                        TextSpan(
                          text: '回复 ${reply.replyToUserName} ',
                          style: const TextStyle(color: Color(0xFF5D78A8)),
                        ),
                      TextSpan(text: reply.content),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      reply.timeLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9F9F9F),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _startReply(reply.comment),
                      child: const Text(
                        '回复',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7F7F7F),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLikeColumn(PostComment comment, {double iconSize = 28}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => _toggleCommentLike(comment),
          child: Icon(
            comment.isLiked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            size: iconSize,
            color: comment.isLiked
                ? const Color(0xFFFF6F7A)
                : const Color(0xFFBCBCBC),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '${comment.likeCount}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF9F9F9F)),
        ),
      ],
    );
  }

  Widget _buildAuthorBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '作者',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildBottomBar(TravelPost post) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFF1F1F1))),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _showCommentSheet,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F7),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _replyingToComment == null
                        ? '请输入内容...'
                        : '回复 ${_replyingToComment!.userName}...',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFC9C9C9),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 18),
            _bottomMetric(
              icon: post.isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: '${max(post.likes, 0)}',
              color: post.isLiked
                  ? const Color(0xFFFF6F7A)
                  : AppColors.textPrimary,
              onTap: () => context.read<PostProvider>().toggleLike(post),
            ),
            const SizedBox(width: 18),
            _bottomMetric(
              icon: post.isFavorited
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: '${max(post.favorites, 0)}',
              color: post.isFavorited
                  ? AppColors.textPrimary
                  : AppColors.textPrimary,
              onTap: () => context.read<PostProvider>().toggleFavorite(post),
            ),
            const SizedBox(width: 18),
            _bottomMetric(
              icon: Icons.chat_bubble_outline_rounded,
              label: '${_displayCommentCount(post)}',
              color: AppColors.textPrimary,
              onTap: _showCommentSheet,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomMetric({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 25, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String url, double size) {
    if (url.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(size / 2),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.person, size: size * 0.52, color: AppColors.textHint),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, _) => Container(
          width: size,
          height: size,
          color: const Color(0xFFF0F0F0),
        ),
        errorWidget: (context, _, __) => Container(
          width: size,
          height: size,
          color: const Color(0xFFF0F0F0),
          alignment: Alignment.center,
          child: Icon(
            Icons.person,
            size: size * 0.52,
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

class _CommentThreadData {
  final PostComment comment;
  final String userName;
  final String userAvatar;
  final String content;
  final String timeLabel;
  final int likeCount;
  final bool isAuthor;
  final List<_CommentReplyData> replies;
  final bool showExpandHint;
  final int hiddenReplyCount;
  final bool isExpanded;

  const _CommentThreadData({
    required this.comment,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.timeLabel,
    required this.likeCount,
    required this.isAuthor,
    this.replies = const [],
    this.showExpandHint = false,
    this.hiddenReplyCount = 0,
    this.isExpanded = false,
  });

  factory _CommentThreadData.fromComment(
    PostComment comment, {
    required bool isAuthor,
    required int likeCount,
    List<_CommentReplyData> replies = const [],
    bool showExpandHint = false,
    int hiddenReplyCount = 0,
    bool isExpanded = false,
  }) {
    return _CommentThreadData(
      comment: comment,
      userName: comment.userName,
      userAvatar: comment.userAvatar,
      content: comment.content,
      timeLabel: _formatTime(comment.createdAt),
      likeCount: likeCount,
      isAuthor: isAuthor,
      replies: replies,
      showExpandHint: showExpandHint,
      hiddenReplyCount: hiddenReplyCount,
      isExpanded: isExpanded,
    );
  }

  static String _formatTime(DateTime time) {
    final now = DateTime.now();
    final local = time.toLocal();
    final diff = now.difference(local);

    if (diff.inMinutes < 1) {
      return '刚刚';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}分钟前';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    }
    if (diff.inDays == 1) {
      return '昨天';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}天前';
    }
    return '${local.year}年${local.month}月${local.day}日';
  }
}

class _CommentReplyData {
  final PostComment comment;
  final String userName;
  final String userAvatar;
  final String content;
  final String timeLabel;
  final int likeCount;
  final bool isAuthor;
  final String replyToUserName;

  const _CommentReplyData({
    required this.comment,
    required this.userName,
    required this.userAvatar,
    required this.content,
    required this.timeLabel,
    required this.likeCount,
    required this.isAuthor,
    this.replyToUserName = '',
  });

  factory _CommentReplyData.fromComment(
    PostComment comment, {
    required bool isAuthor,
    required int likeCount,
  }) {
    return _CommentReplyData(
      comment: comment,
      userName: comment.userName,
      userAvatar: comment.userAvatar,
      content: comment.content,
      timeLabel: _CommentThreadData._formatTime(comment.createdAt),
      likeCount: likeCount,
      isAuthor: isAuthor,
      replyToUserName: comment.replyToUserName,
    );
  }
}
