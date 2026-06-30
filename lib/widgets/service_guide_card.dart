import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/app_theme.dart';
import '../models/guide.dart';

class ServiceGuideCard extends StatelessWidget {
  final Guide guide;
  final String statusLabel;
  final bool compact;

  const ServiceGuideCard({
    super.key,
    required this.guide,
    required this.statusLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cover = guide.images.isNotEmpty ? guide.images.first : guide.avatar;
    final avatar = guide.avatar.isNotEmpty ? guide.avatar : cover;

    if (compact) {
      return _CompactServiceGuideCard(
        guide: guide,
        cover: cover,
        avatar: avatar,
        statusLabel: statusLabel,
      );
    }

    return GestureDetector(
      onTap: () => context.push('/guide/${guide.id}'),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
            _GuideImage(url: cover, width: 104, height: 112, radius: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _GuideAvatar(url: avatar),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          guide.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      _StatusChip(label: statusLabel),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (guide.city.trim().isNotEmpty) _MiniTag(text: guide.city),
                      _MiniTag(
                        text: '${guide.rating.toStringAsFixed(1)}分',
                        color: const Color(0xFFFFF4E8),
                        textColor: AppColors.accent,
                      ),
                      if (guide.verified) _MiniTag(text: '已认证'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    guide.description.isNotEmpty
                        ? guide.description
                        : '${guide.name}的本地陪游服务，支持定制路线和临时约伴。',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _Stat(icon: Icons.favorite_border, value: '${guide.likes}'),
                      const SizedBox(width: 12),
                      _Stat(icon: Icons.chat_bubble_outline, value: '${guide.views}'),
                      const SizedBox(width: 12),
                      _Stat(icon: Icons.star_border, value: '${guide.fans}'),
                      const Spacer(),
                      _ActionButton(
                        label: '去下单',
                        onTap: () => context.push(
                          '/order/create?guideId=${guide.id}&name=${Uri.encodeComponent(guide.name)}&avatar=${Uri.encodeComponent(avatar)}',
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
}

class _CompactServiceGuideCard extends StatelessWidget {
  final Guide guide;
  final String cover;
  final String avatar;
  final String statusLabel;

  const _CompactServiceGuideCard({
    required this.guide,
    required this.cover,
    required this.avatar,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/guide/${guide.id}'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.photo_library_outlined, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '地陪',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    guide.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${guide.rating.toStringAsFixed(1)}分',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _GuideImage(url: cover, width: 92, height: 92, radius: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _GuideAvatar(url: avatar, size: 28),
                          const SizedBox(width: 8),
                          if (guide.verified) const _MiniTag(text: '认证'),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              statusLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        guide.description.isNotEmpty
                            ? guide.description
                            : '${guide.name}提供本地陪玩、定制路线和即时出行协助。',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _Stat(icon: Icons.favorite_border, value: '${guide.likes}'),
                const SizedBox(width: 18),
                _Stat(icon: Icons.chat_bubble_outline, value: '${guide.views}'),
                const SizedBox(width: 18),
                _Stat(icon: Icons.star_border, value: '${guide.fans}'),
                const Spacer(),
                _ActionButton(
                  label: '去下单',
                  onTap: () => context.push(
                    '/order/create?guideId=${guide.id}&name=${Uri.encodeComponent(guide.name)}&avatar=${Uri.encodeComponent(avatar)}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideImage extends StatelessWidget {
  final String url;
  final double width;
  final double height;
  final double radius;

  const _GuideImage({
    required this.url,
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.tagBackground,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: const Icon(Icons.image_outlined, color: AppColors.textHint),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: AppColors.tagBackground,
          child: const Icon(Icons.image_outlined, color: AppColors.textHint),
        ),
      ),
    );
  }
}

class _GuideAvatar extends StatelessWidget {
  final String url;
  final double size;

  const _GuideAvatar({required this.url, this.size = 24});

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.tagBackground,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.person, size: size * 0.58, color: AppColors.textHint),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => Container(
          width: size,
          height: size,
          color: AppColors.tagBackground,
          child: Icon(Icons.person, size: size * 0.58, color: AppColors.textHint),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  final String text;
  final Color? color;
  final Color? textColor;

  const _MiniTag({required this.text, this.color, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textColor ?? AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tagBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;

  const _Stat({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 46,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(23),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
