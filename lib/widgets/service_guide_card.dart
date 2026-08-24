import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_theme.dart';
import '../config/guide_sort.dart';
import '../models/guide.dart';

class ServiceGuideCard extends StatelessWidget {
  final Guide guide;

  const ServiceGuideCard({super.key, required this.guide});

  @override
  Widget build(BuildContext context) {
    final avatar = guide.avatar.isNotEmpty
        ? guide.avatar
        : (guide.images.isNotEmpty ? guide.images.first : '');
    final rating = guide.rating == 0
        ? '暂无评分'
        : '${guide.rating.toStringAsFixed(1)}分';
    final status = formatNextAvailableGuideTime(nextAvailableGuideTime(guide));
    final name = guide.name.trim().isEmpty ? '本地导游' : guide.name.trim();
    final description = guide.description.trim().isNotEmpty
        ? guide.description.trim()
        : '暂未填写服务介绍';

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
                      if (status.isNotEmpty)
                        Flexible(
                          child: Text(
                            status,
                            softWrap: true,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF939393),
                            ),
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        onPressed: () => context.push(
                          '/order/create?guideId=${guide.id}',
                          extra: guide,
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
}
