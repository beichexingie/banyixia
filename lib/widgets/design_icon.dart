import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Icons exported with the 375px mobile design. Keeping them in one widget
/// makes the navigation and category visual language consistent across pages.
class DesignIcon extends StatelessWidget {
  const DesignIcon(
    this.asset, {
    super.key,
    this.size = 24,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final String asset;
  final double size;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/design/$asset.svg',
      width: width ?? size,
      height: height ?? size,
      fit: fit,
      semanticsLabel: asset,
    );
  }
}
