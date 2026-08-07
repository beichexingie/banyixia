import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../providers/guide_backend_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideServiceManagementPage extends StatelessWidget {
  const GuideServiceManagementPage({super.key});

  Future<void> _edit(BuildContext context, [GuideServiceItemData? item]) async {
    final name = TextEditingController(text: item?.name ?? '');
    final description = TextEditingController(text: item?.description ?? '');
    final hour = TextEditingController(text: item == null ? '' : item.pricePerHour.toStringAsFixed(0));
    final day = TextEditingController(text: item == null ? '' : item.pricePerDay.toStringAsFixed(0));
    var enabled = item?.enabled ?? true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(item == null ? '新增服务项目' : '编辑服务项目'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: '服务名称')),
              TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: '服务说明')),
              TextField(controller: hour, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '小时价（可选）')),
              TextField(controller: day, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '日价（可选）')),
              SwitchListTile(value: enabled, onChanged: (value) => setState(() => enabled = value), title: const Text('上架展示')),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('保存'))],
        ),
      ),
    );
    final nameValue = name.text.trim();
    final descriptionValue = description.text.trim();
    final hourValue = double.tryParse(hour.text.trim()) ?? 0;
    final dayValue = double.tryParse(day.text.trim()) ?? 0;
    name.dispose(); description.dispose(); hour.dispose(); day.dispose();
    if (confirmed != true || !context.mounted) return;
    try {
      final provider = context.read<GuideBackendProvider>();
      if (item == null) {
        await provider.addServiceItem(name: nameValue, description: descriptionValue, pricePerHour: hourValue, pricePerDay: dayValue);
      } else {
        await provider.updateServiceItem(item.id, name: nameValue, description: descriptionValue, pricePerHour: hourValue, pricePerDay: dayValue, enabled: enabled);
      }
    } catch (error) {
      if (context.mounted) _message(context, '保存失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuideBackendProvider>();
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('服务项目'), backgroundColor: Colors.white, actions: [IconButton(onPressed: provider.load, icon: const Icon(Icons.refresh))]),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const GuideSectionCard(child: Text('这里配置的是你提供给客户选择的服务，不是付款页面。新增、编辑、上下架会保存到服务器。', style: TextStyle(height: 1.5, color: AppColors.textSecondary))),
        const SizedBox(height: 12),
        if (provider.serviceItems.isEmpty) const _EmptyCard(icon: Icons.handshake_outlined, text: '还没有服务项目')
        else ...provider.serviceItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GuideSectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))), Switch(value: item.enabled, onChanged: (value) async { try { await provider.updateServiceItem(item.id, enabled: value); } catch (error) { if (context.mounted) _message(context, '更新失败：$error'); } })]),
            const SizedBox(height: 6),
            Text(item.description.isEmpty ? '未填写服务说明' : item.description, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
            const SizedBox(height: 10),
            Text('小时价 ¥${item.pricePerHour.toStringAsFixed(0)} · 日价 ¥${item.pricePerDay.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            Align(alignment: Alignment.centerRight, child: Wrap(spacing: 4, children: [TextButton(onPressed: () => _edit(context, item), child: const Text('编辑')), TextButton(onPressed: () async { try { await provider.deleteServiceItem(item.id); } catch (error) { if (context.mounted) _message(context, '删除失败：$error'); } }, child: const Text('删除'))])),
          ])),
        )),
        const SizedBox(height: 88),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(context), icon: const Icon(Icons.add), label: const Text('新增项目')),
    );
  }
}

class GuideSchedulePage extends StatelessWidget {
  const GuideSchedulePage({super.key});

