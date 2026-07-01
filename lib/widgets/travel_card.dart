import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../config/app_theme.dart';
import '../models/travel_post.dart';
import '../providers/post_provider.dart';

class TravelCard extends StatelessWidget {
  final TravelPost post;
  final String? cityLabel;

  const TravelCard({
    super.key,
    required this.post,
    this.cityLabel,
  });

  @override
  Widget build(BuildContext context) {
    final locationLabel = _resolveLocationLabel();

    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: CachedNetworkImage(
                        imageUrl: post.coverImage,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.surfaceMuted,
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: AppColors.surfaceMuted,
                          child: const Icon(
                            Icons.image_outlined,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (locationLabel.isNotEmpty)
                    Positioned(
                      left: 12,
                      bottom: 10,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            locationLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: post.authorAvatar,
                          width: 22,
                          height: 22,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            width: 22,
                            height: 22,
                            color: AppColors.surfaceMuted,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.person,
                              size: 13,
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.read<PostProvider>().toggleLike(post),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              post.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 21,
                              color: post.isLiked
                                  ? const Color(0xFFFF7A7A)
                                  : AppColors.textHint,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${post.likes}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
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

  String _resolveLocationLabel() {
    final explicitCity = (cityLabel ?? '').trim();
    if (explicitCity.isNotEmpty) {
      return explicitCity;
    }

    final fallback = post.tag.trim();
    if (fallback.isEmpty) {
      return '';
    }
    return fallback;
  }
}
