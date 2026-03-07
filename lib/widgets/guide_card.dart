import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../models/guide.dart';

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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: guide.avatar, width: 44, height: 44, fit: BoxFit.cover,
                    placeholder: (context, url) => Container(width: 44, height: 44, color: AppColors.tagBackground),
                    errorWidget: (context, url, error) => Container(
                      width: 44, height: 44,
                      decoration: const BoxDecoration(color: AppColors.tagBackground, shape: BoxShape.circle),
                      child: const Icon(Icons.person, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(guide.name, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          ),
                          const SizedBox(width: 6),
                          if (guide.gender.isNotEmpty)
                            Container(
                              width: 18, height: 18,
                              decoration: BoxDecoration(
                                color: guide.gender == '女' ? const Color(0xFFFFB6C1) : const Color(0xFF87CEEB),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(guide.gender == '女' ? Icons.female : Icons.male, size: 12, color: Colors.white),
                            ),
                          if (guide.verified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 16, color: AppColors.primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: AppColors.starColor),
                          const SizedBox(width: 2),
                          Text('${guide.rating}分', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: AppColors.divider),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: guide.rating / 5.0,
                                child: Container(
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), gradient: AppColors.primaryGradient),
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
            const SizedBox(height: 10),
            if (guide.tags.isNotEmpty)
              Wrap(
                spacing: 6, runSpacing: 4,
                children: guide.tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(tag, style: const TextStyle(fontSize: 11, color: Color(0xFF4CAF50), fontWeight: FontWeight.w500)),
                  );
                }).toList(),
              ),
            if (guide.tags.isNotEmpty) const SizedBox(height: 8),
            Text(guide.description, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            if (guide.images.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: guide.images.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: guide.images[index], width: 80, height: 80, fit: BoxFit.cover,
                        placeholder: (context, url) => Container(width: 80, height: 80, color: AppColors.tagBackground),
                        errorWidget: (context, url, error) => Container(
                          width: 80, height: 80, color: AppColors.tagBackground,
                          child: const Icon(Icons.image, color: AppColors.primary, size: 20),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.remove_red_eye_outlined, size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text('${guide.views}', style: AppTextStyles.caption),
                const SizedBox(width: 16),
                const Icon(Icons.thumb_up_outlined, size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text('${guide.likes}', style: AppTextStyles.caption),
                const SizedBox(width: 16),
                const Icon(Icons.people_outline, size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text('${guide.fans}', style: AppTextStyles.caption),
                const Spacer(),
                Text('了解更多 >', style: AppTextStyles.tag),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
