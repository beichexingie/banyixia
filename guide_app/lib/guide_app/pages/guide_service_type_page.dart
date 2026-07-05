import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../models/guide_app_models.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideServiceTypePage extends StatelessWidget {
  const GuideServiceTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final console = context.watch<GuideConsoleProvider>();
    return GuideAppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('接单类型'),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
              itemCount: console.serviceTypeList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                final type = console.serviceTypeList[index];
                final enabled = console.enabledTypes.contains(type);
                return InkWell(
                  onTap: () => console.toggleServiceType(type),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: enabled ? const Color(0xFFF6FFE7) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE3E5E8)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 94,
                          height: 94,
                          decoration: BoxDecoration(
                            color: enabled
                                ? AppColors.primary
                                : const Color(0xFFE9E9EC),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            type.icon,
                            size: 42,
                            color: enabled
                                ? AppColors.textPrimary
                                : const Color(0xFFB6B6BD),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    type.label,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.info_outline, size: 22),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                type.description,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                              if (type.isLocked) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFB547),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    '去解锁',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          enabled ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 38,
                          color: enabled ? AppColors.textPrimary : AppColors.textHint,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).maybePop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 0,
                ),
                child: const Text(
                  '确定',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
