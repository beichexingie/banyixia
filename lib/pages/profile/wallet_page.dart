import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/ecs_api_client.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  Map<String, dynamic> _walletData = {'balance': 0.0, 'pending_balance': 0.0, 'total_earned': 0.0};
  Map<String, dynamic> _payoutAccount = {};
  List<dynamic> _transactions = [];
  List<dynamic> _withdrawals = [];
  bool _isLoading = true;
  final _api = EcsApiClient();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = context.read<UserProvider>().user.id;
      if (userId == null) return;

      final response = await _api.get('/wallet', authToken: context.read<UserProvider>().accessToken);
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        _walletData = (data['wallet'] as Map?)?.cast<String, dynamic>() ?? _walletData;
        _payoutAccount = (data['payout_account'] as Map?)?.cast<String, dynamic>() ?? {};
        _transactions = (data['transactions'] as List?) ?? [];
        _withdrawals = (data['withdrawals'] as List?) ?? [];
      }
    } catch (e) {
      debugPrint('Load wallet error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('我的钱包', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _showPayoutAccountDialog,
            child: const Text('收款设置', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          TextButton(
            onPressed: () {},
            child: const Text('收支说明', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          )
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeaderCard()),
                  SliverToBoxAdapter(child: _buildPayoutSummary()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Row(
                        children: [
                          const Text('收支明细', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('近30天', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                  _buildTransactionList(),
                ],
              ),
            ),
    );
  }

  double get _availableBalance => double.tryParse('${_walletData['balance'] ?? 0}') ?? 0;

  Future<void> _showPayoutAccountDialog() async {
    final realNameController = TextEditingController(text: _payoutAccount['real_name']?.toString() ?? '');
    final accountController = TextEditingController(text: _payoutAccount['alipay_account']?.toString() ?? '');
    final userIdController = TextEditingController(text: _payoutAccount['alipay_user_id']?.toString() ?? '');
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var saving = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('支付宝收款设置'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '用于平台订单完成后的提现收款，请填写本人支付宝信息。',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: realNameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '支付宝实名 *',
                      hintText: '必须与支付宝实名认证一致',
                    ),
                  ),
                  TextField(
                    controller: accountController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '支付宝账号 *',
                      hintText: '手机号或邮箱',
                    ),
                  ),
                  TextField(
                    controller: userIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '支付宝 user_id（可选）',
                      hintText: '仅在你明确知道时填写',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '支付宝账号和 user_id 至少填写一个。提交后进入平台审核；审核通过后，提现申请才会允许自动转账。',
                    style: TextStyle(color: AppColors.textHint, fontSize: 12, height: 1.45),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final realName = realNameController.text.trim();
                        final account = accountController.text.trim();
                        final userId = userIdController.text.trim();
                        if (realName.length < 2) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('请填写有效的支付宝实名')),
                          );
                          return;
                        }
                        if (account.isEmpty && userId.isEmpty) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('请至少填写支付宝账号或 user_id')),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await _api.put(
                            '/wallet/payout-account',
                            authToken: this.context.read<UserProvider>().accessToken,
                            body: {
                              'real_name': realName,
                              'alipay_account': account,
                              'alipay_user_id': userId,
                            },
                          );
                          if (!mounted) return;
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(content: Text('收款账号已提交，等待管理员审核')),
                          );
                          await _loadData();
                        } catch (error) {
                          setDialogState(() => saving = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(content: Text(error.toString())),
                          );
                        }
                      },
                child: Text(saving ? '提交中...' : '提交审核'),
              ),
            ],
          ),
        );
      },
    );
    realNameController.dispose();
    accountController.dispose();
    userIdController.dispose();
  }

  Future<void> _showWithdrawDialog() async {
    final amountController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('申请提现'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '提现金额',
            hintText: '可提现余额 ¥${_availableBalance.toStringAsFixed(2)}',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text.trim()) ?? 0;
              if (amount < AppConfig.minimumWithdrawalAmount ||
                  amount > _availableBalance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('提现金额最低为 0.10 元，且不能超过可提现余额'),
                  ),
                );
                return;
              }
              try {
                await _api.post(
                  '/wallet/withdraw',
                  authToken: context.read<UserProvider>().accessToken,
                  body: {'amount': amount},
                );
                if (!mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('提现申请已提交，等待管理员审核打款')),
                );
                _loadData();
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.toString())),
                );
              }
            },
            child: const Text('提交提现'),
          ),
        ],
      ),
    );
    amountController.dispose();
  }

  Widget _buildPayoutSummary() {
    final status = _payoutAccount['status']?.toString();
    final label = status == 'approved'
        ? '已审核'
        : status == 'pending'
            ? '审核中'
            : status == 'rejected'
                ? '已驳回'
                : '未绑定';
    final withdrawalCount = _withdrawals.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '支付宝收款：$label',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _payoutAccount.isEmpty
                        ? '未绑定收款账号'
                        : '${_maskedPayoutAccount()}${withdrawalCount > 0 ? ' · 提现记录 $withdrawalCount 条' : ''}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  if (status == 'rejected' && (_payoutAccount['reject_reason']?.toString().isNotEmpty ?? false))
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '驳回原因：${_payoutAccount['reject_reason']}',
                        style: const TextStyle(color: Colors.red, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: _showPayoutAccountDialog,
              child: Text(_payoutAccount.isEmpty ? '绑定' : '修改'),
            ),
          ],
        ),
      ),
    );
  }

  String _maskedPayoutAccount() {
    final account = _payoutAccount['alipay_account']?.toString().trim() ?? '';
    if (account.isEmpty) {
      return '已填写支付宝 user_id';
    }
    if (account.contains('@')) {
      final parts = account.split('@');
      final name = parts.first;
      return '${name.length <= 2 ? name : '${name.substring(0, 2)}***'}@${parts.last}';
    }
    if (account.length >= 7) {
      return '${account.substring(0, 3)}****${account.substring(account.length - 4)}';
    }
    return account;
  }

  Widget _buildHeaderCard() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2D2E32), Color(0xFF43454B)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('总余额 (元)', style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(width: 8),
              const Icon(Icons.help_outline, size: 14, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _walletData['balance']?.toString() ?? '0.00',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildMiniStat('托管中', _walletData['pending_balance']?.toString() ?? '0.00'),
              Container(width: 1, height: 24, color: Colors.white12, margin: const EdgeInsets.symmetric(horizontal: 24)),
              _buildMiniStat('累计收益', _walletData['total_earned']?.toString() ?? '0.00'),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _showWithdrawDialog,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('提现', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OutlinedButton(
                  onPressed: _showPayoutAccountDialog,
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('收款设置'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        const SizedBox(height: 4),
        Text('¥$value', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTransactionList() {
    if (_transactions.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text('暂无明细记录', style: TextStyle(color: AppColors.textHint))),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final tx = _transactions[index];
          final type = tx['type']?.toString() ?? '';
          final isIncome = type.startsWith('income') || (double.tryParse('${tx['actual_amount'] ?? 0}') ?? 0) > 0;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(color: (isIncome ? Colors.green : Colors.orange).withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(isIncome ? Icons.add_card : Icons.account_balance_wallet, color: isIncome ? Colors.green : Colors.orange, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tx['description'] ?? '交易记录', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(DateTime.parse(tx['created_at']).toString().substring(0, 16), style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncome ? "+" : "-"}${tx['actual_amount']}',
                      style: TextStyle(color: isIncome ? Colors.green : AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    if (isIncome && (tx['platform_fee'] ?? 0) > 0)
                      Text('费: ¥${tx['platform_fee']}', style: const TextStyle(color: AppColors.textHint, fontSize: 10)),
                  ],
                ),
              ],
            ),
          );
        },
        childCount: _transactions.length,
      ),
    );
  }
}
