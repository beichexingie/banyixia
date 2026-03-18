import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/guide.dart';
import '../../providers/guide_provider.dart';
import 'package:provider/provider.dart';

class GuideCard extends StatelessWidget {
  final Guide guide;

  const GuideCard({super.key, required this.guide});

  void _showGuideDetail(BuildContext context) {
    context.push('/guide/${guide.id}');
  }

  // Viewers/Stat helper method removed, not needed globally

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showGuideDetail(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧大图
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    // 默认显示相册里的第一张作为大图，如果没有则显示头像
                    imageUrl: guide.images.isNotEmpty ? guide.images[0] : guide.avatar, 
                    width: 100, 
                    height: 130, 
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(width: 100, height: 130, color: AppColors.tagBackground),
                    errorWidget: (context, url, error) => Container(
                      width: 100, height: 130, color: AppColors.tagBackground,
                      child: const Icon(Icons.broken_image, color: AppColors.textHint),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        const Text('今天来过', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // 右侧信息
            Expanded(
              child: SizedBox(
                height: 130, // 强制与左侧图片同高以便按设计排布上下内容
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // // 第一行：小头像，名字，徽章，评分，查看全部
                    Row(
                      children: [
                        ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: guide.avatar, width: 20, height: 20, fit: BoxFit.cover,
                            errorWidget: (context, url, error) => const Icon(Icons.person, size: 20),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            guide.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ),
                        const SizedBox(width: 4),
                        // 树形徽章 (这里先用park代替UI中的绿色图标)
                        const Icon(Icons.park, size: 14, color: Color(0xFF4CAF50)),
                        const SizedBox(width: 6),
                        const Icon(Icons.star, size: 14, color: AppColors.starColor),
                        Text('${guide.rating}分', style: const TextStyle(fontSize: 12, color: AppColors.starColor, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        const Text('查看全部> ', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 简介
                    Text(
                      guide.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                    ),
                    const Spacer(), // 占据剩余空间
                    // 底部互动数据 & 去下单
                    Consumer<GuideProvider>(
                      builder: (context, provider, child) {
                        final isLiked = provider.likedIds.contains(guide.id);
                        final isFavorited = provider.favoriteIds.contains(guide.id);
                        
                        return Row(
                          children: [
                            // 互动数据区域
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                physics: const NeverScrollableScrollPhysics(),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    GestureDetector(
                                      onTap: () => provider.toggleLike(guide.id),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isLiked ? Icons.favorite : Icons.favorite_border, 
                                            size: 14, 
                                            color: isLiked ? Colors.red : AppColors.textHint
                                          ),
                                          const SizedBox(width: 2),
                                          Text('${guide.likes + (isLiked ? 1 : 0)}', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.chat_bubble_outline, size: 14, color: AppColors.textHint),
                                    const SizedBox(width: 2),
                                    const Text('11', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => provider.toggleFavorite(guide.id),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isFavorited ? Icons.star : Icons.star_border, 
                                            size: 14, 
                                            color: isFavorited ? Colors.amber : AppColors.textHint
                                          ),
                                          const SizedBox(width: 2),
                                          Text('${guide.fans + (isFavorited ? 1 : 0)}', style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => context.push('/order_create', extra: guide),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF9A3E),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Text('去下单', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        );
                      },
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
