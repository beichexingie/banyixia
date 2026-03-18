import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/travel_post.dart';
import '../../providers/post_provider.dart';

class TravelCard extends StatelessWidget {
  final TravelPost post;

  const TravelCard({super.key, required this.post});

  void _showPostDetail(BuildContext context) {
    context.push('/post/${post.id}');
  }

  // Helper removed as it's no longer used in bottom sheet

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPostDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: CachedNetworkImage(
                      imageUrl: post.coverImage, width: double.infinity, fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.tagBackground,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.tagBackground,
                        child: const Icon(Icons.image, color: AppColors.primary),
                      ),
                    ),
                  ),
                  if (post.tag.isNotEmpty)
                    Positioned(
                      bottom: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(post.tag, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary, height: 1.3),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: post.authorAvatar, width: 20, height: 20, fit: BoxFit.cover,
                            placeholder: (context, url) => Container(width: 20, height: 20, color: AppColors.tagBackground),
                            errorWidget: (context, url, error) => Container(
                              width: 20, height: 20,
                              decoration: const BoxDecoration(color: AppColors.tagBackground, shape: BoxShape.circle),
                              child: const Icon(Icons.person, size: 12, color: AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(child: Text(post.authorName, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption)),
                        // 点赞按钮 — 可点击
                        GestureDetector(
                          onTap: () {
                            context.read<PostProvider>().toggleLike(post);
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                post.isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 14,
                                color: post.isLiked ? const Color(0xFFFF6B6B) : AppColors.textHint,
                              ),
                              const SizedBox(width: 2),
                              Text('${post.likes}', style: AppTextStyles.caption),
                              const SizedBox(width: 8),
                              const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.textHint),
                              const SizedBox(width: 2),
                              Text('${post.commentCount}', style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
