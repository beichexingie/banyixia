// Guide Apply Page
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class GuideApplyPage extends StatelessWidget {
  const GuideApplyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final introController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('申请成为地陪'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '姓名'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: '手机号'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: introController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '自我介绍'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('申请已提交 (模拟)')),
                );
                Navigator.of(context).pop();
              },
              child: const Text('提交'),
            ),
          ],
        ),
      ),
    );
  }
}
