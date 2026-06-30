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

  const TravelCard({super.key, required this.post, this.cityLabel});

  void _showPostDetail(BuildContext context) {
    context.push('/post/${post.id}');
  }

  @override
  Widget build(BuildContext context) {
    final locationLabel = _resolveLocationLabel();
    final authorAvatar = post.authorAvatar.trim();

    return GestureDetector(
      onTap: () => _showPostDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: post.coverImage,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.tagBackground,
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.tagBackground,
                        child: const Icon(
                          Icons.image_outlined,
                          color: AppColors.textHint,
                          size: 36,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.05),
                              Colors.black.withValues(alpha: 0.42),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: _LocationPill(label: locationLabel),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      post.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        _Avatar(url: authorAvatar),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            post.authorName.isNotEmpty ? post.authorName : '用户昵称',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textHint,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            context.read<PostProvider>().toggleLike(post);
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                post.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 15,
                                color: post.isLiked
                                    ? const Color(0xFFFF6B6B)
                                    : AppColors.textHint,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${post.likes}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textHint,
                                  fontWeight: FontWeight.w500,
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
            ),
          ],
        ),
      ),
    );
  }

  String _resolveLocationLabel() {
    final explicitCity = (cityLabel ?? '').trim();
    if (explicitCity.isNotEmpty) return explicitCity;

    final fallback = post.tag.trim();
    if (fallback.isEmpty || const {'分享', '招募', '官方'}.contains(fallback)) {
      return '城市';
    }
    return fallback;
  }
}

class _LocationPill extends StatelessWidget {
  final String label;

  const _LocationPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.location_on_outlined,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;

  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.tagBackground,
        ),
        child: const Icon(
          Icons.person,
          size: 12,
          color: AppColors.textHint,
        ),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: 22,
        height: 22,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => Container(
          width: 22,
          height: 22,
          color: AppColors.tagBackground,
          child: const Icon(
            Icons.person,
            size: 12,
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }
}
