import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class HelpFeedbackPage extends StatefulWidget {
  const HelpFeedbackPage({super.key});

  @override
  State<HelpFeedbackPage> createState() => _HelpFeedbackPageState();
}

class _HelpFeedbackPageState extends State<HelpFeedbackPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('帮助与反馈'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('常见问题', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildFaqItem('如何成为地陪？', '在首页点击"去入驻"，或在底部菜单的"+"号中选择"申请成为地陪"，填写真实信息后提交审核即可。'),
            _buildFaqItem('什么是搭子？', '搭子是指在同城有相同兴趣爱好，愿意一起出行、游玩、探店的小伙伴。可以发布通告寻找，也可以响应他人的通告。'),
            _buildFaqItem('信誉积分如何获取？', '完成实名认证、完善个人资料、完成高质量的相伴订单并获得好评均可提升信誉积分。'),
            const SizedBox(height: 24),
            const Text('意见反馈', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: '请详细描述您遇到的问题或建议...',
                  hintStyle: TextStyle(color: AppColors.textHint, fontSize: 14),
                  contentPadding: EdgeInsets.all(16),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  if (_controller.text.trim().isEmpty) {
                    _showSnack(context, '请输入反馈内容');
                    return;
                  }
                  _controller.clear();
                  FocusScope.of(context).unfocus();
                  _showSnack(context, '感谢您的反馈！我们会尽快处理');
                  Future.delayed(const Duration(seconds: 1), () {
                    if (context.mounted) Navigator.pop(context);
                  });
                },
                child: const Text('提交反馈', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String q, String a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(q, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        shape: const Border(),
        collapsedShape: const Border(),
        collapsedIconColor: AppColors.textHint,
        iconColor: AppColors.primary,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(a, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
