import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../models/guide_app_models.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';

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
    final console = context.watch<GuideConsoleProvider>();
    return GuideAppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('接单设置'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          GuideSectionCard(
            child: Row(
              children: [
                const Text(
                  '当前接单模式：',
                  style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GuidePillButton(
                      label: console.mode.label,
                      active: true,
                      onTap: onOpenMode,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              '派单',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          GuideSectionCard(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
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
                  value: console.enabledTypes.map((item) => item.label).join(' / '),
                  onTap: onOpenServiceTypes,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              '接单工具',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          GuideSectionCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ToolItem(icon: Icons.verified_user_outlined, label: '地陪保险', onTap: onOpenInsurance),
                _ToolItem(icon: Icons.person_off_outlined, label: '屏蔽名单', onTap: onOpenBlockedUsers),
                _ToolItem(icon: Icons.settings_suggest_outlined, label: '辅助设置', onTap: onOpenAuxiliary),
              ],
            ),
          ),
        ],
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
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value.isEmpty ? '去设置' : value,
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.textHint,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _ToolItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: const BoxDecoration(
            color: Color(0xFFF3F8E4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 38, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
      ),
    );
  }
}
