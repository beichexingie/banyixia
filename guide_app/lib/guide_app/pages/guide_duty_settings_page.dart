import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../models/guide_app_models.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';
import '../widgets/guide_design_icon.dart';

class GuideDutySettingsPage extends StatelessWidget {
  final VoidCallback onOpenMode;
  final VoidCallback onOpenCity;
  final VoidCallback onOpenServiceTypes;
  final VoidCallback onOpenInsurance;
  final VoidCallback onOpenBlockedUsers;
  final VoidCallback onOpenAuxiliary;

  const GuideDutySettingsPage({
    super.key,
    required this.onOpenMode,
    required this.onOpenCity,
    required this.onOpenServiceTypes,
    required this.onOpenInsurance,
    required this.onOpenBlockedUsers,
    required this.onOpenAuxiliary,
  });

  @override
  Widget build(BuildContext context) {
    return GuideAppScaffold(
      backgroundColor: const Color(0xFFF0F1F3),
      appBar: AppBar(title: const Text('接单设置'), backgroundColor: Colors.white),
      body: _SettingsContent(
        onOpenMode: onOpenMode,
        onOpenCity: onOpenCity,
        onOpenServiceTypes: onOpenServiceTypes,
        onOpenInsurance: onOpenInsurance,
        onOpenBlockedUsers: onOpenBlockedUsers,
        onOpenAuxiliary: onOpenAuxiliary,
      ),
    );
  }
}

class GuideDutySettingsSheet extends StatelessWidget {
  final VoidCallback onOpenMode;
  final VoidCallback onOpenCity;
  final VoidCallback onOpenServiceTypes;
  final VoidCallback onOpenInsurance;
  final VoidCallback onOpenBlockedUsers;
  final VoidCallback onOpenAuxiliary;

  const GuideDutySettingsSheet({
    super.key,
    required this.onOpenMode,
    required this.onOpenCity,
    required this.onOpenServiceTypes,
    required this.onOpenInsurance,
    required this.onOpenBlockedUsers,
    required this.onOpenAuxiliary,
  });

  void _closeAndOpen(BuildContext context, VoidCallback action) {
    Navigator.of(context).pop();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 520),
        decoration: const BoxDecoration(
          color: Color(0xFFF0F1F3),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _SettingsContent(
          inSheet: true,
          onOpenMode: () => _closeAndOpen(context, onOpenMode),
          onOpenCity: () => _closeAndOpen(context, onOpenCity),
          onOpenServiceTypes: () => _closeAndOpen(context, onOpenServiceTypes),
          onOpenInsurance: () => _closeAndOpen(context, onOpenInsurance),
          onOpenBlockedUsers: () => _closeAndOpen(context, onOpenBlockedUsers),
          onOpenAuxiliary: () => _closeAndOpen(context, onOpenAuxiliary),
        ),
      ),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  final bool inSheet;
  final VoidCallback onOpenMode;
  final VoidCallback onOpenCity;
  final VoidCallback onOpenServiceTypes;
  final VoidCallback onOpenInsurance;
  final VoidCallback onOpenBlockedUsers;
  final VoidCallback onOpenAuxiliary;

  const _SettingsContent({
    this.inSheet = false,
    required this.onOpenMode,
    required this.onOpenCity,
    required this.onOpenServiceTypes,
    required this.onOpenInsurance,
    required this.onOpenBlockedUsers,
    required this.onOpenAuxiliary,
  });

  @override
  Widget build(BuildContext context) {
    final console = context.watch<GuideConsoleProvider>();
    return ListView(
      padding: EdgeInsets.fromLTRB(16, inSheet ? 12 : 16, 16, 24),
      children: [
        if (inSheet)
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD0D2D5),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        if (inSheet) const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(
              child: Text(
                '当前接单模式：',
                style: TextStyle(fontSize: 15, color: AppColors.textHint),
              ),
            ),
            GuidePillButton(
              label: console.mode.label,
              active: true,
              onTap: onOpenMode,
            ),
            if (inSheet)
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 22),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const _SectionTitle('派单'),
        GuideSectionCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _SettingRow(
                title: '常驻区域',
                value: console.selectedCity,
                onTap: onOpenCity,
              ),
              const Divider(height: 1),
              _SettingRow(
                title: '接单类型',
                value: console.enabledTypes
                    .map((item) => item.label)
                    .join(' / '),
                onTap: onOpenServiceTypes,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SectionTitle('接单工具'),
        GuideSectionCard(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: _ToolItem(
                  asset: '地陪保险',
                  label: '地陪保险',
                  onTap: onOpenInsurance,
                ),
              ),
              Expanded(
                child: _ToolItem(
                  asset: '屏蔽名单',
                  label: '屏蔽名单',
                  onTap: onOpenBlockedUsers,
                ),
              ),
              Expanded(
                child: _ToolItem(
                  asset: '辅助设置',
                  label: '辅助设置',
                  onTap: onOpenAuxiliary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;

  const _SettingRow({
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value.isEmpty ? '去设置' : value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: AppColors.textHint),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolItem extends StatelessWidget {
  final String asset;
  final String label;
  final VoidCallback onTap;

  const _ToolItem({
    required this.asset,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFF4FBDD),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: GuideDesignIcon(asset, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
