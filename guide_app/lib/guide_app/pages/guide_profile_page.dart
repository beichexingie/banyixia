import 'package:flutter/material.dart';
import 'package:flutter_application_1/config/app_theme.dart';
import 'package:flutter_application_1/providers/user_provider.dart';
import 'package:flutter_application_1/services/ecs_api_client.dart';
import 'package:provider/provider.dart';

import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';
import '../widgets/guide_design_icon.dart';

class GuideProfilePage extends StatefulWidget {
  final VoidCallback onOpenDutySettings;
  final VoidCallback onOpenAddressManager;
  final VoidCallback onOpenCityPicker;
  final VoidCallback onOpenCertification;
  final VoidCallback onOpenPlatformRules;
  final VoidCallback onOpenWallet;
  final VoidCallback onOpenProfileEdit;
  final VoidCallback onOpenPasswordChange;

  const GuideProfilePage({
    super.key,
    required this.onOpenDutySettings,
    required this.onOpenAddressManager,
    required this.onOpenCityPicker,
    required this.onOpenCertification,
    required this.onOpenPlatformRules,
    required this.onOpenWallet,
    required this.onOpenProfileEdit,
    required this.onOpenPasswordChange,
  });

  @override
  State<GuideProfilePage> createState() => _GuideProfilePageState();
}

