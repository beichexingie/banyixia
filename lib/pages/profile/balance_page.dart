import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/user_provider.dart';

class BalancePage extends StatelessWidget {
  const BalancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('账户余额'),
        centerTitle: true,
      ),
      body: Consumer<UserProvider>(
        builder: (context, userProvider, child) {
          final balance = userProvider.user.balance;

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: Column(
                  children: [
                    const Text('总余额 (元)', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(balance.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionButton(context, '充值', Icons.account_balance_wallet, isOutline: false),
                        _buildActionButton(context, '提现', Icons.money, isOutline: true),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('收支明细', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            _buildTransactionItem('充值', '2026-03-01 10:00', '+100.00', true),
                            _buildTransactionItem('预约地陪 - 小树', '2026-02-28 14:30', '-50.00', false),
                            _buildTransactionItem('新用户奖励', '2026-02-28 09:00', '+50.00', true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, String label, IconData icon, {required bool isOutline}) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 18, color: isOutline ? Colors.white : AppColors.primary),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isOutline ? Colors.transparent : Colors.white,
        foregroundColor: isOutline ? Colors.white : AppColors.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isOutline ? const BorderSide(color: Colors.white) : BorderSide.none,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      ),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('【$label】功能暂未开放，充值提现需真实支付支持'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      },
    );
  }

  Widget _buildTransactionItem(String title, String time, String amount, bool isIncome) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isIncome ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        child: Icon(
          isIncome ? Icons.add : Icons.remove,
          color: isIncome ? const Color(0xFF4CAF50) : const Color(0xFFF44336),
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(time, style: AppTextStyles.caption),
      trailing: Text(amount, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isIncome ? const Color(0xFF4CAF50) : AppColors.textPrimary)),
    );
  }
}
