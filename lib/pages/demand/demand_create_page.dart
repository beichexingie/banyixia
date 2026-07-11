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
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  final TextEditingController _peopleController = TextEditingController();

  String _city = '苏州';
  String _location = '';
  double? _serviceLat;
  double? _serviceLng;
  DateTime? _startAt;
  DateTime? _endAt;
  String _gender = '不限';
  final Set<String> _tags = {'休闲游玩'};
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
    final result = await context.push<Map<String, dynamic>>(
      '/demand/location',
      extra: {'city': _city, 'address': _location.isEmpty ? _city : _location},
    );
    if (result == null || !mounted) {
      return;
    }

    final city = _normalizeCityName(result['city']?.toString());
    if (city.isEmpty) {
      return;
    }

    setState(() {
      _city = city;
      if (_location.isEmpty) {
        _location =
            result['summary']?.toString() ??
            result['address']?.toString() ??
            _location;
      }
      _serviceLat = (result['latitude'] as num?)?.toDouble();
      _serviceLng = (result['longitude'] as num?)?.toDouble();
    });
  }

  Future<void> _pickLocation() async {
    final result = await context.push<Map<String, dynamic>>(
      '/demand/location',
      extra: {'city': _city, 'address': _location},
    );
    if (result == null || !mounted) {
      return;
    }

    setState(() {
      final normalized = _normalizeCityName(result['city']?.toString());
      if (normalized.isNotEmpty) {
        _city = normalized;
      }
      _location =
          result['summary']?.toString() ??
          result['address']?.toString() ??
          _location;
      _serviceLat = (result['latitude'] as num?)?.toDouble();
      _serviceLng = (result['longitude'] as num?)?.toDouble();
    });
  }

  Future<void> _pickPeopleAndGender() async {
    final peopleController = TextEditingController(
      text: _peopleController.text,
    );
    String tempGender = _gender;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                16,
                18,
                18 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '服务人数及性别',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _modalLabel('人数'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: peopleController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: '请输入服务人数',
                      filled: true,
                      fillColor: const Color(0xFFF6F6F0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _modalLabel('性别'),
                  const SizedBox(height: 10),
                  Row(
                    children: ['男', '女', '不限'].map((item) {
                      final selected = tempGender == item;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () => setModalState(() => tempGender = item),
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : const Color(0xFFF6F6F0),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'people': peopleController.text.trim(),
                          'gender': tempGender,
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text(
                        '确认',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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
        _peopleController.text = result['people'] ?? '';
        _gender = result['gender'] ?? _gender;
      });
    }
  }

  Future<void> _pickTimeRange() async {
    final now = DateTime.now();
    final initialDate = _startAt ?? now.add(const Duration(days: 1));
    DateTime selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    DateTime? tempStart = _startAt;
    DateTime? tempEnd = _endAt;
    const minHours = 3;
    final hours = List.generate(18, (i) => 6 + i);

    final result = await showModalBottomSheet<Map<String, DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final dates = List.generate(5, (i) => now.add(Duration(days: i)));

        bool disabledHour(int hour) {
          return _isSameDay(selectedDate, now) && hour <= now.hour;
        }

        DateTime atHour(DateTime date, int hour) {
          return DateTime(date.year, date.month, date.day, hour);
        }

        String dateTitle(DateTime date, int index) {
          if (index == 0) return '今天';
          if (index == 1) return '明天';
          const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
          return weekdays[date.weekday - 1];
        }

        int selectedHours() {
          if (tempStart == null || tempEnd == null) return 0;
          return tempEnd!.difference(tempStart!).inHours;
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalHours = selectedHours();
            final canConfirm = totalHours >= minHours;

            return FractionallySizedBox(
              heightFactor: 0.84,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD9D9D9),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '预约服务时间',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        const Text(
                          '具体开始时间会通过电话联系和您确认',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 88,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: dates.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final date = dates[index];
                              final selected = _isSameDay(selectedDate, date);
                              return GestureDetector(
                                onTap: () => setModalState(() {
                                  selectedDate = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                  );
                                  tempStart = null;
                                  tempEnd = null;
                                }),
                                child: Container(
                                  width: 84,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.primary
                                        : const Color(0xFFF6F6F0),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        dateTitle(date, index),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: selected
                                              ? AppColors.textPrimary
                                              : AppColors.textHint,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          '预约时间段',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '平台预约服务时间默认 3 小时起订',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: GridView.builder(
                            itemCount: hours.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 4,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                  childAspectRatio: 1.55,
                                ),
                            itemBuilder: (context, index) {
                              final hour = hours[index];
                              final disabled = disabledHour(hour);
                              final time = atHour(selectedDate, hour);

                              final isStart =
                                  tempStart != null &&
                                  _isSameDay(tempStart!, selectedDate) &&
                                  tempStart!.hour == hour;
                              final isEnd =
                                  tempEnd != null &&
                                  _isSameDay(tempEnd!, selectedDate) &&
                                  tempEnd!.hour == hour;
                              final inRange =
                                  tempStart != null &&
                                  tempEnd != null &&
                                  time.isAfter(tempStart!) &&
                                  time.isBefore(tempEnd!);

                              final active = isStart || isEnd;

                              return GestureDetector(
                                onTap: disabled
                                    ? null
                                    : () {
                                        setModalState(() {
                                          if (tempStart == null ||
                                              (tempStart != null &&
                                                  tempEnd != null)) {
                                            tempStart = atHour(
                                              selectedDate,
                                              hour,
                                            );
                                            tempEnd = null;
                                            return;
                                          }
                                          final candidate = atHour(
                                            selectedDate,
                                            hour,
                                          );
                                          if (!candidate.isAfter(tempStart!)) {
                                            tempStart = candidate;
                                            tempEnd = null;
                                            return;
                                          }
                                          if (candidate
                                                  .difference(tempStart!)
                                                  .inHours <
                                              minHours) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('至少选择 3 小时'),
                                              ),
                                            );
                                            return;
                                          }
                                          tempEnd = candidate;
                                        });
                                      },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.primary
                                        : inRange
                                        ? const Color(0xFFF0F6DA)
                                        : const Color(0xFFF8F8F3),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${hour.toString().padLeft(2, '0')}:00',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: disabled
                                              ? const Color(0xFFCFCFCF)
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isStart
                                            ? '开始'
                                            : isEnd
                                            ? '结束'
                                            : (disabled ? '约满' : '可约'),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: disabled
                                              ? const Color(0xFFCFCFCF)
                                              : (active
                                                    ? AppColors.textPrimary
                                                    : AppColors.textHint),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: canConfirm
                                ? () => Navigator.pop(context, {
                                    'start': tempStart!,
                                    'end': tempEnd!,
                                  })
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.textPrimary,
                              disabledBackgroundColor: const Color(0xFFE5E5E5),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                            child: Text(
                              canConfirm
                                  ? '共计 ${totalHours}h 确定'
                                  : '请选择至少 3 小时',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
        serviceLat: _serviceLat,
        serviceLng: _serviceLng,
        serviceStartAt: _startAt!,
        serviceEndAt: _endAt!,
        peopleCount: peopleCount,
        gender: _gender,
        budget: _budgetController.text.trim(),
        tags: _tags.toList(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('需求已发布')));
      context.go('/demands/me');
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('发布失败：$e')));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _saveDraft() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('草稿功能稍后接入')));
  }

  void _showPreview() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        final timeText = _startAt == null || _endAt == null
            ? '暂未选择'
            : '${_formatMoment(_startAt!)} - ${_formatMoment(_endAt!)}';
        final peopleText = _peopleController.text.trim().isEmpty
            ? '暂未填写'
            : '${_peopleController.text.trim()}人 · $_gender';

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '需求预览',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _titleController.text.trim().isEmpty
                      ? '未填写标题'
                      : _titleController.text.trim(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                _previewRow('城市', _city),
                _previewRow('地点', _location.isEmpty ? '暂未选择' : _location),
                _previewRow('时间', timeText),
                _previewRow('人数', peopleText),
                _previewRow(
                  '预算',
                  _budgetController.text.trim().isEmpty
                      ? '未填写'
                      : _budgetController.text.trim(),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F7F2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    _contentController.text.trim().isEmpty
                        ? '未填写内容'
                        : _contentController.text.trim(),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.65,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _previewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textHint),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '服务地点',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  _buildMainCard(),
                  const SizedBox(height: 12),
                  _buildInfoCard(),
                  const SizedBox(height: 12),
                  _buildSafetyCard(),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _bottomAction(
                    Icons.remove_red_eye_outlined,
                    '预览',
                    onTap: _showPreview,
                  ),
                  const SizedBox(width: 20),
                  _bottomAction(
                    Icons.drafts_outlined,
                    '存草稿',
                    onTap: _saveDraft,
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 184,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textPrimary,
                              ),
                            )
                          : const Text(
                              '立即发布',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard() {
    final tags = [
      ('休闲游玩', Icons.local_activity_outlined),
      ('商务陪同', Icons.person_outline),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F5EF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.add,
                        size: 22,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '添加图片',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD2D2D2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              const Padding(
                padding: EdgeInsets.only(top: 84),
                child: Text(
                  '0/9',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _titleController,
            maxLength: 20,
            decoration: const InputDecoration(
              hintText: '请输入活动标题（20字以内）',
              hintStyle: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFFD2D2D2),
              ),
              counterText: '',
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 172,
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText:
                    '请编辑您的活动内容(如「苏州工业园区金鸡湖大酒店湖光厅，商户活动出席，需要95后女生1名」仅限平台沟通勿留私人联系方式，安全自负。)',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Color(0xFFD2D2D2),
                  height: 1.65,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.65,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: tags.map((item) {
              final selected = _tags.contains(item.$1);
              return _buildTagChip(
                label: item.$1,
                icon: item.$2,
                selected: selected,
                onTap: () {
                  setState(() {
                    if (selected) {
                      _tags.remove(item.$1);
                    } else {
                      _tags.add(item.$1);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          _buildInfoTile(
            icon: Icons.place_outlined,
            label: '服务地点',
            value: _location.isEmpty ? '请选择服务地点' : _location,
            onTap: _pickLocation,
          ),
          const Divider(height: 20, thickness: 1, color: Color(0xFFF2F2F2)),
          _buildInfoTile(
            icon: Icons.schedule_outlined,
            label: '服务时间',
            value: _startAt == null || _endAt == null
                ? '请选择服务时间'
                : '${_formatMoment(_startAt!)} - ${_formatMoment(_endAt!)}',
            onTap: _pickTimeRange,
          ),
          const Divider(height: 20, thickness: 1, color: Color(0xFFF2F2F2)),
          _buildInfoTile(
            icon: Icons.people_alt_outlined,
            label: '服务人数及性别',
            value: _peopleController.text.isEmpty
                ? '请输入服务人数'
                : '${_peopleController.text}人·$_gender',
            onTap: _pickPeopleAndGender,
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAF1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined, color: Color(0xFFFFA24A)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '本服务由平台合作保险全程保障您的人身财产安全',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFA24A),
              ),
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.primaryDeep),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildTagChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : const Color(0xFFF5F5EF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
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
          Icon(icon, color: AppColors.textHint, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _modalLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  String _normalizeCityName(String? raw) {
    final city = (raw ?? '').trim();
    if (city.isEmpty) {
      return '';
    }

    const suffixes = ['特别行政区', '自治区', '自治州', '自治县', '地区', '盟', '市'];
    for (final suffix in suffixes) {
      if (city.endsWith(suffix) && city.length > suffix.length) {
        return city.substring(0, city.length - suffix.length);
      }
    }
    return city;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatMoment(DateTime dateTime) {
    const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${dateTime.year}.${dateTime.month}.${dateTime.day} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} ${weekdays[dateTime.weekday - 1]}';
  }
}
