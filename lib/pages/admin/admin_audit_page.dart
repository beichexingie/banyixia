import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/application_provider.dart';
import '../../models/guide_application.dart';

class AdminAuditPage extends StatefulWidget {
  const AdminAuditPage({super.key});

  @override
  State<AdminAuditPage> createState() => _AdminAuditPageState();
}

class _AdminAuditPageState extends State<AdminAuditPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<ApplicationProvider>().loadPendingApplications());
  }

  void _showAuditDialog(GuideApplication app) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('审核申请'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('申请人：${app.fullName}'),
            const SizedBox(height: 8),
            Text('常驻城市：${app.city}'),
            const SizedBox(height: 8),
            Text('简介：${app.bio}'),
            const SizedBox(height: 16),
            const Text('是否准予入驻？'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _handleAudit(app.id, false);
            },
            child: const Text('驳回', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _handleAudit(app.id, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('通过'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAudit(String id, bool approved) async {
    try {
      await context.read<ApplicationProvider>().auditApplication(id, approved);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approved ? '审批已通过，已同步至地陪库' : '申请已驳回'), backgroundColor: approved ? Colors.green : Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('入驻审批后台', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 1,
      ),
      body: Consumer<ApplicationProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          
          if (provider.pendingApplications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.assignment_turned_in_outlined, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
                   const SizedBox(height: 16),
                   const Text('暂无待审核申请', style: TextStyle(color: AppColors.textHint)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: provider.pendingApplications.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (ctx, index) {
              final app = provider.pendingApplications[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: AppColors.divider)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(app.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('城市：${app.city} | 性别：${app.gender}'),
                      const SizedBox(height: 4),
                      Text(app.bio ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _showAuditDialog(app),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('审核'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
