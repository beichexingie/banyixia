import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/user_provider.dart';
import '../models/guide_app_models.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';
import '../widgets/guide_design_icon.dart';

class GuideServiceTypePage extends StatelessWidget {
  const GuideServiceTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final console = context.watch<GuideConsoleProvider>();
    const types = [
      GuideServiceType.localCompanion,
      GuideServiceType.customTrip,
      GuideServiceType.errandHelp,
    ];

    return GuideAppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '接单类型',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: types.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final type = types[index];
                final selected = console.enabledTypes.contains(type);
                return InkWell(
                  onTap: () => console.toggleServiceType(type),
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFF5FBDD) : Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFE3F6A2)
                            : const Color(0xFFE8E9EC),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: GuideDesignIcon(
                            type == GuideServiceType.localCompanion
                                ? '订单中心'
                                : type == GuideServiceType.customTrip
                                ? '服务项目'
                                : '专属运营',
                            size: 34,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type.label,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                type.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          selected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 23,
                          color: selected
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await console.saveServiceTypesToProfile(
                      context.read<UserProvider>(),
                    );
                    if (!context.mounted) return;
                    Navigator.of(context).maybePop();
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                child: const Text(
                  '确定',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
