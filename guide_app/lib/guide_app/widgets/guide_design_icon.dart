import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GuideDesignIcon extends StatelessWidget {
  const GuideDesignIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.color,
  });

  final String asset;
  final double size;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Some older design exports do not include every functional entry.
    // Keep those entries usable instead of letting one missing asset break a page.
    final fallback = _fallbackIcons[asset];
    if (fallback != null) {
      final requestedSize = width ?? height ?? size;
      return Icon(
        fallback,
        size: requestedSize.isFinite ? requestedSize : size,
        color: color ?? Colors.black87,
        semanticLabel: asset,
      );
    }
    return SvgPicture.asset(
      'assets/design/$asset.svg',
      width: width ?? size,
      height: height ?? size,
      fit: fit,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
      semanticsLabel: asset,
    );
  }

  static const Map<String, IconData> _fallbackIcons = {
    '地陪保险': Icons.shield_outlined,
    '屏蔽名单': Icons.person_off_outlined,
    '辅助设置': Icons.tune_rounded,
    '加号': Icons.add_rounded,
    '活动通知': Icons.campaign_outlined,
    '系统通知': Icons.notifications_none_rounded,
  };
}
