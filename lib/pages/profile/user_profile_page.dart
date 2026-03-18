import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/user.dart';
import '../../models/travel_post.dart';
import '../../providers/user_provider.dart';
import '../../providers/post_provider.dart';
import '../../config/app_theme.dart';

/// 普通用户公开主页（非地陪）
class UserProfilePage extends StatefulWidget {
  final String userId;

  const UserProfilePage({super.key, required this.userId});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  User? _profileUser;
  List<TravelPost> _userPosts = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userProvider = context.read<UserProvider>();
    final postProvider = context.read<PostProvider>();

    final results = await Future.wait([
      userProvider.fetchUserById(widget.userId),
      postProvider.fetchPostsByUser(widget.userId),
      userProvider.isFollowing(widget.userId),
    ]);

    if (mounted) {
      setState(() {
        _profileUser = results[0] as User?;
        _userPosts = results[1] as List<TravelPost>;
        _isFollowing = results[2] as bool;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;
    setState(() => _isFollowLoading = true);
    try {
      final userProvider = context.read<UserProvider>();
      if (_isFollowing) {
        await userProvider.unfollowUser(widget.userId);
      } else {
        await userProvider.followUser(widget.userId);
      }
      final following = await userProvider.isFollowing(widget.userId);
      if (mounted) setState(() => _isFollowing = following);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isFollowLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_profileUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('用户主页'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        body: const Center(child: Text('未找到该用户', style: TextStyle(color: AppColors.textHint))),
      );
    }

    final user = _profileUser!;
    final isSelf = context.read<UserProvider>().user.id == widget.userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // 顶部渐变 AppBar
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // 渐变背景
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF9A3E), Color(0xFFFFC078)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // 用户信息
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                                child: ClipOval(
                                  child: CachedNetworkImage(
                                    imageUrl: user.avatar.isNotEmpty
                                        ? user.avatar
                                        : 'https://picsum.photos/seed/${user.id}/100/100',
                                    width: 72, height: 72, fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(width: 72, height: 72, color: Colors.white24),
                                    errorWidget: (context, url, error) => const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 36)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(user.nickname,
                                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                        if (user.vipLabel.isNotEmpty) ...[ 
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.3),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(user.vipLabel,
                                                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (user.title.isNotEmpty)
                                      Text(user.title,
                                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                                  ],
                                ),
                              ),
                              // 关注 / 取消关注 / 编辑资料
                              if (isSelf)
                                Container(
                                  margin: const EdgeInsets.only(left: 12),
                                  child: OutlinedButton(
                                    onPressed: () => context.push('/settings'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(color: Colors.white70),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                      minimumSize: const Size(0, 32),
                                    ),
                                    child: const Text('编辑资料', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                )
                              else
                                Container(
                                  margin: const EdgeInsets.only(left: 12),
                                  child: ElevatedButton(
                                    onPressed: _toggleFollow,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isFollowing ? Colors.white.withValues(alpha: 0.2) : Colors.white,
                                      foregroundColor: _isFollowing ? Colors.white : const Color(0xFFFF9A3E),
                                      elevation: _isFollowing ? 0 : 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                      minimumSize: const Size(0, 32),
                                    ),
                                    child: _isFollowLoading
                                        ? SizedBox(width: 14, height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: _isFollowing ? Colors.white : const Color(0xFFFF9A3E)))
                                        : Text(_isFollowing ? '已关注' : '+ 关注',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _statItem('关注', user.followCount),
                              const SizedBox(width: 24),
                              _statItem('粉丝', user.fansCount),
                              const SizedBox(width: 24),
                              _statItem('笔记', _userPosts.length),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 分隔标题
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Ta 的旅行笔记', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ),
          ),

          // 帖子列表
          _userPosts.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.note_alt_outlined, size: 56, color: AppColors.textHint.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        const Text('还没有发布过旅行笔记', style: TextStyle(color: AppColors.textHint)),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.75,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final post = _userPosts[index];
                        return _PostCard(post: post);
                      },
                      childCount: _userPosts.length,
                    ),
                  ),
                ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _statItem(String label, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }
}

class _PostCard extends StatelessWidget {
  final TravelPost post;
  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: CachedNetworkImage(
                imageUrl: post.coverImage,
                fit: BoxFit.cover,
                width: double.infinity,
                placeholder: (context, url) => Container(color: AppColors.tagBackground),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.tagBackground,
                  child: const Icon(Icons.image, color: AppColors.primary),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.favorite_border, size: 12, color: AppColors.textHint),
                      const SizedBox(width: 3),
                      Text('${post.likes}', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
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
