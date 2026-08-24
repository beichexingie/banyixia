import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/guide_sort.dart';

class GuideSortMenuButton extends StatelessWidget {
  final GuideSortMode mode;
  final ValueChanged<GuideSortMode> onSelected;

  const GuideSortMenuButton({
    super.key,
    required this.mode,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<GuideSortMode>(
      initialValue: mode,
      onSelected: onSelected,
      itemBuilder: (context) => GuideSortMode.values
          .map(
            (item) => PopupMenuItem<GuideSortMode>(
              value: item,
              child: Text(item.label),
            ),
          )
          .toList(),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mode.label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
