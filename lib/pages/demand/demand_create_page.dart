import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/demand_provider.dart';

class DemandCreatePage extends StatefulWidget {
  const DemandCreatePage({super.key});

  @override
  State<DemandCreatePage> createState() => _DemandCreatePageState();
}

class _DemandCreatePageState extends State<DemandCreatePage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _budgetController = TextEditingController();
  final _peopleController = TextEditingController();

  String _city = '苏州';
  String _location = '';
  DateTime? _startAt;
  DateTime? _endAt;
  String _gender = '不限';
  final Set<String> _tags = {'陪游'};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _contentController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _budgetController.dispose();
    _peopleController.dispose();
    super.dispose();
  }

  Future<void> _pickCity() async {
    final cities = ['苏州', '北京', '上海', '杭州', '成都', '西安', '长沙', '重庆', '广州', '深圳'];
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: cities.map((city) {
                final selected = city == _city;
                return ChoiceChip(
                  label: Text(city),
                  selected: selected,
                  onSelected: (_) => Navigator.pop(context, city),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
    if (selected != null && mounted) {
      setState(() => _city = selected);
    }
  }

  Future<void> _pickLocation() async {
    final result = await context.push<String>(
      '/demand/location',
      extra: {'city': _city, 'address': _location},
    );
    if (result != null && mounted) {
      setState(() => _location = result);
    }
  }

  Future<void> _pickPeopleAndGender() async {
    final tempController = TextEditingController(text: _peopleController.text);
    String tempGender = _gender;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '服务人数及性别',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tempController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '服务人数',
                      hintText: '请输入人数',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '性别要求',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: ['不限', '男', '女'].map((item) {
                      final selected = tempGender == item;
                      return ChoiceChip(
                        label: Text(item),
                        selected: selected,
                        onSelected: (_) =>
                            setModalState(() => tempGender = item),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'people': tempController.text.trim(),
                          'gender': tempGender,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    tempController.dispose();
    if (result != null && mounted) {
      setState(() {
        _peopleController.text = result['people'] ?? '';
        _gender = result['gender'] ?? _gender;
      });
    }
  }

  Future<void> _pickTimeRange() async {
    final now = DateTime.now();
    final startDate = _startAt ?? now.add(const Duration(days: 1));
    DateTime tempStart = _startAt ?? startDate;
    DateTime tempEnd = _endAt ?? startDate.add(const Duration(hours: 4));

    final result = await showModalBottomSheet<Map<String, DateTime>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final dates = List.generate(7, (i) => now.add(Duration(days: i + 1)));
        final startTimes = List.generate(12, (i) => 8 + i);
        final endTimes = List.generate(12, (i) => 9 + i);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '服务时间',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '开始日期',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final date = dates[index];
                        final selected = _isSameDay(tempStart, date);
                        return ChoiceChip(
                          label: Text('${date.month}/${date.day}'),
                          selected: selected,
                          onSelected: (_) => setModalState(() {
                            tempStart = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              tempStart.hour,
                              tempStart.minute,
                            );
                            if (tempEnd.isBefore(tempStart)) {
                              tempEnd = tempStart.add(const Duration(hours: 4));
                            }
                          }),
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemCount: dates.length,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '开始时间',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: startTimes.map((hour) {
                      final selected = tempStart.hour == hour;
                      return ChoiceChip(
                        label: Text('${hour.toString().padLeft(2, '0')}:00'),
                        selected: selected,
                        onSelected: (_) => setModalState(() {
                          tempStart = DateTime(
                            tempStart.year,
                            tempStart.month,
                            tempStart.day,
                            hour,
                            0,
                          );
                          if (tempEnd.isBefore(tempStart)) {
                            tempEnd = tempStart.add(const Duration(hours: 4));
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '结束时间',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: endTimes.map((hour) {
                      final selected =
                          tempEnd.hour == hour &&
                          _isSameDay(tempEnd, tempStart);
                      return ChoiceChip(
                        label: Text('${hour.toString().padLeft(2, '0')}:00'),
                        selected: selected,
                        onSelected: (_) => setModalState(() {
                          tempEnd = DateTime(
                            tempStart.year,
                            tempStart.month,
                            tempStart.day,
                            hour,
                            0,
                          );
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, {
                        'start': tempStart,
                        'end': tempEnd,
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _startAt = result['start'];
        _endAt = result['end'];
      });
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '请选择';
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    return '${dateTime.month}月${dateTime.day}日 周${weekdays[dateTime.weekday - 1]} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final peopleCount = int.tryParse(_peopleController.text.trim()) ?? 0;
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty ||
        _location.isEmpty ||
        _startAt == null ||
        _endAt == null ||
        peopleCount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请把标题、地点、时间和人数补全')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await context.read<DemandProvider>().createDemand(
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        city: _city,
        location: _location,
        serviceStartAt: _startAt!,
        serviceEndAt: _endAt!,
        peopleCount: peopleCount,
        gender: _gender,
        budget: _budgetController.text.trim(),
        tags: _tags.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('需求已发布')));
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发布失败：$e')));
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(title: const Text('发需求'), centerTitle: true),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              _bottomAction(
                Icons.visibility_outlined,
                '预览',
                onTap: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('预览功能后续接入'))),
              ),
              const SizedBox(width: 12),
              _bottomAction(
                Icons.bookmark_border,
                '存草稿',
                onTap: () => ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('草稿功能后续接入'))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            '立即获取报价',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F3F7),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 32,
                            color: AppColors.textHint,
                          ),
                          SizedBox(height: 6),
                          Text(
                            '0/9',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _titleController,
                            maxLength: 20,
                            decoration: const InputDecoration(
                              hintText: '请输入需求标题（20字以内）',
                              counterText: '',
                              border: InputBorder.none,
                            ),
                          ),
                          const Divider(height: 1),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _contentController,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              hintText: '商务活动：苏州工业园区金鸡湖大酒店湖光厅，商户活动出席，需95后女生1名',
                              border: InputBorder.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['文化讲解', '文娱活动', '摄影陪同', '美食陪吃', 'CityWalk'].map((
                    item,
                  ) {
                    final selected = _tags.contains(item);
                    return FilterChip(
                      label: Text(item),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          if (selected) {
                            _tags.remove(item);
                          } else {
                            _tags.add(item);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_contentController.text.length}/50',
                    style: const TextStyle(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                _buildInfoTile(
                  icon: Icons.place_outlined,
                  label: '服务地点：',
                  value: _location.isEmpty ? '请选择服务地点' : _location,
                  trailing: _buildCityChip(),
                  onTap: _pickLocation,
                ),
                const Divider(height: 24),
                _buildInfoTile(
                  icon: Icons.schedule_outlined,
                  label: '服务时间：',
                  value: _startAt == null || _endAt == null
                      ? '请选择服务时间'
                      : '${_formatDateTime(_startAt)} - ${_formatDateTime(_endAt)}',
                  onTap: _pickTimeRange,
                ),
                const Divider(height: 24),
                _buildInfoTile(
                  icon: Icons.sentiment_satisfied_alt_outlined,
                  label: '服务人数及性别：',
                  value: _peopleController.text.isEmpty
                      ? '请输入人数'
                      : '${_peopleController.text}人 / $_gender',
                  onTap: _pickPeopleAndGender,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: AppColors.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '本服务由**保险全程保障您的人身财产安全',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _budgetController,
            decoration: const InputDecoration(
              labelText: '预算（可选）',
              hintText: '例如：300-500',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityChip() {
    return InkWell(
      onTap: _pickCity,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.tagBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _city,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              size: 18,
              color: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing,
          ] else
            const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
    );
  }

  Widget _bottomAction(
    IconData icon,
    String label, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.tagBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}
