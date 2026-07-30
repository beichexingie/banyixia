import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_theme.dart';
import '../models/guide.dart';

class ServiceGuideCard extends StatelessWidget {
  final Guide guide;
  final String statusLabel;
  final String? rankLabel;

  const ServiceGuideCard({
    super.key,
    required this.guide,
    required this.statusLabel,
    this.rankLabel,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = guide.avatar.isNotEmpty
        ? guide.avatar
        : (guide.images.isNotEmpty ? guide.images.first : '');
    final likes = guide.likes == 0 ? 10 : guide.likes;
    final comments = guide.views == 0 ? 209 : guide.views;
    final favorites = guide.fans == 0 ? 900 : guide.fans;
    final rating = guide.rating == 0
        ? '4.8分'
        : '${guide.rating.toStringAsFixed(1)}分';
    final name = guide.name.trim().isEmpty ? '本地导游' : guide.name.trim();
    final description = guide.description.trim().isNotEmpty
        ? guide.description.trim()
        : '这是详情这是详情这是详情这是详情这是详情这是详情这是详情这是详情这是详情...';

    return GestureDetector(
      onTap: () => context.push('/guide/${guide.id}'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(avatar),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if ((rankLabel ?? '').isNotEmpty)
                              _buildRankBadge(rankLabel!),
                            _buildVerifiedBadge(),
                            Text(
                              rating,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF2A439),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _normalizeStatus(statusLabel),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF939393),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.45,
                      color: Color(0xFF8B8B8B),
                    ),
                  ),
                  if (guide.tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: guide.tags.take(4).map(_serviceTag).toList(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 18,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _metric(Icons.favorite_border_rounded, '$likes'),
                      _metric(Icons.mode_comment_outlined, '$comments'),
                      _metric(Icons.star_border_rounded, '$favorites'),
                      SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          onPressed: () => context.push(
                            '/order/create?guideId=${guide.id}&name=${Uri.encodeComponent(guide.name)}&avatar=${Uri.encodeComponent(guide.avatar)}',
                          ),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                          ),
                          child: const Text(
                            '去下单',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
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

  Widget _buildAvatar(String avatar) {
    if (avatar.isEmpty) {
      return Container(
        width: 98,
        height: 98,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(49),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.person, size: 34, color: AppColors.textHint),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(49),
      child: CachedNetworkImage(
        imageUrl: avatar,
        width: 98,
        height: 98,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Container(width: 98, height: 98, color: AppColors.surfaceMuted),
        errorWidget: (context, url, error) => Container(
          width: 98,
          height: 98,
          color: AppColors.surfaceMuted,
          alignment: Alignment.center,
          child: const Icon(Icons.person, size: 34, color: AppColors.textHint),
        ),
      ),
    );
  }

  Widget _buildRankBadge(String text) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.check_rounded,
        size: 16,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _metric(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFFA7A7A7)),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(fontSize: 14, color: Color(0xFFA7A7A7)),
        ),
      ],
    );
  }

  Widget _serviceTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  String _normalizeStatus(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return '最早可约 今14:00';
    }
    return text;
  }
}
