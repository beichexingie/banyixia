import 'package:flutter/material.dart';
import 'package:flutter_application_1/pages/profile/user_profile_page.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/demand_request.dart';
import '../../providers/demand_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideDemandHallPage extends StatefulWidget {
  const GuideDemandHallPage({super.key});

  @override
  State<GuideDemandHallPage> createState() => _GuideDemandHallPageState();
}

class _GuideDemandHallPageState extends State<GuideDemandHallPage> {
  bool _showApplied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<DemandProvider>().loadDemands();
      await context.read<DemandProvider>().loadAppliedDemands();
    });
  }

  // Kept for compatibility with older hot-reload state; new taps use the
  // lifecycle-safe dialog below.
  // ignore: unused_element
  Future<void> _apply(DemandRequest demand) async {
    final quoteController = TextEditingController();
    final noteController = TextEditingController();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('报名需求'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quoteController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '我的报价（元）'),
            ),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '报名说明（可选）'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(context, {
                'quote': double.tryParse(quoteController.text.trim()),
                'note': noteController.text.trim(),
              });
            },
            child: const Text('提交报名'),
          ),
        ],
      ),
    );
    // Let the dialog finish its route transition before disposing controllers.
    // Disposing them immediately can trip Flutter's inherited-widget
    // dependent assertion while the text fields are still deactivating.
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      quoteController.dispose();
      noteController.dispose();
    });
    final quote = result?['quote'] as double?;
    if (!mounted || quote == null || quote <= 0) return;
    try {
      await context.read<DemandProvider>().applyToDemand(
        demand.id,
        quoteAmount: quote,
        note: result?['note']?.toString() ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('报名成功')));
      setState(() => _showApplied = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('报名失败：$e')));
    }
  }

  Future<void> _applySafely(DemandRequest demand) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _GuideQuoteDialog(),
    );
    if (!mounted) return;
    final quote = result?['quote'] as double?;
    if (quote == null || quote <= 0) return;
    try {
      await context.read<DemandProvider>().applyToDemand(
        demand.id,
        quoteAmount: quote,
        note: result?['note']?.toString() ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('报名成功')));
      setState(() => _showApplied = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('报名失败：$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GuideAppScaffold(
      backgroundColor: const Color(0xFFF0F1F3),
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('需求大厅')),
      body: Consumer<DemandProvider>(
        builder: (context, provider, _) {
          final data = _showApplied
              ? provider.appliedDemands
              : provider.demands;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GuidePillButton(
                      label: '可报名需求',
                      active: !_showApplied,
                      onTap: () => setState(() => _showApplied = false),
                    ),
                    const SizedBox(width: 10),
                    GuidePillButton(
                      label: '我已报名',
                      active: _showApplied,
                      onTap: () => setState(() => _showApplied = true),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    await provider.loadDemands();
                    await provider.loadAppliedDemands();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: data.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final demand = data[index];
                      return GuideSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: demand.authorId.isEmpty
                                  ? null
                                  : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => UserProfilePage(
                                          userId: demand.authorId,
                                        ),
                                      ),
                                    ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 19,
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _showApplied ? demand.status : '报名中',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              demand.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              demand.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '${demand.city} · ${demand.location}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              demand.timeLabel,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_showApplied &&
                                demand.myQuoteAmount != null) ...[
                              Text(
                                '我的报价：¥${demand.myQuoteAmount!.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFF5A2E),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              children: [
                                Text(
                                  '预算 ${demand.budget.isEmpty ? '待沟通' : demand.budget}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                if (!_showApplied)
                                  ElevatedButton(
                                    onPressed: () => _applySafely(demand),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.textPrimary,
                                      elevation: 0,
                                    ),
                                    child: const Text('我要报名'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GuideQuoteDialog extends StatefulWidget {
  const _GuideQuoteDialog();

  @override
  State<_GuideQuoteDialog> createState() => _GuideQuoteDialogState();
}

class _GuideQuoteDialogState extends State<_GuideQuoteDialog> {
  final _quoteController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _quoteController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final quote = double.tryParse(_quoteController.text.trim());
    if (quote == null || quote <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入有效的报价金额')));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(
      context,
    ).pop({'quote': quote, 'note': _noteController.text.trim()});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('报名需求'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _quoteController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '我的报价（元）'),
            ),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '报名说明（可选）'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('提交报名')),
      ],
    );
  }
}
