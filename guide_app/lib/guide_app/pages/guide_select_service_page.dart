import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideSelectServicePage extends StatelessWidget {
  const GuideSelectServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    final console = context.watch<GuideConsoleProvider>();
    final selectedCount = console.serviceOptions.fold<int>(
      0,
      (sum, item) => sum + item.count,
    );
    final selectedAmount = console.serviceOptions.fold<double>(
      0,
      (sum, item) => sum + item.pricePerDay * item.count,
    );

    return GuideAppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('选择服务'), backgroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
              children: [
                Text(
                  '已选 $selectedCount 项服务',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ...console.serviceOptions.map(
                  (service) => Padding(
                    padding: const EdgeInsets.only(bottom: 26),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.network(
                            service.imageUrl,
                            width: 116,
                            height: 116,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 116,
                              height: 116,
                              color: const Color(0xFFECEEF2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  service.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                service.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '¥${service.pricePerDay.toStringAsFixed(2)}/天',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFF5A3C),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                _CountButton(
                                  icon: Icons.remove_rounded,
                                  active: service.count > 0,
                                  onTap: () => context
                                      .read<GuideConsoleProvider>()
                                      .changeServiceOptionCount(service.id, -1),
                                ),
                                const SizedBox(width: 14),
                                Text(
                                  '${service.count}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                _CountButton(
                                  icon: Icons.add_rounded,
                                  active: true,
                                  onTap: () => context
                                      .read<GuideConsoleProvider>()
                                      .changeServiceOptionCount(service.id, 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                GuidePillButton(
                  label: '订单须知',
                  icon: Icons.error_outline_rounded,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('订单须知与服务规则页已预留')),
                    );
                  },
                  color: const Color(0xFFF4F5F7),
                ),
                const SizedBox(height: 24),
                GuideSectionCard(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                  child: Column(
                    children: const [
                      _SelectLine(title: '服务地点', value: '苏州区某某路苏州区某某路122号'),
                      Divider(height: 1),
                      _SelectLine(title: '服务时间', value: '5月5日 12:00'),
                      Divider(height: 1),
                      _SelectLine(title: '服务人数及性别', value: '请选择'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                GuideSectionCard(
                  padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                  child: Column(
                    children: [
                      _PaymentRow(
                        label: '微信支付',
                        iconColor: const Color(0xFF2DC653),
                        iconText: '微',
                        selected: false,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('正式版可在这里切换支付方式')),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      _PaymentRow(
                        label: '支付宝支付',
                        iconColor: const Color(0xFF1FA8F7),
                        iconText: '支',
                        selected: true,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('当前演示页默认使用支付宝支付')),
                          );
                        },
                      ),
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF2E5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          '本服务由平台合作保险提供行程保障，正式版这里接真实投保说明。',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFFFF8C3B),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      '合计 ¥${selectedAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFF5A3C),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.radio_button_unchecked,
                      color: AppColors.textHint.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '我已知晓并同意《**支付协议》和《免责声明》',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textHint,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: selectedCount == 0
                        ? null
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '已选择 $selectedCount 项服务，支付能力后续接正式订单流',
                                ),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '立即付款',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;

  const _CountButton({required this.icon, required this.active, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: active ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : const Color(0xFFF0F1F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: active ? AppColors.textPrimary : AppColors.textHint,
        ),
      ),
    );
  }
}

class _SelectLine extends StatelessWidget {
  final String title;
  final String value;

  const _SelectLine({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Row(
        children: [
          SizedBox(
            width: 118,
            child: Text(
              '$title：',
              style: const TextStyle(
                fontSize: 17,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 17,
                fontWeight: title == '服务人数及性别'
                    ? FontWeight.w500
                    : FontWeight.w800,
                color: title == '服务人数及性别'
                    ? AppColors.textHint
                    : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textHint),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final String label;
  final Color iconColor;
  final String iconText;
  final bool selected;
  final VoidCallback? onTap;

  const _PaymentRow({
    required this.label,
    required this.iconColor,
    required this.iconText,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                iconText,
                style: const TextStyle(
                  fontSize: 26,
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 38,
              color: selected ? AppColors.textPrimary : AppColors.textHint,
            ),
          ],
        ),
      ),
    );
  }
}
