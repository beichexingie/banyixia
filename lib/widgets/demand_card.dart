import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../models/demand_request.dart';

class DemandCard extends StatelessWidget {
  final DemandRequest demand;
  final bool compact;

  const DemandCard({super.key, required this.demand, this.compact = false});

  List<String> get _previewImages {
    if (demand.images.isEmpty) {
      return const [
        'https://picsum.photos/seed/demand-card-a/400/300',
        'https://picsum.photos/seed/demand-card-b/400/300',
        'https://picsum.photos/seed/demand-card-c/400/300',
      ];
    }
    if (demand.images.length == 1) {
      return [demand.images.first, demand.images.first, demand.images.first];
    }
    if (demand.images.length == 2) {
      return [demand.images[0], demand.images[1], demand.images[1]];
    }
    return demand.images.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final images = _previewImages;

    return GestureDetector(
      onTap: () => _showDetailSheet(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: demand.authorAvatar,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorWidget: (context, url, error) => Container(
                      width: 50,
                      height: 50,
                      color: AppColors.surfaceMuted,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person,
                        size: 24,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          demand.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '3',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 15,
                        color: AppColors.textPrimary,
                      ),
                      SizedBox(width: 3),
                      Text(
                        '报名中',
                        style: TextStyle(
                          fontSize: 15,
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
                    demand.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              demand.content,
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: List.generate(
                images.length,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == images.length - 1 ? 0 : 10,
                    ),
                    child: _buildImage(images[index]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _metaLine(
                          Icons.place_outlined,
                          '${demand.city}·${demand.location}',
                        ),
                        const SizedBox(height: 10),
                        _metaLine(Icons.schedule_outlined, _compactTimeLabel()),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 54,
                    color: const Color(0xFFDCDCDC),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '已报名',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ...List.generate(
                            demand.applicantCount > 3
                                ? 3
                                : demand.applicantCount,
                            (index) => Transform.translate(
                              offset: Offset(index == 0 ? 0 : -6.0 * index, 0),
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.5,
                                  ),
                                  image: DecorationImage(
                                    image: NetworkImage(
                                      'https://picsum.photos/seed/demand-avatar-$index/40/40',
                                    ),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${demand.applicantCount}人',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
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

  Widget _metaLine(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.primaryDeep),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _compactTimeLabel() {
    final start = demand.serviceStartAt;
    final end = demand.serviceEndAt;
    final days = end.difference(start).inDays + 1;
    return '${start.month}月${start.day}日-${end.month}月${end.day}日 | ${days}天';
  }

  Widget _buildImage(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 1,
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              Container(color: AppColors.surfaceMuted),
          errorWidget: (context, url, error) => Container(
            color: AppColors.surfaceMuted,
            child: const Icon(Icons.image_outlined, color: AppColors.textHint),
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                demand.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                demand.content,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
