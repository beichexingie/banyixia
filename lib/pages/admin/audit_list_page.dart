import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/application_provider.dart';
import '../../providers/user_provider.dart';
import '../../models/guide_application.dart';
import './audit_detail_page.dart';

class AuditListPage extends StatefulWidget {
  const AuditListPage({super.key});

  @override
  State<AuditListPage> createState() => _AuditListPageState();
}

class _AuditListPageState extends State<AuditListPage> {
  List<GuideApplication> _applications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    if (!context.read<UserProvider>().isAdmin) {
      if (mounted) {
        setState(() {
          _applications = [];
          _isLoading = false;
        });
      }
      return;
    }

    await context.read<ApplicationProvider>().loadPendingApplications();
    final results = context.read<ApplicationProvider>().pendingApplications;
    if (mounted) {
      setState(() {
        _applications = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAccess = context.watch<UserProvider>().isAdmin;
    if (!canAccess) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('地陪入驻审核', style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '当前账号没有审核权限。',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('地陪入驻审核', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadApplications,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _applications.isEmpty
            ? _buildEmpty()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _applications.length,
                itemBuilder: (context, index) => _buildAuditCard(_applications[index]),
              ),
      ),
    );
  }

  Widget _buildAuditCard(GuideApplication app) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: NetworkImage(app.avatar ?? 'https://picsum.photos/seed/app/100/100'),
        ),
        title: Text(app.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('城市: ${app.city ?? "未知"}', style: AppTextStyles.caption),
            const SizedBox(height: 2),
            Text('申请时间: ${app.createdAt.year}-${app.createdAt.month}-${app.createdAt.day}', style: AppTextStyles.caption),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AuditDetailPage(application: app)),
          );
          if (result == true) {
            _loadApplications();
          }
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('暂无待审核申请', style: AppTextStyles.subtitle),
          const SizedBox(height: 8),
          const Text('导游入驻请求已经全部处理完毕', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
