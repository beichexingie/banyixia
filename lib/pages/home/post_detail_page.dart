import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/post_comment.dart';
import '../../models/travel_post.dart';
import '../../providers/guide_provider.dart';
import '../../providers/message_provider.dart';
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
  List<PostComment> _comments = [];
  bool _isLoadingComments = false;
  final TextEditingController _commentController = TextEditingController();

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
    super.dispose();
  }

  Future<void> _checkFollowStatus() async {
    final following = await context.read<UserProvider>().isFollowing(widget.post.authorId);
    if (mounted) {
      setState(() => _isFollowing = following);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _loadComments() async {
    setState(() => _isLoadingComments = true);
    final comments = await context.read<PostProvider>().loadComments(widget.post.id);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _contactGuide() async {
    try {
      final roomId = await context.read<MessageProvider>().getOrCreateRoom(widget.post.authorId);
      if (!mounted) return;
      context.push('/chat/$roomId?name=${Uri.encodeComponent(widget.post.authorName)}&avatar=${Uri.encodeComponent(widget.post.authorAvatar)}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _showCommentModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(16),
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
                      hintText: '写下你的评论...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.tagBackground,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    final content = _commentController.text.trim();
                    if (content.isEmpty) return;
                    Navigator.pop(ctx);
                    _commentController.clear();
                    await context.read<PostProvider>().addComment(widget.post.id, content);
                    _loadComments();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                  ),
                  child: const Text('发送'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showShareModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: const Text('分享功能后续补充。', style: TextStyle(fontSize: 14)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelfPost = context.read<UserProvider>().user.id == widget.post.authorId;
    final latestPost = context.watch<PostProvider>().posts.firstWhere(
          (p) => p.id == widget.post.id,
          orElse: () => widget.post,
        );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 360,
            pinned: true,
            backgroundColor: Colors.white,
            leading: _CircleBtn(icon: Icons.arrow_back_ios_new, onTap: () => context.pop()),
            actions: [
              _CircleBtn(icon: Icons.share, onTap: _showShareModal),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: widget.post.coverImage,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(color: AppColors.tagBackground),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: widget.post.authorAvatar,
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => const CircleAvatar(radius: 21, child: Icon(Icons.person)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.post.authorName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.post.timeLabel,
                                    style: const TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            if (!isSelfPost)
                              ElevatedButton(
                                onPressed: _isFollowLoading ? null : _toggleFollow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: AppColors.textPrimary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                ),
                                child: Text(_isFollowing ? '已关注' : '关注'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PostStatRow(post: latestPost),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '正文',
                    child: Text(
                      widget.post.content ?? '暂无正文内容',
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.7,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '标签',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (widget.post.tag.isNotEmpty) _Tag(text: widget.post.tag),
                        _Tag(text: widget.post.cityLabelOrDefault),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    '全部评论',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          if (_isLoadingComments)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator(color: AppColors.primaryDark)),
              ),
            )
          else if (_comments.isEmpty)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('暂无评论，快来抢沙发吧~', style: TextStyle(color: AppColors.textHint)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final comment = _comments[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _CommentCard(comment: comment),
                    );
                  },
                  childCount: _comments.length,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
      bottomSheet: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _showCommentModal,
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppColors.tagBackground,
                        borderRadius: BorderRadius.circular(21),
                      ),
                      alignment: Alignment.centerLeft,
                      child: const Text('说点什么...', style: TextStyle(color: AppColors.textHint)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => context.read<PostProvider>().toggleLike(latestPost),
                  icon: Icon(
                    latestPost.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: latestPost.isLiked ? const Color(0xFFFF6B6B) : AppColors.textSecondary,
                  ),
                ),
                IconButton(
                  onPressed: () => context.read<PostProvider>().toggleFavorite(latestPost),
                  icon: Icon(
                    latestPost.isFavorited ? Icons.star : Icons.star_border,
                    color: latestPost.isFavorited ? const Color(0xFFFFB300) : AppColors.textSecondary,
                  ),
                ),
                ElevatedButton(
                  onPressed: _contactGuide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text('找TA下单'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on TravelPost {
  String get cityLabelOrDefault {
    final tag = this.tag.trim();
    if (tag.isNotEmpty) return tag;
    return '苏州';
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _PostStatRow extends StatelessWidget {
  final TravelPost post;

  const _PostStatRow({required this.post});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatItem(value: '${post.likes}', label: '点赞'),
        _StatItem(value: '${post.commentCount}', label: '评论'),
        _StatItem(value: '${post.timeLabel}', label: '发布'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
    );
  }
}

class _CommentCard extends StatelessWidget {
  final PostComment comment;

  const _CommentCard({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: CachedNetworkImage(
            imageUrl: comment.userAvatar,
            width: 32,
            height: 32,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => const CircleAvatar(radius: 16, child: Icon(Icons.person, size: 16)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(comment.userName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text(comment.timeLabel, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                ],
              ),
              const SizedBox(height: 6),
              Text(comment.content, style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}
