import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class CouponsPage extends StatelessWidget {
  const CouponsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('我的优惠券'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCouponCard('新人专享券', '50', '满200元可用', '有效期至 2026-12-31'),
          _buildCouponCard('周末出行券', '20', '无门槛', '有效期至 2026-11-30'),
          _buildCouponCard('地陪首单立减', '30', '满100元可用', '有效期至 2026-10-31', isUsed: true),
        ],
      ),
    );
  }

  Widget _buildCouponCard(String title, String amount, String condition, String expiry, {bool isUsed = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: isUsed ? const Color(0xFFF5F5F5) : const Color(0xFFFFF4EC),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¥', style: TextStyle(color: isUsed ? AppColors.textHint : AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold, height: 1.5)),
                    Text(amount, style: TextStyle(color: isUsed ? AppColors.textHint : AppColors.primary, fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isUsed ? AppColors.textHint : AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(condition, style: TextStyle(fontSize: 12, color: isUsed ? AppColors.textHint : AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text(expiry, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ),
          ),
          if (isUsed)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Image.network('https://cdn.iconscout.com/icon/free/png-256/free-used-2-458117.png', width: 48, height: 48, color: AppColors.textHint.withValues(alpha: 0.3)),
            ),
        ],
      ),
    );
  }
}
