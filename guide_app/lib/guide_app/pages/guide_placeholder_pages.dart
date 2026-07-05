import 'package:flutter/material.dart';

import '../../config/app_theme.dart';
import '../widgets/guide_app_shell.dart';

class GuidePlaceholderPage extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;

  const GuidePlaceholderPage({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.construction_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return GuideAppScaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: GuideSectionCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 68, color: AppColors.primaryDark),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
