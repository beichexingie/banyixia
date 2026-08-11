import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/demand_request.dart';
import '../../providers/demand_provider.dart';

class DemandDetailPage extends StatefulWidget {
  final String demandId;

  const DemandDetailPage({super.key, required this.demandId});

  @override
  State<DemandDetailPage> createState() => _DemandDetailPageState();
}

class _DemandDetailPageState extends State<DemandDetailPage> {
  late Future<DemandRequest> _future;
  final TextEditingController _amountController = TextEditingController(
    text: '399',
  );

  @override
  void initState() {
    super.initState();
    _future = context.read<DemandProvider>().getDemandDetail(widget.demandId);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = context.read<DemandProvider>().getDemandDetail(widget.demandId);
    });
    await _future;
  }

  Future<void> _selectGuide(DemandApplication application) async {
    final amount =
        application.quoteAmount ??
        double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效金额')));
      return;
    }
    try {
      final data = await context
          .read<DemandProvider>()
          .selectGuideAndCreateOrder(
            demandId: widget.demandId,
            applicationId: application.id,
            amount: amount,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已生成订单：${data['id'] ?? ''}')));
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '需求详情',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: FutureBuilder<DemandRequest>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('需求详情加载失败'));
          }
          final demand = snapshot.data!;
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: demand.authorId.isEmpty
                                  ? null
                                  : () => context.push(
                                      '/user/${demand.authorId}',
                                    ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundImage:
                                        demand.authorAvatar.isNotEmpty
                                        ? NetworkImage(demand.authorAvatar)
                                        : null,
                                    child: demand.authorAvatar.isEmpty
                                        ? const Icon(Icons.person_outline)
                                        : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      demand.authorName.isEmpty
                                          ? '客户'
                                          : demand.authorName,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _DemandStatusChip(status: demand.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        demand.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        demand.content,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                      if (demand.images.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 88,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: demand.images.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) => ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                demand.images[index],
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Text('地点：${demand.city} ${demand.location}'),
                      const SizedBox(height: 8),
                      Text('时间：${demand.timeLabel}'),
                      const SizedBox(height: 8),
                      Text('人数：${demand.peopleCount}人 · ${demand.gender}'),
                      const SizedBox(height: 8),
                      Text(
                        '预算：${demand.budget.isEmpty ? '未填写' : demand.budget}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '订单金额',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          hintText: '选择地陪后用于生成订单金额',
                          filled: true,
                          fillColor: const Color(0xFFF7F7F2),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '报名地陪（${demand.applications.length}）',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (demand.applications.isEmpty)
                        const Text(
                          '暂时还没有地陪报名',
                          style: TextStyle(color: AppColors.textSecondary),
                        )
                      else
                        ...demand.applications.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F7F2),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () => context.push(
                                            '/guide/${item.guideId}',
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 18,
                                                backgroundImage:
                                                    item.guideAvatar.isNotEmpty
                                                    ? NetworkImage(
                                                        item.guideAvatar,
                                                      )
                                                    : null,
                                                child: item.guideAvatar.isEmpty
                                                    ? const Icon(
                                                        Icons.person_outline,
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  item.guideName.isEmpty
                                                      ? '地陪'
                                                      : item.guideName,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _applicationLabel(item.status),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.quoteAmount == null
                                        ? '报价：待沟通'
                                        : '报价：¥${item.quoteAmount!.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFFF5A2E),
                                    ),
                                  ),
                                  Text(
                                    item.guideCity.isEmpty
                                        ? '未填写城市'
                                        : item.guideCity,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (item.note.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      item.note,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  if (demand.status != 'matched' &&
                                      item.status == 'pending') ...[
                                    const SizedBox(height: 12),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton(
                                        onPressed: () => _selectGuide(item),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primary,
                                          foregroundColor:
                                              AppColors.textPrimary,
                                          elevation: 0,
                                        ),
                                        child: const Text('选中并生成订单'),
                                      ),
                                    ),
                                  ],
                                ],
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
        },
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }

  String _applicationLabel(String status) {
    switch (status) {
      case 'selected':
        return '已选中';
      case 'rejected':
        return '未选中';
      default:
        return '待处理';
    }
  }
}

class _DemandStatusChip extends StatelessWidget {
  final String status;

  const _DemandStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'matched' => ('已匹配', const Color(0xFF9EDC2E)),
      'closed' => ('已关闭', const Color(0xFFE6E7EB)),
      _ => ('报名中', AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
