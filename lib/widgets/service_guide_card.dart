import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_theme.dart';
import '../models/guide.dart';

class ServiceGuideCard extends StatelessWidget {
  final Guide guide;
  final String statusLabel;

  const ServiceGuideCard({
    super.key,
    required this.guide,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cover = guide.images.isNotEmpty ? guide.images.first : guide.avatar;
    final avatar = guide.avatar.isNotEmpty ? guide.avatar : cover;

    return GestureDetector(
      onTap: () => context.push('/guide/${guide.id}'),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E2E2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCover(cover),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 124,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAvatar(avatar),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                guide.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (guide.verified)
                                    const Icon(
                                      Icons.verified,
                                      size: 13,
                                      color: AppColors.textHint,
                                    ),
                                  if (guide.verified) const SizedBox(width: 3),
                                  Text(
                                    '${guide.rating.toStringAsFixed(1)}分',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        guide.description.isNotEmpty
                            ? guide.description
                            : '${guide.name}的本地陪游服务，支持定制路线和临时约伴。',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildStat(Icons.favorite_border, '${guide.likes}'),
                              _buildStat(Icons.chat_bubble_outline, '${guide.views}'),
                              _buildStat(Icons.star_border, '${guide.fans}'),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 56,
                          height: 28,
                          child: ElevatedButton(
                            onPressed: () => context.push(
                              '/order/create?guideId=${guide.id}&name=${Uri.encodeComponent(guide.name)}&avatar=${Uri.encodeComponent(avatar)}',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const FittedBox(
                              child: Text(
                                '去下单',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
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

  Widget _buildCover(String url) {
    if (url.isEmpty) {
      return Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          color: AppColors.tagBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.image_outlined, color: AppColors.primary),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: url,
        width: 112,
        height: 112,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 112,
          height: 112,
          color: AppColors.tagBackground,
        ),
        errorWidget: (context, url, error) => Container(
          width: 112,
          height: 112,
          color: AppColors.tagBackground,
          child: const Icon(Icons.image_outlined, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildAvatar(String url) {
    if (url.isEmpty) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
          color: AppColors.tagBackground,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.person, size: 14, color: AppColors.primary),
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
          child: const Icon(Icons.person, size: 14, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textHint),
        const SizedBox(width: 3),
        Text(value, style: const TextStyle(fontSize: 12, color: AppColors.primary)),
      ],
    );
  }
}
