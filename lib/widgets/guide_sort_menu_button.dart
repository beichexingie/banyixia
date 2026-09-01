import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/guide_sort.dart';

class GuideSortMenuButton extends StatefulWidget {
  final GuideSortMode mode;
  final ValueChanged<GuideSortMode> onSelected;

  const GuideSortMenuButton({
    super.key,
    required this.mode,
    required this.onSelected,
  });

  @override
  State<GuideSortMenuButton> createState() => _GuideSortMenuButtonState();
}

class _GuideSortMenuButtonState extends State<GuideSortMenuButton> {
  final MenuController _menuController = MenuController();

  bool get _isOpen => _menuController.isOpen;

  void _toggleMenu() {
    if (_menuController.isOpen) {
      _menuController.close();
    } else {
      _menuController.open();
    }
    setState(() {});
  }

  void _select(GuideSortMode mode) {
    _menuController.close();
    widget.onSelected(mode);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(0, 6),
      style: MenuStyle(
        minimumSize: const WidgetStatePropertyAll(Size(132, 0)),
        maximumSize: const WidgetStatePropertyAll(Size(132, 132)),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        backgroundColor: const WidgetStatePropertyAll(Colors.white),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE9EDE3)),
          ),
        ),
        elevation: const WidgetStatePropertyAll(8),
        shadowColor: WidgetStatePropertyAll(
          Colors.black.withValues(alpha: 0.14),
        ),
      ),
      onOpen: () => setState(() {}),
      onClose: () => setState(() {}),
      menuChildren: GuideSortMode.values
          .map(
            (item) => SizedBox(
              width: 120,
              height: 38,
              child: MenuItemButton(
                onPressed: () => _select(item),
                style: ButtonStyle(
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 10),
                  ),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => item == widget.mode
                        ? AppColors.primarySoft
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: item == widget.mode
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (item == widget.mode)
                      const Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: AppColors.textPrimary,
                      ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
      builder: (context, controller, child) => InkWell(
        onTap: _toggleMenu,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isOpen ? AppColors.primary : const Color(0xFFE9EDE3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.mode.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                _isOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
