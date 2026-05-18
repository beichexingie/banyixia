import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/guide_application.dart';
import '../../providers/application_provider.dart';
import '../../providers/user_provider.dart';

class AuditDetailPage extends StatefulWidget {
  final GuideApplication application;
  const AuditDetailPage({super.key, required this.application});

  @override
  State<AuditDetailPage> createState() => _AuditDetailPageState();
}

class _AuditDetailPageState extends State<AuditDetailPage> {
  bool _isProcessing = false;

  void _approve() async {
    setState(() => _isProcessing = true);
    try {
      await context.read<ApplicationProvider>().auditApplication(
        widget.application.id,
        true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('审批已通过')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showRejectDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('驳回申请'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '请输入驳回原因'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context);
              _reject(controller.text.trim());
            }, 
            child: const Text('确认驳回', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _reject(String reason) async {
    setState(() => _isProcessing = true);
    try {
      await context.read<ApplicationProvider>().auditApplication(
        widget.application.id,
        false,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('申请已驳回')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<UserProvider>().isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('申请详情')),
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

    final app = widget.application;
    return Scaffold(
      appBar: AppBar(title: const Text('申请详情')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('基本信息', [
              _buildInfoRow('真实姓名', app.fullName),
              _buildInfoRow('性别', app.gender ?? '未填'),
              _buildInfoRow('身份证号', app.idCardNum ?? '未填'),
              _buildInfoRow('所在城市', app.city ?? '未填'),
            ]),
            const SizedBox(height: 24),
            _buildSection('实名证件', [
              const Text('身份证人像面:', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              _buildImageFrame(app.idCardFront),
              const SizedBox(height: 16),
              const Text('身份证国徽面:', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              _buildImageFrame(app.idCardBack),
            ]),
            const SizedBox(height: 24),
            _buildSection('个人简介', [
              Text(app.bio ?? '暂无介绍', style: const TextStyle(fontSize: 15, height: 1.5)),
            ]),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isProcessing ? null : _showRejectDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('驳回申请'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _approve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('审批通过'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildImageFrame(String? url) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.tagBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: url != null && url.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: AppColors.textHint))),
          )
        : const Center(child: Icon(Icons.image, color: AppColors.textHint, size: 48)),
    );
  }
}
