// Travel Plan Creation Page
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class TravelPlanCreatePage extends StatelessWidget {
  const TravelPlanCreatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    return Scaffold(
      appBar: AppBar(
        title: const Text('创建旅行计划'),
        backgroundColor: AppColors.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '标题'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: '描述'),
            ),
            const SizedBox(height: 12),
            ListTile(
              title: const Text('开始日期'),
              subtitle: Text(startDate != null ? startDate!.toLocal().toString().split(' ')[0] : '未选择'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  startDate = picked;
                }
              },
            ),
            ListTile(
              title: const Text('结束日期'),
              subtitle: Text(endDate != null ? endDate!.toLocal().toString().split(' ')[0] : '未选择'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  endDate = picked;
                }
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('旅行计划已创建 (模拟)')),
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
