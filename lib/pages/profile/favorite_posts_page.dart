import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/travel_post.dart';
import '../../providers/post_provider.dart';
import '../../widgets/travel_card.dart';

class FavoritePostsPage extends StatefulWidget {
  const FavoritePostsPage({super.key});

  @override
  State<FavoritePostsPage> createState() => _FavoritePostsPageState();
}

class _FavoritePostsPageState extends State<FavoritePostsPage> {
  bool _isLoading = true;
  List<TravelPost> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final provider = context.read<PostProvider>();
    final posts = await provider.fetchFavoritedPosts();
    if (mounted) {
      setState(() {
        _favorites = posts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('我的收藏'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_border, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('暂无收藏内容', style: AppTextStyles.subtitle),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        itemCount: _favorites.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.7,
        ),
        itemBuilder: (context, index) => TravelCard(post: _favorites[index]),
      ),
    );
  }
}
