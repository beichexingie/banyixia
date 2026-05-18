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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCover(cover),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 7,
                              runSpacing: 3,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (guide.verified)
                                  const Icon(
                                    Icons.verified,
                                    size: 13,
                                    color: AppColors.textHint,
                                  ),
                                Text(
                                  '${guide.rating.toStringAsFixed(1)}分',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (guide.city.trim().isNotEmpty)
                                  _buildTag(guide.city.trim()),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(child: _buildStatusChip(statusLabel)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    guide.description.isNotEmpty
                        ? guide.description
                        : '${guide.name}的本地陪游服务，支持定制路线和临时约伴。',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 3,
                          children: [
                            _buildStat(Icons.favorite_border, '${guide.likes}'),
                            _buildStat(
                              Icons.chat_bubble_outline,
                              '${guide.views}',
                            ),
                            _buildStat(Icons.star_border, '${guide.fans}'),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 68,
                        height: 30,
                        child: ElevatedButton(
                          onPressed: () => context.push(
                            '/order/create?guideId=${guide.id}&name=${Uri.encodeComponent(guide.name)}&avatar=${Uri.encodeComponent(avatar)}',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            '去下单',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

  Widget _buildCover(String url) {
    if (url.isEmpty) {
      return Container(
        width: 104,
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
        width: 104,
        height: 112,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Container(width: 104, height: 112, color: AppColors.tagBackground),
        errorWidget: (context, url, error) => Container(
          width: 104,
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
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 11, color: AppColors.primary),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.tagBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.tagBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
