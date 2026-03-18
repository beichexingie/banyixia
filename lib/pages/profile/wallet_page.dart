import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/order_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  Map<String, dynamic> _walletData = {'balance': 0.0, 'pending_balance': 0.0, 'total_earned': 0.0};
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // 1. 获取钱包摘要
      final walletResponse = await Supabase.instance.client
          .from('wallets')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      if (walletResponse != null) {
        _walletData = walletResponse;
      }

      // 2. 获取收支明细
      final txResponse = await Supabase.instance.client
          .from('transactions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      _transactions = txResponse ?? [];
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
                  onPressed: () {},
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
