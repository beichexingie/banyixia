import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/travel_post.dart';
import '../../models/post_comment.dart';
import '../../providers/post_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/guide_provider.dart';
import '../../config/app_theme.dart';

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
    // Record footprint when viewing post
    context.read<PostProvider>().recordFootprint(widget.post.id);
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
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _showShareModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('分享到', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _shareIcon(Icons.wechat, '微信好友', Colors.green),
                  _shareIcon(Icons.camera, '朋友圈', Colors.greenAccent),
                  _shareIcon(Icons.link, '复制链接', Colors.blue),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _shareIcon(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '写下你的评论...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: AppColors.tagBackground,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () async {
                    if (_commentController.text.trim().isEmpty) return;
                    
                    final content = _commentController.text.trim();
                    Navigator.pop(ctx); // Close modal first
                    _commentController.clear();
                    
                    try {
                      await context.read<PostProvider>().addComment(widget.post.id, content);
                      _loadComments(); // Refresh list
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('评论成功'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
                        );
                      }
                    }
                  },
                  child: const Text('发送', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentList() {
    if (_isLoadingComments) {
      return const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator(color: AppColors.primary))),
      );
    }
    
    if (_comments.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(40), child: Center(child: Text('暂无评论，快来抢沙发吧~', style: TextStyle(color: AppColors.textHint)))),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final comment = _comments[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: comment.userAvatar, width: 32, height: 32, fit: BoxFit.cover,
                    errorWidget: (context, url, error) => const Icon(Icons.person, size: 32),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(comment.userName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text('${comment.createdAt.month}-${comment.createdAt.day} ${comment.createdAt.hour}:${comment.createdAt.minute}', style: AppTextStyles.caption),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(comment.content, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        childCount: _comments.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // 顶部全屏图片带返回按钮
          SliverAppBar(
            expandedHeight: 300.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: widget.post.coverImage,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: AppColors.tagBackground),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.tagBackground,
                  child: const Icon(Icons.image, size: 48, color: AppColors.primary),
                ),
              ),
            ),
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: _showShareModal,
              ),
            ],
          ),
          // 内容区域
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(widget.post.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  // 作者信息
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      final isGuide = context.read<GuideProvider>().guides.any((g) => g.id == widget.post.authorId);
                      if (isGuide) {
                        context.push('/guide/${widget.post.authorId}');
                      } else {
                        context.push('/user/${widget.post.authorId}');
                      }
                    },
                    child: Row(
                      children: [
                        ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: widget.post.authorAvatar, width: 40, height: 40, fit: BoxFit.cover,
                            placeholder: (context, url) => Container(width: 40, height: 40, color: AppColors.tagBackground),
                            errorWidget: (context, url, error) => const CircleAvatar(radius: 20, child: Icon(Icons.person, size: 20)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.post.authorName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            Text('发布于 ${widget.post.createdAt.year}/${widget.post.createdAt.month}/${widget.post.createdAt.day}', style: AppTextStyles.caption),
                          ],
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: _toggleFollow,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isFollowing ? AppColors.textSecondary : AppColors.primary,
                            side: BorderSide(color: _isFollowing ? AppColors.divider : AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          ),
                          child: _isFollowLoading 
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                            : Text(_isFollowing ? '已关注' : '关注', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  // 详细内容
                  Text(
                    widget.post.content ?? '这是一段旅行笔记的详细内容。在这里可以看到完整的旅行攻略、行程安排、美食推荐等信息。\n\n'
                    '📍 第一天：抵达目的地，入住酒店，逛周边老街。老街有很多特色小吃，建议空腹前往！\n\n'
                    '📍 第二天：打卡网红景点，品尝当地美食。记得提前在网上买好门票，避免排长队。\n\n'
                    '📍 第三天：深度体验当地文化，购买纪念品。如果要买特产，建议去当地的大超市而不是旅游街。\n\n'
                    '💡 小贴士：当地早晚温差较大，哪怕是夏天也要带一件薄外套~ 还有防晒霜一定不能忘！',
                    style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.8),
                  ),
                  const SizedBox(height: 30),
                  if (widget.post.tag.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.tagBackground, borderRadius: BorderRadius.circular(12)),
                      child: Text('# ${widget.post.tag}', style: AppTextStyles.tag),
                    ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 20),
                  const Text('全部评论', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          _buildCommentList(),
          // 关联向导卡片（引流逻辑）
          Consumer<GuideProvider>(
            builder: (context, guideProvider, child) {
              final isGuide = guideProvider.guides.any((g) => g.id == widget.post.authorId);
              if (!isGuide) {
                return const SliverToBoxAdapter(child: SizedBox(height: 100)); // 底部留白
              }

              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Text('想和作者一起出发？', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () {
                                    context.push('/guide/${widget.post.authorId}');
                                  },
                                  child: Row(
                                    children: [
                                      const Text('去咨询', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                                      const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.primary),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text('该作者同时也是平台认证地陪，点击咨询可预订其陪游服务。', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      // 底部悬浮条
      bottomSheet: Container(
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: GestureDetector(
                  onTap: _showCommentModal,
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: AppColors.tagBackground, borderRadius: BorderRadius.circular(18)),
                    alignment: Alignment.centerLeft,
                    child: const Text('说点什么...', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Consumer<PostProvider>(
                builder: (context, provider, _) {
                  // Find the post in the provider to get the latest state
                  final latestPost = provider.posts.firstWhere(
                    (p) => p.id == widget.post.id,
                    orElse: () => widget.post,
                  );
                  final isLiked = latestPost.isLiked;
                  return GestureDetector(
                    onTap: () => provider.toggleLike(latestPost),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(isLiked ? Icons.favorite : Icons.favorite_border,
                            color: isLiked ? const Color(0xFFFF6B6B) : AppColors.textSecondary, size: 24),
                        const SizedBox(width: 4),
                        Text('${latestPost.likes}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 20),
              Consumer<PostProvider>(
                builder: (context, provider, _) {
                  // Find the post in the provider to get the latest state
                  final latestPost = provider.posts.firstWhere(
                    (p) => p.id == widget.post.id,
                    orElse: () => widget.post,
                  );
                  final isFavorited = latestPost.isFavorited;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      provider.toggleFavorite(latestPost);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(isFavorited ? Icons.star : Icons.star_border, color: isFavorited ? const Color(0xFFFFB300) : AppColors.textSecondary, size: 24),
                          const SizedBox(width: 4),
                          Text(isFavorited ? '已收藏' : '收藏', style: TextStyle(fontWeight: FontWeight.w600, color: isFavorited ? const Color(0xFFFFB300) : AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }
}