  Future<void> _add(BuildContext context) async {
    final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 180)), initialDate: DateTime.now());
    if (date == null || !context.mounted) return;
    final start = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 9, minute: 0));
    if (start == null || !context.mounted) return;
    final end = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 18, minute: 0));
    if (end == null || !context.mounted) return;
    String two(int value) => value.toString().padLeft(2, '0');
    final dateText = '${date.year}-${two(date.month)}-${two(date.day)}';
    final startText = '${two(start.hour)}:${two(start.minute)}';
    final endText = '${two(end.hour)}:${two(end.minute)}';
    try {
      await context.read<GuideBackendProvider>().addAvailability(date: dateText, start: startText, end: endText);
    } catch (error) {
      if (context.mounted) _message(context, '保存失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuideBackendProvider>();
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('时间管理'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        const GuideSectionCard(child: Text('设置可接单时段后，用户和平台才会把对应时间的需求推荐给你。已有订单优先于排班。', style: TextStyle(height: 1.5, color: AppColors.textSecondary))),
        const SizedBox(height: 12),
        if (provider.availability.isEmpty) const _EmptyCard(icon: Icons.calendar_month_outlined, text: '暂无可接单时段')
        else ...provider.availability.map((item) {
          final note = item['note']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GuideSectionCard(child: Row(children: [
              const Icon(Icons.schedule, color: AppColors.primaryDark),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['service_date']?.toString() ?? '', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text('${item['start_time'] ?? ''} - ${item['end_time'] ?? ''}${note.isEmpty ? '' : '  $note'}', style: const TextStyle(color: AppColors.textSecondary))])),
              IconButton(onPressed: () async { try { await provider.deleteAvailability(item['id'].toString()); } catch (error) { if (context.mounted) _message(context, '删除失败：$error'); } }, icon: const Icon(Icons.delete_outline)),
            ])),
          );
        }),
        const SizedBox(height: 88),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _add(context), icon: const Icon(Icons.add), label: const Text('添加时段')),
    );
  }
}

class GuideReviewCenterPage extends StatelessWidget {
  const GuideReviewCenterPage({super.key});

  Future<void> _reply(BuildContext context, Map<String, dynamic> review) async {
    final controller = TextEditingController(text: review['guide_reply']?.toString() ?? '');
    final reply = await showDialog<String>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('回复客户评价'), content: TextField(controller: controller, maxLines: 4, decoration: const InputDecoration(hintText: '回复会经过内容审核')), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('提交'))]));
    controller.dispose();
    if (reply == null || reply.isEmpty || !context.mounted) return;
    try { await context.read<GuideBackendProvider>().replyReview(review['id'].toString(), reply); } catch (error) { if (context.mounted) _message(context, '提交失败：$error'); }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuideBackendProvider>();
    return GuideAppScaffold(appBar: AppBar(title: const Text('客户评价'), backgroundColor: Colors.white), backgroundColor: const Color(0xFFF0F1F3), body: ListView(padding: const EdgeInsets.all(16), children: [
      GuideSectionCard(child: Text(provider.reviews.isEmpty ? '暂无客户评价。订单完成后，客户可匿名提交真实反馈。' : '共收到 ${provider.reviews.length} 条匿名客户反馈。', style: const TextStyle(color: AppColors.textSecondary))),
      const SizedBox(height: 12),
      if (provider.reviews.isEmpty) const _EmptyCard(icon: Icons.reviews_outlined, text: '暂无评价')
      else ...provider.reviews.map((review) => Padding(padding: const EdgeInsets.only(bottom: 10), child: GuideSectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Expanded(child: Text('匿名客户', style: TextStyle(fontWeight: FontWeight.w900))), Text('${review['rating'] ?? 0} 分', style: const TextStyle(color: Color(0xFFE28B24), fontWeight: FontWeight.w900))]),
        const SizedBox(height: 8), Text(review['content']?.toString() ?? ''), const SizedBox(height: 8), Text(review['service_name']?.toString() ?? '地陪服务', style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
        const SizedBox(height: 8), if ((review['guide_reply']?.toString() ?? '').isNotEmpty) Text('我的回复：${review['guide_reply']}', style: const TextStyle(color: AppColors.textSecondary)) else Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _reply(context, review), icon: const Icon(Icons.reply), label: const Text('回复'))),
      ])))),
    ]));
  }
}

class GuideTaskCenterPage extends StatelessWidget {
  const GuideTaskCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuideBackendProvider>();
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('任务中心'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const GuideSectionCard(child: Text('任务状态由资料、服务项目、排班、订单和客户评价自动计算，不能通过点击伪造完成。', style: TextStyle(height: 1.5, color: AppColors.textSecondary))),
          const SizedBox(height: 12),
          ...provider.tasks.map((task) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GuideSectionCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(task['done'] == true ? Icons.check_circle : Icons.radio_button_unchecked, color: task['done'] == true ? Colors.green : AppColors.textHint),
                title: Text(task['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900)),
                subtitle: Text(task['description']?.toString() ?? ''),
                trailing: Text(task['done'] == true ? '已完成' : '未满足', style: TextStyle(color: task['done'] == true ? Colors.green : AppColors.textHint)),
              ),
            ),
          )),
        ],
      ),
    );
  }
}

