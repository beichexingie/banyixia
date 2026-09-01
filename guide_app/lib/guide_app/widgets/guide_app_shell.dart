import 'package:flutter/material.dart';

import '../../config/app_theme.dart';

class GuideAppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool safeAreaTop;
  final Color? backgroundColor;

  const GuideAppScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.safeAreaTop = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final wrappedBody = safeAreaTop ? SafeArea(child: body) : body;
    return Scaffold(
      backgroundColor: backgroundColor ?? AppColors.background,
      appBar: appBar,
      body: wrappedBody,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

class GuideSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const GuideSectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class GuidePillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final IconData? icon;
  final Color? color;
  final Color? foregroundColor;

  const GuidePillButton({
    super.key,
    required this.label,
    this.onTap,
    this.active = false,
    this.icon,
    this.color,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final background = color ??
        (active ? AppColors.primary : const Color(0xFFF1F2F5));
    final textColor = foregroundColor ??
        (active ? AppColors.textPrimary : AppColors.textSecondary);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: textColor),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
