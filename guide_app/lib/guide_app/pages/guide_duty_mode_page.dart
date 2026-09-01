import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../models/guide_app_models.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideDutyModePage extends StatelessWidget {
  const GuideDutyModePage({super.key});

  @override
  Widget build(BuildContext context) {
    final console = context.watch<GuideConsoleProvider>();
    final modes = console.modeList;

    return GuideAppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '接单模式',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        backgroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: modes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final mode = modes[index];
                final selected = console.mode == mode;
                return InkWell(
                  onTap: () => console.setMode(mode),
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
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFFF1F2F4),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            switch (mode.index) {
                              0 => Icons.near_me_outlined,
                              1 => Icons.location_city_outlined,
                              _ => Icons.public_outlined,
                            },
                            size: 28,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mode.label,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mode.description,
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
                onPressed: () => Navigator.of(context).maybePop(),
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
