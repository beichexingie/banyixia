import 'package:flutter/material.dart';
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

  Future<void> _apply(DemandRequest demand) async {
    try {
      await context.read<DemandProvider>().applyToDemand(
            demand.id,
            note: '地陪端报名：可根据需求提供本地陪同服务',
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('需求大厅'),
      ),
      body: Consumer<DemandProvider>(
        builder: (context, provider, _) {
          final data = _showApplied ? provider.appliedDemands : provider.demands;
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
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    demand.title,
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
                            const SizedBox(height: 10),
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
                                    onPressed: () => _apply(demand),
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
