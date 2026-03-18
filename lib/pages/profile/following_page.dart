import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../providers/user_provider.dart';
import '../../providers/guide_provider.dart';
import '../../models/user.dart';
import '../../config/app_theme.dart';

class FollowingPage extends StatefulWidget {
  const FollowingPage({super.key});

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  List<User> _followingUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFollowingUsers();
  }

  Future<void> _loadFollowingUsers() async {
    setState(() => _isLoading = true);
    final users = await context.read<UserProvider>().getFollowingUsers();
    if (mounted) {
      setState(() {
        _followingUsers = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _unfollowUser(User targetUser) async {
    try {
      await context.read<UserProvider>().unfollowUser(targetUser.id);
      if (mounted) {
        setState(() {
          _followingUsers.removeWhere((u) => u.id == targetUser.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消关注'), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('我关注的博主', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _followingUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text('还没有关注任何人喔', style: AppTextStyles.subtitle),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _followingUsers.length,
                  itemBuilder: (context, index) {
                    final user = _followingUsers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: user.avatar.isNotEmpty ? user.avatar : 'https://picsum.photos/seed/${user.id}/100/100',
                            width: 48, height: 48, fit: BoxFit.cover,
                            placeholder: (context, url) => Container(width: 48, height: 48, color: AppColors.tagBackground),
                            errorWidget: (context, url, error) => const CircleAvatar(radius: 24, child: Icon(Icons.person, size: 24)),
                          ),
                        ),
                        title: Text(user.nickname, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        subtitle: Text(user.title.isNotEmpty ? user.title : '个人用户', 
                                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        trailing: OutlinedButton(
                          onPressed: () => _unfollowUser(user),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.divider),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text('取消关注', style: TextStyle(fontSize: 12)),
                        ),
                        onTap: () {
                          final isGuide = context.read<GuideProvider>().guides.any((g) => g.id == user.id);
                          if (isGuide) {
                            context.push('/guide/${user.id}');
                          } else {
                            context.push('/user/${user.id}');
                          }
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
