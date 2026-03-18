import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/travel_post.dart';
import '../../providers/post_provider.dart';
import '../../widgets/travel_card.dart';

class FootprintPostsPage extends StatefulWidget {
  const FootprintPostsPage({super.key});

  @override
  State<FootprintPostsPage> createState() => _FootprintPostsPageState();
}

class _FootprintPostsPageState extends State<FootprintPostsPage> {
  bool _isLoading = true;
  List<TravelPost> _footprints = [];

  @override
  void initState() {
    super.initState();
    _loadFootprints();
  }

  Future<void> _loadFootprints() async {
    final provider = context.read<PostProvider>();
    final posts = await provider.fetchFootprints();
    if (mounted) {
      setState(() {
        _footprints = posts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('我的足迹'),
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

    if (_footprints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_walk, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('暂无浏览记录', style: AppTextStyles.subtitle),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFootprints,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        itemCount: _footprints.length,
        itemBuilder: (context, index) {
          final post = _footprints[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              height: 280,
              child: TravelCard(
                post: post,
              ),
            ),
          );
        },
      ),
    );
  }
}