class GuideTrainingCenterPage extends StatelessWidget {
  const GuideTrainingCenterPage({super.key});
  Future<void> _open(BuildContext context, Map<String, dynamic> course) async {
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: Text(course['title']?.toString() ?? ''), content: SingleChildScrollView(child: Text(course['content']?.toString() ?? '', style: const TextStyle(height: 1.6))), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('关闭')), if (course['completed'] != true) FilledButton(onPressed: () async { try { await context.read<GuideBackendProvider>().completeTraining(course['id'].toString()); if (dialogContext.mounted) Navigator.pop(dialogContext); } catch (error) { if (context.mounted) _message(context, '记录失败：$error'); } }, child: const Text('学完并记录'))]));
  }
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuideBackendProvider>();
    return GuideAppScaffold(appBar: AppBar(title: const Text('培训中心'), backgroundColor: Colors.white), backgroundColor: const Color(0xFFF0F1F3), body: ListView(padding: const EdgeInsets.all(16), children: [
      const GuideSectionCard(child: Text('课程内容由平台维护。阅读课程后可记录完成，必修课完成状态会跨设备保存。', style: TextStyle(height: 1.5, color: AppColors.textSecondary))), const SizedBox(height: 12),
      ...provider.training.map((course) => Padding(padding: const EdgeInsets.only(bottom: 10), child: GuideSectionCard(child: ListTile(contentPadding: EdgeInsets.zero, onTap: () => _open(context, course), leading: Icon(course['completed'] == true ? Icons.school : Icons.menu_book_outlined, color: course['completed'] == true ? Colors.green : AppColors.primaryDark), title: Text(course['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w900)), subtitle: Text(course['summary']?.toString() ?? ''), trailing: Icon(course['completed'] == true ? Icons.check_circle : Icons.chevron_right))))),
    ]));
  }
}

class GuideOperationPage extends StatefulWidget {
  const GuideOperationPage({super.key});

  @override
  State<GuideOperationPage> createState() => _GuideOperationPageState();
}

class _GuideOperationPageState extends State<GuideOperationPage> {
  final _content = TextEditingController();
  String _category = '运营咨询';

  @override
  void dispose() { _content.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuideBackendProvider>();
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('专属运营'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GuideSectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('提交运营工单', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('活动、订单协助、资料修改和申诉都会生成可追踪工单。', style: TextStyle(color: AppColors.textSecondary)),
          DropdownButtonFormField<String>(value: _category, items: const ['运营咨询', '订单协助', '活动报名', '申诉'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => setState(() => _category = value ?? _category)),
          TextField(controller: _content, maxLines: 4, decoration: const InputDecoration(labelText: '问题描述')),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
            try { await provider.createSupportRequest(category: _category, content: _content.text.trim()); _content.clear(); if (mounted) _message(context, '工单已提交'); }
            catch (error) { if (mounted) _message(context, '提交失败：$error'); }
          }, child: const Text('提交工单'))),
        ])),
        const SizedBox(height: 12),
        if (provider.supportRequests.isEmpty) const _EmptyCard(icon: Icons.support_agent_outlined, text: '暂无运营工单')
        else ...provider.supportRequests.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: GuideSectionCard(child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item['category']?.toString() ?? '运营咨询'),
          subtitle: Text('${item['content']?.toString() ?? ''}${(item['reply']?.toString() ?? '').isEmpty ? '' : '\n运营回复：${item['reply']}'}'),
          trailing: Text(item['status']?.toString() ?? 'open'),
        )))),
      ]),
    );
  }
}

