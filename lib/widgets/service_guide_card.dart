import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_theme.dart';
import '../config/guide_sort.dart';
import '../models/guide.dart';

class ServiceGuideCard extends StatelessWidget {
  final Guide guide;
  final bool compact;
  final bool listCompact;

  const ServiceGuideCard({
    super.key,
    required this.guide,
    this.compact = false,
    this.listCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (listCompact) {
      return _buildListCompactCard(context);
    }
    if (compact) {
      return _buildCompactCard(context);
    }

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
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
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
            const SizedBox(width: 12),
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
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              rating,
                              style: const TextStyle(
                                fontSize: 14,
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
                  const SizedBox(height: 8),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Color(0xFF8B8B8B),
                    ),
                  ),
                  if (guide.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: guide.tags.take(4).map(_serviceTag).toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      height: 36,
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
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        child: const Text(
                          '去下单',
                          style: TextStyle(
                            fontSize: 15,
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

  Widget _buildCompactCard(BuildContext context) {
    final avatar = guide.avatar.isNotEmpty
        ? guide.avatar
        : (guide.images.isNotEmpty ? guide.images.first : '');
    final name = guide.name.trim().isEmpty ? '本地地陪' : guide.name.trim();
    final rating = guide.rating == 0 ? '暂无评分' : guide.rating.toStringAsFixed(1);
    final city = guide.city.trim().isEmpty ? '服务地待完善' : guide.city.trim();

    return GestureDetector(
      onTap: () => context.push('/guide/${guide.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.035),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: avatar.isEmpty
                  ? Container(
                      width: double.infinity,
                      color: AppColors.surfaceMuted,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person,
                        size: 38,
                        color: AppColors.textHint,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: avatar,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (context, url) =>
                          Container(color: AppColors.surfaceMuted),
                      errorWidget: (context, url, error) => Container(
                        color: AppColors.surfaceMuted,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.person,
                          size: 38,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontSize: 10.5,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF2A439),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    city,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      height: 1.1,
                      color: AppColors.textHint,
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

  Widget _buildListCompactCard(BuildContext context) {
    final avatar = guide.avatar.isNotEmpty
        ? guide.avatar
        : (guide.images.isNotEmpty ? guide.images.first : '');
    final name = guide.name.trim().isEmpty ? '本地地陪' : guide.name.trim();
    final rating = guide.rating == 0
        ? '暂无评分'
        : '${guide.rating.toStringAsFixed(1)}分';
    final status = formatNextAvailableGuideTime(nextAvailableGuideTime(guide));
    final description = guide.description.trim().isEmpty
        ? '这位地陪还没有填写详细介绍'
        : guide.description.trim();
    final likes = guide.likes > 0 ? guide.likes : guide.fans;
    final reviews = guide.reviews.length;
    final orders = guide.completedOrders > 0
        ? guide.completedOrders
        : guide.totalOrders;

    return InkWell(
      onTap: () => context.push('/guide/${guide.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 96),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatarSmall(avatar),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF2A439),
                        ),
                      ),
                      if (status.isNotEmpty) ...[
                        const Spacer(),
                        Flexible(
                          child: Text(
                            status,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _statItem(Icons.favorite_border, likes),
                      const SizedBox(width: 12),
                      _statItem(Icons.chat_bubble_outline, reviews),
                      const SizedBox(width: 12),
                      _statItem(Icons.star_border, orders),
                      const Spacer(),
                      SizedBox(
                        height: 26,
                        child: ElevatedButton(
                          onPressed: () => context.push(
                            '/order/create?guideId=${guide.id}',
                            extra: guide,
                          ),
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: const Text(
                            '去下单',
                            style: TextStyle(
                              fontSize: 11,
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
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(49),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.person, size: 28, color: AppColors.textHint),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(49),
      child: CachedNetworkImage(
        imageUrl: avatar,
        width: 78,
        height: 78,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Container(width: 78, height: 78, color: AppColors.surfaceMuted),
        errorWidget: (context, url, error) => Container(
          width: 78,
          height: 78,
          color: AppColors.surfaceMuted,
          alignment: Alignment.center,
          child: const Icon(Icons.person, size: 34, color: AppColors.textHint),
        ),
      ),
    );
  }

  Widget _buildAvatarSmall(String avatar) {
    if (avatar.isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: const BoxDecoration(
          color: AppColors.surfaceMuted,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.person, size: 26, color: AppColors.textHint),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: avatar,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            Container(width: 58, height: 58, color: AppColors.surfaceMuted),
        errorWidget: (context, url, error) => Container(
          width: 58,
          height: 58,
          color: AppColors.surfaceMuted,
          alignment: Alignment.center,
          child: const Icon(Icons.person, size: 26, color: AppColors.textHint),
        ),
      ),
    );
  }

  Widget _statItem(IconData icon, int value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textHint),
        const SizedBox(width: 3),
        Text(
          '$value',
          style: const TextStyle(fontSize: 10, color: AppColors.textHint),
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
}