class _GuideProfilePageState extends State<GuideProfilePage> {
  final EcsApiClient _api = EcsApiClient();
  Map<String, dynamic> _wallet = const {};
  Map<String, dynamic> _payoutAccount = const {};
  bool _walletLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadWallet());
  }

  Future<void> _loadWallet() async {
    final token = context.read<UserProvider>().accessToken;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _walletLoading = false);
      return;
    }
    if (mounted) setState(() => _walletLoading = true);
    try {
      final response = await _api.get('/wallet', authToken: token);
      final data = response['data'];
      if (!mounted || data is! Map) return;
      setState(() {
        _wallet = (data['wallet'] as Map?)?.cast<String, dynamic>() ?? {};
        _payoutAccount =
            (data['payout_account'] as Map?)?.cast<String, dynamic>() ?? {};
      });
    } catch (error) {
      debugPrint('Guide profile wallet load error: $error');
    } finally {
      if (mounted) setState(() => _walletLoading = false);
    }
  }

  double _money(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;

  String _payoutStatus() {
    switch (_payoutAccount['status']?.toString()) {
      case 'approved':
        return '已审核';
      case 'pending':
        return '审核中';
      case 'rejected':
        return '已驳回';
      default:
        return '未绑定';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final console = context.watch<GuideConsoleProvider>();
    final balance = _money(_wallet['balance'] ?? user.balance);
    final pendingBalance = _money(_wallet['pending_balance']);
    final totalEarned = _money(_wallet['total_earned']);

    return GuideAppScaffold(
      backgroundColor: const Color(0xFFF1F3F7),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        children: [
          Row(
            children: [
              ClipOval(
                child: user.avatar.isNotEmpty
                    ? Image.network(
                        user.avatar,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _AvatarFallback(),
                      )
                    : _AvatarFallback(),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.nickname.isNotEmpty ? user.nickname : '地陪用户',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (user.vipLabel.isNotEmpty) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC45A),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              user.vipLabel,
                              style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF704300),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.city.isNotEmpty ? 'IP：${user.city}' : 'IP：未设置',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              GuidePillButton(
                label: console.isOnline ? '上线' : '下线',
                icon: console.isOnline
                    ? Icons.check_circle
                    : Icons.remove_circle,
                active: console.isOnline,
                onTap: () => console.setOnline(!console.isOnline),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WalletSummary(
            balance: balance,
            pendingBalance: pendingBalance,
            totalEarned: totalEarned,
            payoutStatus: _walletLoading ? '读取中' : _payoutStatus(),
            onRefresh: _loadWallet,
            onWithdraw: widget.onOpenWallet,
            onPayoutAccount: widget.onOpenWallet,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RewardCard(
                  title: '邀请用户奖励',
                  value: '${user.followCount}',
                  subtitle: '累计人数',
                  amount: '${user.couponCount}',
                  amountLabel: '入账（元）',
                  tint: const Color(0xFFFFF0D9),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RewardCard(
                  title: '邀请新人奖励',
                  value: '${user.fansCount}',
                  subtitle: '累计人数',
                  amount: '0',
                  amountLabel: '入账（元）',
                  tint: const Color(0xFFF2FFD9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GuideSectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _ProfileRow(
                  icon: Icons.edit_note_outlined,
                  title: '编辑地陪资料',
                  onTap: widget.onOpenProfileEdit,
                ),
                const Divider(height: 1),
                _ProfileRow(
                  icon: Icons.settings_outlined,
                  title: '接单设置',
                  onTap: widget.onOpenDutySettings,
                ),
                const Divider(height: 1),
                _ProfileRow(
                  icon: Icons.location_on_outlined,
                  title: '服务地址管理',
                  onTap: widget.onOpenAddressManager,
                ),
                const Divider(height: 1),
                _ProfileRow(
                  icon: Icons.verified_user_outlined,
                  title: '认证资料',
                  onTap: widget.onOpenCertification,
                ),
                const Divider(height: 1),
                _ProfileRow(
                  icon: Icons.policy_outlined,
                  title: '平台规则',
                  onTap: widget.onOpenPlatformRules,
                ),
                const Divider(height: 1),
                _ProfileRow(
                  icon: Icons.location_city_outlined,
                  title: '城市与服务信息',
                  onTap: widget.onOpenCityPicker,
                ),
                const Divider(height: 1),
                _ProfileRow(
                  icon: Icons.lock_outline,
                  title: '修改密码',
                  onTap: widget.onOpenPasswordChange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () => context.read<UserProvider>().logout(),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFE85B47),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                '退出当前账号',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletSummary extends StatelessWidget {
  final double balance;
  final double pendingBalance;
  final double totalEarned;
  final String payoutStatus;
  final VoidCallback onRefresh;
  final VoidCallback onWithdraw;
  final VoidCallback onPayoutAccount;

  const _WalletSummary({
    required this.balance,
    required this.pendingBalance,
    required this.totalEarned,
    required this.payoutStatus,
    required this.onRefresh,
    required this.onWithdraw,
    required this.onPayoutAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '总资产',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('刷新'),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          Text(
            '¥${balance.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _WalletMetric(
                  title: '托管中（元）',
                  value: pendingBalance.toStringAsFixed(2),
                  action: '钱包',
                  onTap: onRefresh,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WalletMetric(
                  title: '累计收益（元）',
                  value: totalEarned.toStringAsFixed(2),
                  action: '明细',
                  onTap: onWithdraw,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _WalletMetric(
                  title: '收款账号',
                  value: payoutStatus,
                  action: '设置',
                  onTap: onPayoutAccount,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: onWithdraw,
              borderRadius: BorderRadius.circular(99),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                child: Text(
                  '进入钱包提现',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletMetric extends StatelessWidget {
  final String title;
  final String value;
  final String action;
  final VoidCallback onTap;

  const _WalletMetric({
    required this.title,
    required this.value,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              InkWell(
                onTap: onTap,
                child: Text(
                  action,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value == '管理' ? value : '¥$value',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final String amount;
  final String amountLabel;
  final Color tint;

  const _RewardCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.amount,
    required this.amountLabel,
    required this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 9, 10),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _RewardValue(value: value, label: subtitle),
              ),
              Expanded(
                child: _RewardValue(value: amount, label: amountLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardValue extends StatelessWidget {
  final String value;
  final String label;

  const _RewardValue({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String? asset;
  final IconData? icon;
  final String title;
  final VoidCallback onTap;

  const _ProfileRow({
    this.asset,
    this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            asset != null
                ? GuideDesignIcon(asset!, size: 22)
                : Icon(icon, size: 21, color: AppColors.textSecondary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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

class _AvatarFallback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      color: const Color(0xFFE2E5EA),
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: AppColors.textHint),
    );
  }
}