class GuideInsurancePage extends StatefulWidget { const GuideInsurancePage({super.key}); @override State<GuideInsurancePage> createState() => _GuideInsurancePageState(); }
class _GuideInsurancePageState extends State<GuideInsurancePage> {
  final _provider = TextEditingController(); final _policy = TextEditingController(); final _expires = TextEditingController();
  @override void dispose() { _provider.dispose(); _policy.dispose(); _expires.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) { final backend = context.watch<GuideBackendProvider>(); final insurance = backend.insurance; final status = insurance == null ? '尚未提交保险资料。请填写真实保单信息，平台审核后显示保障状态。' : '当前状态：${insurance['status'] ?? 'pending'}${insurance['reject_reason'] == null ? '' : '\n驳回原因：${insurance['reject_reason']}'}'; return GuideAppScaffold(appBar: AppBar(title: const Text('地陪保险'), backgroundColor: Colors.white), backgroundColor: const Color(0xFFF0F1F3), body: ListView(padding: const EdgeInsets.all(16), children: [GuideSectionCard(child: Text(status, style: const TextStyle(height: 1.5, color: AppColors.textSecondary))), const SizedBox(height: 12), GuideSectionCard(child: Column(children: [TextField(controller: _provider, decoration: const InputDecoration(labelText: '保险公司')), TextField(controller: _policy, decoration: const InputDecoration(labelText: '保单号')), TextField(controller: _expires, readOnly: true, decoration: const InputDecoration(labelText: '到期日期', suffixIcon: Icon(Icons.calendar_today)), onTap: () async { final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650)), initialDate: DateTime.now().add(const Duration(days: 365))); if (date != null) _expires.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'; }), const SizedBox(height: 14), SizedBox(width: double.infinity, child: FilledButton(onPressed: () async { try { await backend.saveInsurance(provider: _provider.text.trim(), policyNo: _policy.text.trim(), expiresAt: _expires.text.trim()); if (mounted) _message(context, '已提交，等待平台审核'); } catch (error) { if (mounted) _message(context, '提交失败：$error'); } }, child: const Text('提交审核')))]))])); }
}

class GuideBlockedUsersPage extends StatefulWidget {
  const GuideBlockedUsersPage({super.key});

  @override
  State<GuideBlockedUsersPage> createState() => _GuideBlockedUsersPageState();
}

class _GuideBlockedUsersPageState extends State<GuideBlockedUsersPage> {
  final _phone = TextEditingController();
  final _reason = TextEditingController();

  @override
  void dispose() { _phone.dispose(); _reason.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final backend = context.watch<GuideBackendProvider>();
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('屏蔽名单'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GuideSectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('屏蔽后，平台不会再向你推荐该用户的需求。仅填写已知的真实用户手机号。', style: TextStyle(color: AppColors.textSecondary)),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: '用户手机号')),
          TextField(controller: _reason, decoration: const InputDecoration(labelText: '屏蔽原因（可选）')),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
            try {
              await backend.addBlockedUser(phone: _phone.text.trim(), reason: _reason.text.trim());
              _phone.clear(); _reason.clear();
              if (mounted) _message(context, '已加入屏蔽名单');
            } catch (error) { if (mounted) _message(context, '操作失败：$error'); }
          }, child: const Text('加入屏蔽名单'))),
        ])),
        const SizedBox(height: 12),
        if (backend.blockedUsers.isEmpty) const _EmptyCard(icon: Icons.person_off_outlined, text: '暂无屏蔽用户')
        else ...backend.blockedUsers.map((item) => Padding(padding: const EdgeInsets.only(bottom: 10), child: GuideSectionCard(child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(item['nickname']?.toString().isNotEmpty == true ? item['nickname'].toString() : '用户'),
          subtitle: Text(item['reason']?.toString() ?? ''),
          trailing: IconButton(onPressed: () async { try { await backend.removeBlockedUser(item['blocked_user_id'].toString()); } catch (error) { if (context.mounted) _message(context, '操作失败：$error'); } }, icon: const Icon(Icons.remove_circle_outline)),
        )))),
      ]),
    );
  }
}

class GuideAuxiliarySettingsPage extends StatelessWidget {
  const GuideAuxiliarySettingsPage({super.key});
  @override Widget build(BuildContext context) { final backend = context.watch<GuideBackendProvider>(); final aux = backend.settings['auxiliary'] is Map ? Map<String, dynamic>.from(backend.settings['auxiliary'] as Map) : <String, dynamic>{}; Future<void> save(String key, bool value) async { aux[key] = value; try { await backend.saveSettings(auxiliary: aux); } catch (error) { if (context.mounted) _message(context, '保存失败：$error'); } } return GuideAppScaffold(appBar: AppBar(title: const Text('辅助设置'), backgroundColor: Colors.white), backgroundColor: const Color(0xFFF0F1F3), body: ListView(padding: const EdgeInsets.all(16), children: [GuideSectionCard(child: Column(children: [SwitchListTile(value: aux['show_distance'] != false, onChanged: (value) => save('show_distance', value), title: const Text('订单距离提醒'), subtitle: const Text('在订单卡片显示当前位置到服务地的距离')), SwitchListTile(value: aux['reminders'] != false, onChanged: (value) => save('reminders', value), title: const Text('服务时间提醒'), subtitle: const Text('服务开始前提醒确认行程')), SwitchListTile(value: aux['auto_reply'] == true, onChanged: (value) => save('auto_reply', value), title: const Text('自动回复模板'), subtitle: const Text('只保存开关，不会替你向客户承诺接单'))]))])); }
}

class _EmptyCard extends StatelessWidget { final IconData icon; final String text; const _EmptyCard({required this.icon, required this.text}); @override Widget build(BuildContext context) => GuideSectionCard(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [Icon(icon, size: 46, color: AppColors.textHint), const SizedBox(height: 10), Text(text, style: const TextStyle(fontWeight: FontWeight.w800))]))); }
void _message(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
