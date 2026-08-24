import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../providers/guide_backend_provider.dart';
import '../widgets/guide_app_shell.dart';
import 'package:flutter_application_1/widgets/time_range_picker.dart';

class GuideServiceManagementPage extends StatelessWidget {
  const GuideServiceManagementPage({super.key});

  Future<void> _edit(BuildContext context, [GuideServiceItemData? item]) async {
    final result = await showDialog<_GuideServiceEditorResult>(
      context: context,
      builder: (_) => _GuideServiceEditorDialog(item: item),
    );
    if (result == null || !context.mounted) return;
    try {
      final provider = context.read<GuideBackendProvider>();
      if (item == null) {
        await provider.addServiceItem(
          name: result.name,
          description: result.description,
          pricePerHour: result.pricePerHour,
        );
      } else {
        await provider.updateServiceItem(
          item.id,
          name: result.name,
          description: result.description,
          pricePerHour: result.pricePerHour,
        );
      }
    } catch (error) {
      if (context.mounted) _message(context, '保存失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuideBackendProvider>();
    return GuideAppScaffold(
      appBar: AppBar(
        title: const Text('服务项目'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(onPressed: provider.load, icon: const Icon(Icons.refresh)),
        ],
      ),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const GuideSectionCard(
            child: Text(
              '服务名称只能从个人资料中已选择的服务类型里选择。保存后会直接展示在你的主页，客户只能从这些项目下单。',
              style: TextStyle(height: 1.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          if (provider.serviceItems.isEmpty)
            const _EmptyCard(icon: Icons.handshake_outlined, text: '还没有服务项目')
          else
            ...provider.serviceItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GuideSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.description.isEmpty ? '未填写服务说明' : item.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '小时价 ¥${item.pricePerHour.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 4,
                          children: [
                            TextButton(
                              onPressed: () => _edit(context, item),
                              child: const Text('编辑'),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await provider.deleteServiceItem(item.id);
                                } catch (error) {
                                  if (context.mounted)
                                    _message(context, '删除失败：$error');
                                }
                              },
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 88),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('新增项目'),
      ),
    );
  }
}

class _GuideServiceEditorResult {
  const _GuideServiceEditorResult({
    required this.name,
    required this.description,
    required this.pricePerHour,
  });

  final String name;
  final String description;
  final double pricePerHour;
}

class _GuideServiceEditorDialog extends StatefulWidget {
  const _GuideServiceEditorDialog({this.item});

  final GuideServiceItemData? item;

  @override
  State<_GuideServiceEditorDialog> createState() =>
      _GuideServiceEditorDialogState();
}

class _GuideServiceEditorDialogState extends State<_GuideServiceEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _hour;
  late String _selectedName;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _name = TextEditingController(text: item?.name ?? '');
    _selectedName = item?.name ?? '';
    _description = TextEditingController(text: item?.description ?? '');
    _hour = TextEditingController(
      text: item == null ? '' : item.pricePerHour.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _hour.dispose();
    super.dispose();
  }

  void _save() {
    final name = _selectedName.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '请填写服务名称');
      return;
    }
    Navigator.of(context).pop(
      _GuideServiceEditorResult(
        name: name,
        description: _description.text.trim(),
        pricePerHour: double.tryParse(_hour.text.trim()) ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.item != null;
    final tags = context.read<GuideBackendProvider>().guideTags;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.handshake_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          editing ? '编辑服务项目' : '新增服务项目',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '保存后将展示在你的地陪主页',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: tags.contains(_selectedName) ? _selectedName : null,
                items: tags
                    .map(
                      (tag) => DropdownMenuItem(value: tag, child: Text(tag)),
                    )
                    .toList(),
                onChanged: (value) => setState(() {
                  _selectedName = value ?? '';
                  _nameError = null;
                }),
                decoration: InputDecoration(
                  labelText: '服务类型',
                  errorText: _nameError,
                  hintText: tags.isEmpty ? '请先在个人资料选择服务类型' : '选择已登记的服务类型',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _description,
                minLines: 3,
                maxLines: 5,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: '服务说明',
                  hintText: '说明服务内容、适用场景和注意事项',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _hour,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '小时价',
                  prefixText: '¥ ',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(editing ? '保存修改' : '创建项目'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GuideSchedulePage extends StatefulWidget {
  const GuideSchedulePage({super.key});

  @override
  State<GuideSchedulePage> createState() => _GuideSchedulePageState();
}

class _GuideSchedulePageState extends State<GuideSchedulePage> {
  static const _firstHour = 6;
  static const _lastHour = 23;
  static const _dayCount = 7;
  static const _dayWidth = 96.0;
  static const _hourHeight = 56.0;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _dayAt(int index) => _today.add(Duration(days: index));

  String _dateText(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  DateTime? _parseDate(dynamic raw) {
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  int? _minutes(dynamic raw) {
    final parts = raw?.toString().split(':') ?? const <String>[];
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  DateTime _initialTime(DateTime day, int hour) =>
      DateTime(day.year, day.month, day.day, hour);

  Future<void> _editSlot(
    BuildContext context, {
    DateTime? day,
    Map<String, dynamic>? item,
  }) async {
    final selectedDay = day ?? _parseDate(item?['service_date']) ?? _today;
    final startMinutes = _minutes(item?['start_time']);
    final endMinutes = _minutes(item?['end_time']);
    final initialStart = startMinutes == null
        ? _initialTime(selectedDay, _firstHour)
        : _initialTime(
            selectedDay,
            startMinutes ~/ 60,
          ).add(Duration(minutes: startMinutes % 60));
    final initialEnd = endMinutes == null
        ? initialStart.add(const Duration(hours: 1))
        : _initialTime(
            selectedDay,
            endMinutes ~/ 60,
          ).add(Duration(minutes: endMinutes % 60));
    final range = await showAppTimeRangePicker(
      context,
      initialStart: initialStart,
      initialEnd: initialEnd,
      firstDate: _today,
      dateCount: _dayCount,
      minHours: 1,
      title: item == null ? '添加接单时段' : '修改接单时段',
      subtitle: '选择未来 7 天内的具体日期，再点击开始和结束时间',
    );
    if (range == null || !context.mounted) return;
    final date = range.start;
    final start = TimeOfDay.fromDateTime(range.start);
    final end = TimeOfDay.fromDateTime(range.end);
    String two(int value) => value.toString().padLeft(2, '0');
    final dateText = _dateText(date);
    final startText = '${two(start.hour)}:${two(start.minute)}';
    final endText = '${two(end.hour)}:${two(end.minute)}';
    final provider = context.read<GuideBackendProvider>();
    try {
      if (item != null) {
        await provider.deleteAvailability(item['id'].toString());
      }
      await provider.addAvailability(
        date: dateText,
        start: startText,
        end: endText,
        recurrenceType: 'exact',
        dateStart: dateText,
        dateEnd: dateText,
      );
    } catch (error) {
      if (context.mounted) _message(context, '保存失败：$error');
    }
  }

  List<Map<String, dynamic>> _itemsForDay(
    List<Map<String, dynamic>> items,
    DateTime day,
  ) {
    return items.where((item) {
      final itemDay = _parseDate(item['service_date'] ?? item['date_start']);
      return itemDay != null &&
          itemDay.year == day.year &&
          itemDay.month == day.month &&
          itemDay.day == day.day;
    }).toList();
  }

  String _weekday(DateTime day) =>
      const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][day.weekday - 1];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuideBackendProvider>();
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('时间管理'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const GuideSectionCard(
            child: Text(
              '未来 7 天接单安排。点击已有彩色时段可修改，点击空白日期或底部按钮可添加。',
              style: TextStyle(height: 1.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          GuideSectionCard(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 56 + _dayCount * _dayWidth,
                child: Column(
                  children: [
                    SizedBox(
                      height: 58,
                      child: Row(
                        children: [
                          const SizedBox(width: 56),
                          ...List.generate(_dayCount, (index) {
                            final day = _dayAt(index);
                            return SizedBox(
                              width: _dayWidth,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    index == 0 ? '今天' : _weekday(day),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    '${day.month}/${day.day}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: (_lastHour - _firstHour) * _hourHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 56,
                            child: Column(
                              children: List.generate(
                                _lastHour - _firstHour,
                                (index) => SizedBox(
                                  height: _hourHeight,
                                  child: Text(
                                    '${(_firstHour + index).toString().padLeft(2, '0')}:00',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ...List.generate(_dayCount, (index) {
                            final day = _dayAt(index);
                            final dayItems = _itemsForDay(
                              provider.availability,
                              day,
                            );
                            return GestureDetector(
                              onTap: dayItems.isEmpty
                                  ? () => _editSlot(context, day: day)
                                  : null,
                              child: SizedBox(
                                width: _dayWidth,
                                height: (_lastHour - _firstHour) * _hourHeight,
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Column(
                                        children: List.generate(
                                          _lastHour - _firstHour,
                                          (_) => Container(
                                            height: _hourHeight,
                                            decoration: const BoxDecoration(
                                              border: Border(
                                                top: BorderSide(
                                                  color: Color(0xFFECECEC),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    ...dayItems.map((item) {
                                      final start = _minutes(
                                        item['start_time'],
                                      );
                                      final end = _minutes(item['end_time']);
                                      if (start == null || end == null) {
                                        return const SizedBox.shrink();
                                      }
                                      final top =
                                          ((start - _firstHour * 60) / 60) *
                                          _hourHeight;
                                      final height =
                                          ((end - start) / 60) * _hourHeight;
                                      return Positioned(
                                        top: top.clamp(0, double.infinity),
                                        left: 6,
                                        right: 6,
                                        height: height.clamp(
                                          28,
                                          double.infinity,
                                        ),
                                        child: GestureDetector(
                                          onTap: () =>
                                              _editSlot(context, item: item),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            alignment: Alignment.topLeft,
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${item['start_time']} - ${item['end_time']}',
                                              maxLines: 2,
                                              overflow: TextOverflow.clip,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (provider.availability.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                '还没有安排，点击任意一天即可添加。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textHint),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editSlot(context),
        icon: const Icon(Icons.add),
        label: const Text('添加时段'),
      ),
    );
  }
}

class GuideReviewCenterPage extends StatefulWidget {
  const GuideReviewCenterPage({super.key});

  @override
  State<GuideReviewCenterPage> createState() => _GuideReviewCenterPageState();
}

class _GuideReviewCenterPageState extends State<GuideReviewCenterPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<GuideBackendProvider>().load();
    });
  }

  Future<void> _reply(BuildContext context, Map<String, dynamic> review) async {
    final controller = TextEditingController(
      text: review['guide_reply']?.toString() ?? '',
    );
    final reply = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('回复客户评价'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: '回复会经过内容审核'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('提交'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reply == null || reply.isEmpty || !context.mounted) return;
    try {
      await context.read<GuideBackendProvider>().replyReview(
        review['id'].toString(),
        reply,
      );
    } catch (error) {
      if (context.mounted) _message(context, '提交失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuideBackendProvider>();
    return GuideAppScaffold(
      appBar: AppBar(
        title: const Text('客户评价'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(onPressed: provider.load, icon: const Icon(Icons.refresh)),
        ],
      ),
      backgroundColor: const Color(0xFFF0F1F3),
      body: RefreshIndicator(
        onRefresh: provider.load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GuideSectionCard(
              child: Text(
                provider.reviews.isEmpty
                    ? '暂无客户评价。订单完成后，客户可匿名提交真实反馈。'
                    : '共收到 ${provider.reviews.length} 条匿名客户反馈。',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 12),
            if (provider.reviews.isEmpty)
              const _EmptyCard(icon: Icons.reviews_outlined, text: '暂无评价')
            else
              ...provider.reviews.map(
                (review) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GuideSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '匿名客户',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                            Text(
                              '${review['rating'] ?? 0} 分',
                              style: const TextStyle(
                                color: Color(0xFFE28B24),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(review['content']?.toString() ?? ''),
                        const SizedBox(height: 8),
                        Text(
                          review['service_name']?.toString() ?? '地陪服务',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if ((review['guide_reply']?.toString() ?? '')
                            .isNotEmpty)
                          Text(
                            '我的回复：${review['guide_reply']}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _reply(context, review),
                              icon: const Icon(Icons.reply),
                              label: const Text('回复'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
          const GuideSectionCard(
            child: Text(
              '任务状态由资料、服务项目、排班、订单和客户评价自动计算，不能通过点击伪造完成。',
              style: TextStyle(height: 1.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          ...provider.tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GuideSectionCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    task['done'] == true
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    color: task['done'] == true
                        ? Colors.green
                        : AppColors.textHint,
                  ),
                  title: Text(
                    task['title']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(task['description']?.toString() ?? ''),
                  trailing: Text(
                    task['done'] == true ? '已完成' : '未满足',
                    style: TextStyle(
                      color: task['done'] == true
                          ? Colors.green
                          : AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GuideTrainingCenterPage extends StatelessWidget {
  const GuideTrainingCenterPage({super.key});
  Future<void> _open(BuildContext context, Map<String, dynamic> course) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(course['title']?.toString() ?? ''),
        content: SingleChildScrollView(
          child: Text(
            course['content']?.toString() ?? '',
            style: const TextStyle(height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
          if (course['completed'] != true)
            FilledButton(
              onPressed: () async {
                try {
                  await context.read<GuideBackendProvider>().completeTraining(
                    course['id'].toString(),
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                } catch (error) {
                  if (context.mounted) _message(context, '记录失败：$error');
                }
              },
              child: const Text('学完并记录'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuideBackendProvider>();
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('培训中心'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const GuideSectionCard(
            child: Text(
              '课程内容由平台维护。阅读课程后可记录完成，必修课完成状态会跨设备保存。',
              style: TextStyle(height: 1.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 12),
          ...provider.training.map(
            (course) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GuideSectionCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => _open(context, course),
                  leading: Icon(
                    course['completed'] == true
                        ? Icons.school
                        : Icons.menu_book_outlined,
                    color: course['completed'] == true
                        ? Colors.green
                        : AppColors.primaryDark,
                  ),
                  title: Text(
                    course['title']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(course['summary']?.toString() ?? ''),
                  trailing: Icon(
                    course['completed'] == true
                        ? Icons.check_circle
                        : Icons.chevron_right,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GuideBackendProvider>();
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('专属运营'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuideSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '提交运营工单',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  '活动、订单协助、资料修改和申诉都会生成可追踪工单。',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                DropdownButtonFormField<String>(
                  value: _category,
                  items: const ['运营咨询', '订单协助', '活动报名', '申诉']
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => _category = value ?? _category),
                ),
                TextField(
                  controller: _content,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '问题描述'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await provider.createSupportRequest(
                          category: _category,
                          content: _content.text.trim(),
                        );
                        _content.clear();
                        if (mounted) _message(context, '工单已提交');
                      } catch (error) {
                        if (mounted) _message(context, '提交失败：$error');
                      }
                    },
                    child: const Text('提交工单'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (provider.supportRequests.isEmpty)
            const _EmptyCard(icon: Icons.support_agent_outlined, text: '暂无运营工单')
          else
            ...provider.supportRequests.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GuideSectionCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['category']?.toString() ?? '运营咨询'),
                    subtitle: Text(
                      '${item['content']?.toString() ?? ''}${(item['reply']?.toString() ?? '').isEmpty ? '' : '\n运营回复：${item['reply']}'}',
                    ),
                    trailing: Text(item['status']?.toString() ?? 'open'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GuideInsurancePage extends StatefulWidget {
  const GuideInsurancePage({super.key});
  @override
  State<GuideInsurancePage> createState() => _GuideInsurancePageState();
}

class _GuideInsurancePageState extends State<GuideInsurancePage> {
  final _provider = TextEditingController();
  final _policy = TextEditingController();
  final _expires = TextEditingController();
  @override
  void dispose() {
    _provider.dispose();
    _policy.dispose();
    _expires.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.watch<GuideBackendProvider>();
    final insurance = backend.insurance;
    final status = insurance == null
        ? '尚未提交保险资料。请填写真实保单信息，平台审核后显示保障状态。'
        : '当前状态：${insurance['status'] ?? 'pending'}${insurance['reject_reason'] == null ? '' : '\n驳回原因：${insurance['reject_reason']}'}';
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('地陪保险'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuideSectionCard(
            child: Text(
              status,
              style: const TextStyle(
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          GuideSectionCard(
            child: Column(
              children: [
                TextField(
                  controller: _provider,
                  decoration: const InputDecoration(labelText: '保险公司'),
                ),
                TextField(
                  controller: _policy,
                  decoration: const InputDecoration(labelText: '保单号'),
                ),
                TextField(
                  controller: _expires,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: '到期日期',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: DateTime.now().add(
                        const Duration(days: 365),
                      ),
                    );
                    if (date != null)
                      _expires.text =
                          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  },
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await backend.saveInsurance(
                          provider: _provider.text.trim(),
                          policyNo: _policy.text.trim(),
                          expiresAt: _expires.text.trim(),
                        );
                        if (mounted) _message(context, '已提交，等待平台审核');
                      } catch (error) {
                        if (mounted) _message(context, '提交失败：$error');
                      }
                    },
                    child: const Text('提交审核'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
  void dispose() {
    _phone.dispose();
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.watch<GuideBackendProvider>();
    return GuideAppScaffold(
      appBar: AppBar(title: const Text('屏蔽名单'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuideSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '屏蔽后，平台不会再向你推荐该用户的需求。仅填写已知的真实用户手机号。',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: '用户手机号'),
                ),
                TextField(
                  controller: _reason,
                  decoration: const InputDecoration(labelText: '屏蔽原因（可选）'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      try {
                        await backend.addBlockedUser(
                          phone: _phone.text.trim(),
                          reason: _reason.text.trim(),
                        );
                        _phone.clear();
                        _reason.clear();
                        if (mounted) _message(context, '已加入屏蔽名单');
                      } catch (error) {
                        if (mounted) _message(context, '操作失败：$error');
                      }
                    },
                    child: const Text('加入屏蔽名单'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (backend.blockedUsers.isEmpty)
            const _EmptyCard(icon: Icons.person_off_outlined, text: '暂无屏蔽用户')
          else
            ...backend.blockedUsers.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GuideSectionCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      item['nickname']?.toString().isNotEmpty == true
                          ? item['nickname'].toString()
                          : '用户',
                    ),
                    subtitle: Text(item['reason']?.toString() ?? ''),
                    trailing: IconButton(
                      onPressed: () async {
                        try {
                          await backend.removeBlockedUser(
                            item['blocked_user_id'].toString(),
                          );
                        } catch (error) {
                          if (context.mounted) _message(context, '操作失败：$error');
                        }
                      },
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class GuideAuxiliarySettingsPage extends StatelessWidget {
  const GuideAuxiliarySettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final backend = context.watch<GuideBackendProvider>();
    final aux = backend.settings['auxiliary'] is Map
        ? Map<String, dynamic>.from(backend.settings['auxiliary'] as Map)
        : <String, dynamic>{};
    Future<void> save(String key, bool value) async {
      aux[key] = value;
      try {
        await backend.saveSettings(auxiliary: aux);
      } catch (error) {
        if (context.mounted) _message(context, '保存失败：$error');
      }
    }

    return GuideAppScaffold(
      appBar: AppBar(title: const Text('辅助设置'), backgroundColor: Colors.white),
      backgroundColor: const Color(0xFFF0F1F3),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GuideSectionCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: aux['show_distance'] != false,
                  onChanged: (value) => save('show_distance', value),
                  title: const Text('订单距离提醒'),
                  subtitle: const Text('在订单卡片显示当前位置到服务地的距离'),
                ),
                SwitchListTile(
                  value: aux['reminders'] != false,
                  onChanged: (value) => save('reminders', value),
                  title: const Text('服务时间提醒'),
                  subtitle: const Text('服务开始前提醒确认行程'),
                ),
                SwitchListTile(
                  value: aux['auto_reply'] == true,
                  onChanged: (value) => save('auto_reply', value),
                  title: const Text('自动回复模板'),
                  subtitle: const Text('只保存开关，不会替你向客户承诺接单'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyCard({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => GuideSectionCard(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(icon, size: 46, color: AppColors.textHint),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  );
}

void _message(BuildContext context, String message) => ScaffoldMessenger.of(
  context,
).showSnackBar(SnackBar(content: Text(message)));
