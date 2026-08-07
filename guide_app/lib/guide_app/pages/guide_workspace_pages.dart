import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_theme.dart';
import '../../providers/user_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideChecklistPage extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<String> items;

  const GuideChecklistPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
  });

  @override
  State<GuideChecklistPage> createState() => _GuideChecklistPageState();
}

class _GuideChecklistPageState extends State<GuideChecklistPage> {
  late final List<bool> _completed;
  late final String _storageKey;

  @override
  void initState() {
    super.initState();
    _completed = List<bool>.filled(widget.items.length, false);
    _storageKey = 'guide_checklist_${widget.title}';
    _loadCompleted();
  }

  Future<void> _loadCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_storageKey);
    if (!mounted || values == null) return;
    setState(() {
      for (var index = 0; index < _completed.length && index < values.length; index++) {
        _completed[index] = values[index] == '1';
      }
    });
  }

  Future<void> _setCompleted(int index, bool value) async {
    setState(() => _completed[index] = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, _completed.map((item) => item ? '1' : '0').toList());
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completed.where((item) => item).length;
    return GuideAppScaffold(
      appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          GuideSectionCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.subtitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text('已完成 $completed/${widget.items.length}', style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GuideSectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: List.generate(widget.items.length, (index) {
                return CheckboxListTile(
                  value: _completed[index],
                  onChanged: (value) => _setCompleted(index, value ?? false),
                  title: Text(widget.items[index]),
                  subtitle: Text(_completed[index] ? '已完成' : '点击标记进度'),
                  activeColor: AppColors.primaryDark,
                  controlAffinity: ListTileControlAffinity.leading,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class GuideCertificationPage extends StatelessWidget {
  final VoidCallback onEditProfile;

  const GuideCertificationPage({super.key, required this.onEditProfile});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final status = user.guideApplicationStatus == 'approved' || user.isGuideApproved ? '已通过审核' : '审核中';
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('认证资料'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuideSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('地陪认证状态', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppColors.primaryDark),
                    const SizedBox(width: 8),
                    Text(status, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 18),
                _InfoLine(label: '昵称', value: user.nickname),
                _InfoLine(label: '城市', value: user.city.isEmpty ? '未填写' : user.city),
                _InfoLine(label: '职业', value: user.occupation.isEmpty ? '未填写' : user.occupation),
                _InfoLine(label: '个人介绍', value: user.guideIntroduction.isEmpty ? '未填写' : user.guideIntroduction),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: onEditProfile,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('编辑资料'),
            ),
          ),
        ],
      ),
    );
  }
}

class GuideRulesPage extends StatelessWidget {
  const GuideRulesPage({super.key});

  @override
  Widget build(BuildContext context) {
    const rules = {
      '接单前': '确认服务时间、地点、价格和客户需求，不清楚的内容先通过聊天确认。',
      '服务中': '按约定到达，不擅自增加收费项目，不向客户索要与服务无关的隐私信息。',
      '订单结束': '客户确认服务完成后再结束订单，遇到纠纷及时联系客服并保留聊天记录。',
      '违规处理': '平台会根据投诉、证据和订单记录进行核实，严重违规可能限制接单权限。',
    };
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('平台规则'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuideSectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: rules.entries.map((item) => ExpansionTile(title: Text(item.key), childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16), children: [Text(item.value, style: const TextStyle(height: 1.6, color: AppColors.textSecondary))])).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class GuideContactPage extends StatefulWidget {
  const GuideContactPage({super.key});

  @override
  State<GuideContactPage> createState() => _GuideContactPageState();
}

class _GuideContactPageState extends State<GuideContactPage> {
  final List<String> _contacts = [];

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _contacts.addAll(prefs.getStringList('guide_emergency_contacts') ?? const []));
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('guide_emergency_contacts', _contacts);
  }

  Future<void> _addContact() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增紧急联系人'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(hintText: '姓名和联系电话')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value.isNotEmpty && mounted) {
      setState(() => _contacts.add(value));
      await _saveContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('紧急联系人'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuideSectionCard(child: const Text('仅在发生安全、医疗或突发情况时使用。请确保联系人同意被记录。', style: TextStyle(height: 1.6, color: AppColors.textSecondary))),
          const SizedBox(height: 14),
          GuideSectionCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (_contacts.isEmpty) const ListTile(title: Text('还没有添加联系人'), subtitle: Text('建议至少添加一位可信赖的联系人')),
                ..._contacts.asMap().entries.map((entry) => ListTile(leading: const Icon(Icons.person_outline), title: Text(entry.value), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { setState(() => _contacts.removeAt(entry.key)); await _saveContacts(); }))),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(onPressed: _addContact, icon: const Icon(Icons.add), label: const Text('添加联系人')),
        ],
      ),
    );
  }
}

class GuideInvitePage extends StatelessWidget {
  const GuideInvitePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final rawCode = user.id.replaceAll('-', '');
    final code = rawCode.isEmpty ? 'GUIDE' : rawCode.substring(0, rawCode.length.clamp(1, 8).toInt());
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('拉新赚钱'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        GuideSectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('我的邀请码', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Row(children: [Expanded(child: Text(code, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900))), IconButton(onPressed: () { Clipboard.setData(ClipboardData(text: code)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('邀请码已复制'))); }, icon: const Icon(Icons.copy_outlined))]),
          const SizedBox(height: 8),
          const Text('邀请好友完成注册和认证后，收益与活动规则以平台通知为准。', style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
        ])),
        const SizedBox(height: 14),
        const GuideSectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('收益记录', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), SizedBox(height: 14), Text('当前暂无可结算的邀请收益', style: TextStyle(color: AppColors.textSecondary))])),
      ]),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 72, child: Text(label, style: const TextStyle(color: AppColors.textHint))), Expanded(child: Text(value, style: const TextStyle(height: 1.4)))]));
}
