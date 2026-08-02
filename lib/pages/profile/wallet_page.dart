import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('支付宝收款设置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: realNameController,
                decoration: const InputDecoration(labelText: '支付宝实名'),
              ),
              TextField(
                controller: accountController,
                decoration: const InputDecoration(labelText: '支付宝账号（手机号或邮箱）'),
              ),
              TextField(
                controller: userIdController,
                decoration: const InputDecoration(labelText: '支付宝 user_id（可选）'),
              ),
              const SizedBox(height: 8),
              const Text(
                '账号和 user_id 填一个即可。提交后由管理员审核，审核通过才能提现。',
                style: TextStyle(color: AppColors.textHint, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              try {
                await _api.put(
                  '/wallet/payout-account',
                  authToken: context.read<UserProvider>().accessToken,
                  body: {
                    'real_name': realNameController.text.trim(),
                    'alipay_account': accountController.text.trim(),
                    'alipay_user_id': userIdController.text.trim(),
                  },
                );
                if (!mounted) return;
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('收款账号已提交，等待管理员审核')),
                );
                _loadData();
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error.toString())),
                );
              }
            },
            child: const Text('提交审核'),
          ),
        ],
      ),
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
              if (amount <= 0 || amount > _availableBalance) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入不超过可提现余额的有效金额')),
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              '支付宝收款：$label${withdrawalCount > 0 ? ' · 提现记录 $withdrawalCount 条' : ''}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _showPayoutAccountDialog,
            child: const Text('设置'),
          ),
        ],
      ),
    );
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
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: const Text('充值'),
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
          final isIncome = tx['type'] == 'income';
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
