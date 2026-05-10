import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/demand_provider.dart';
import '../order/location_picker_page.dart';

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

  Future<void> _pickLocationApiReady() async {
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
    final initialDate = _startAt ?? now.add(const Duration(days: 1));
    DateTime selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    DateTime? tempStart = _startAt;
    DateTime? tempEnd = _endAt;

    if (tempStart == null || !_isSameDay(tempStart, selectedDate)) {
      tempStart = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        11,
      );
      tempEnd = tempStart.add(const Duration(hours: 3));
    }

    final result = await showModalBottomSheet<Map<String, DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final dates = List.generate(5, (i) => now.add(Duration(days: i)));
        final hours = List.generate(18, (i) => 6 + i);
        const minHours = 3;

        DateTime atHour(DateTime date, int hour) {
          return DateTime(date.year, date.month, date.day, hour);
        }

        int selectedHours() {
          if (tempStart == null || tempEnd == null) return 0;
          return tempEnd!.difference(tempStart!).inHours;
        }

        bool disabledHour(int hour) {
          return _isSameDay(selectedDate, now) && hour <= now.hour;
        }

        String dateTitle(DateTime date, int index) {
          if (index == 0) return '今天';
          if (index == 1) return '明天';
          const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
          return weekdays[date.weekday - 1];
        }

        void selectHour(int hour, void Function(void Function()) setModalState) {
          if (disabledHour(hour)) return;
          final picked = atHour(selectedDate, hour);
          setModalState(() {
            if (tempStart == null ||
                tempEnd != null ||
                !picked.isAfter(tempStart!)) {
              tempStart = picked;
              tempEnd = null;
              return;
            }
            if (picked.difference(tempStart!).inHours < minHours) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('平台预定服务时间默认 3 小时起订')),
              );
              return;
            }
            tempEnd = picked;
          });
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalHours = selectedHours();
            final canConfirm = totalHours >= minHours;

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF8F7FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    18,
                    18,
                    MediaQuery.of(context).viewInsets.bottom + 18,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '预约时间',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                      const Text(
                        '具体开始时间地陪服务将通过电话联系和您确认',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 86,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
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
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 92,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFFC8F26D)
                                      : Colors.white.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected
                                        ? const Color(0xFFC8F26D)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      dateTitle(date, index),
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                        color: selected
                                            ? AppColors.textPrimary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w400,
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
                          separatorBuilder: (_, _) => const SizedBox(width: 10),
                          itemCount: dates.length,
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        '预约时间段',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '平台预定服务时间默认 3 小时起订',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: hours.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.25,
                        ),
                        itemBuilder: (context, index) {
                          final hour = hours[index];
                          final time = atHour(selectedDate, hour);
                          final disabled = disabledHour(hour);
                          final isStart = tempStart != null &&
                              _isSameDay(tempStart!, selectedDate) &&
                              tempStart!.hour == hour;
                          final isEnd = tempEnd != null &&
                              _isSameDay(tempEnd!, selectedDate) &&
                              tempEnd!.hour == hour;
                          final inRange = tempStart != null &&
                              tempEnd != null &&
                              time.isAfter(tempStart!) &&
                              time.isBefore(tempEnd!);
                          final highlighted = isStart || isEnd;
                          final night = hour >= 20;

                          return GestureDetector(
                            onTap: () => selectHour(hour, setModalState),
                            onLongPress: () => selectHour(hour, setModalState),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              decoration: BoxDecoration(
                                color: highlighted
                                    ? const Color(0xFFC8F26D)
                                    : inRange
                                        ? const Color(0xFFF0F6DA)
                                        : disabled
                                            ? const Color(0xFFF4F3F8)
                                            : Colors.white.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: highlighted
                                      ? const Color(0xFFC8F26D)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  if (night)
                                    const Positioned(
                                      top: 5,
                                      left: 8,
                                      child: Text(
                                        '夜间',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFFC78F3A),
                                        ),
                                      ),
                                    ),
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${hour.toString().padLeft(2, '0')}:00',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: highlighted
                                                ? FontWeight.w800
                                                : FontWeight.w500,
                                            color: disabled
                                                ? const Color(0xFFC9C7D1)
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isStart
                                              ? '开始'
                                              : isEnd
                                                  ? '结束'
                                                  : '空闲',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: disabled
                                                ? const Color(0xFFD5D2DC)
                                                : highlighted
                                                    ? AppColors.textPrimary
                                                    : AppColors.textHint,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
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
                            backgroundColor: const Color(0xFF242934),
                            disabledBackgroundColor: const Color(0xFFB6B8C1),
                            foregroundColor: const Color(0xFFC8F26D),
                            disabledForegroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            canConfirm ? '共计${totalHours}h 确定' : '请选择至少3小时',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
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

  Future<void> _pickTimeRangeV2() async {
    final now = DateTime.now();
    final initialDate = _startAt ?? now.add(const Duration(days: 1));
    const minHours = 3;
    const startHour = 6;
    const endHour = 23;
    const crossAxisCount = 4;
    const crossAxisSpacing = 12.0;
    const mainAxisSpacing = 12.0;
    const childAspectRatio = 2.2;

    DateTime selectedDate = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    DateTime? tempStart = _startAt;
    DateTime? tempEnd = _endAt;
    int? dragOriginHour;

    DateTime atHour(DateTime date, int hour) =>
        DateTime(date.year, date.month, date.day, hour);

    bool isDisabledHour(int hour) =>
        _isSameDay(selectedDate, now) && hour <= now.hour;

    String weekdayLabel(DateTime date) {
      const weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return weekdays[date.weekday - 1];
    }

    void setRange(int startHourValue, int endHourValue) {
      final rangeStart = startHourValue <= endHourValue
          ? startHourValue
          : endHourValue;
      final rangeEnd = startHourValue <= endHourValue
          ? endHourValue
          : startHourValue;
      tempStart = atHour(selectedDate, rangeStart);
      tempEnd = atHour(selectedDate, rangeEnd);
    }

    int? hourFromPosition(Offset position, BoxConstraints constraints) {
      final cellWidth =
          (constraints.maxWidth - crossAxisSpacing * (crossAxisCount - 1)) /
              crossAxisCount;
      final cellHeight = cellWidth / childAspectRatio;
      final rows = ((endHour - startHour + 1) + crossAxisCount - 1) ~/
          crossAxisCount;
      final blockWidth = cellWidth + crossAxisSpacing;
      final blockHeight = cellHeight + mainAxisSpacing;
      final col = (position.dx / blockWidth).floor();
      final row = (position.dy / blockHeight).floor();
      if (col < 0 || col >= crossAxisCount || row < 0 || row >= rows) {
        return null;
      }
      final withinX = position.dx - col * blockWidth;
      final withinY = position.dy - row * blockHeight;
      if (withinX > cellWidth || withinY > cellHeight) return null;
      final hour = startHour + row * crossAxisCount + col;
      if (hour < startHour || hour > endHour) return null;
      return hour;
    }

    final result = await showModalBottomSheet<Map<String, DateTime>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final dates = List.generate(5, (i) => now.add(Duration(days: i)));
        final hours = List.generate(endHour - startHour + 1, (i) => startHour + i);

        int selectedHours() {
          if (tempStart == null || tempEnd == null) return 0;
          return tempEnd!.difference(tempStart!).inHours;
        }

        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalHours = selectedHours();
            final canConfirm = totalHours >= minHours;
            final summaryText = tempStart != null && tempEnd != null
                ? '${tempStart!.hour.toString().padLeft(2, '0')}:00 - ${tempEnd!.hour.toString().padLeft(2, '0')}:00'
                : '拖动选择开始和结束时间';

            return FractionallySizedBox(
              heightFactor: 0.88,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F7FF),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      18,
                      14,
                      18,
                      MediaQuery.of(context).viewInsets.bottom + 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 44,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFF5A5D6A),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                '服务时间',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                        const Text(
                          '先选日期，再在下方拖动时间块选择时长',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          height: 84,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: dates.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
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
                                  dragOriginHour = null;
                                }),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 92,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFC8F26D)
                                        : Colors.white.withValues(alpha: 0.58),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFFC8F26D)
                                          : const Color(0xFFD5D8E2),
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        index == 0
                                            ? '今天'
                                            : index == 1
                                                ? '明天'
                                                : weekdayLabel(date),
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: selected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          color: selected
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: selected
                                              ? FontWeight.w700
                                              : FontWeight.w400,
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
                        const SizedBox(height: 20),
                        const Text(
                          '预约时间段',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '平台默认最少 3 小时起订',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: SingleChildScrollView(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final cellWidth =
                                    (constraints.maxWidth -
                                            crossAxisSpacing *
                                                (crossAxisCount - 1)) /
                                        crossAxisCount;
                                final cellHeight = cellWidth / childAspectRatio;
                                final rows =
                                    (hours.length + crossAxisCount - 1) ~/
                                        crossAxisCount;
                                final gridHeight = rows * cellHeight +
                                    (rows - 1) * mainAxisSpacing;

                                return SizedBox(
                                  height: gridHeight,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTapDown: (details) {
                                      final hour = hourFromPosition(
                                        details.localPosition,
                                        constraints,
                                      );
                                      if (hour == null || isDisabledHour(hour)) {
                                        return;
                                      }
                                      setModalState(() {
                                        if (tempStart == null ||
                                            tempEnd != null) {
                                          tempStart = atHour(selectedDate, hour);
                                          tempEnd = null;
                                          dragOriginHour = hour;
                                          return;
                                        }
                                        if (hour == tempStart!.hour) {
                                          tempEnd = null;
                                          dragOriginHour = hour;
                                          return;
                                        }
                                        setRange(tempStart!.hour, hour);
                                        dragOriginHour = tempStart!.hour;
                                      });
                                    },
                                    onPanStart: (details) {
                                      final hour = hourFromPosition(
                                        details.localPosition,
                                        constraints,
                                      );
                                      if (hour == null || isDisabledHour(hour)) {
                                        return;
                                      }
                                      setModalState(() {
                                        tempStart = atHour(selectedDate, hour);
                                        tempEnd = null;
                                        dragOriginHour = hour;
                                      });
                                    },
                                    onPanUpdate: (details) {
                                      final origin = dragOriginHour;
                                      if (origin == null) return;
                                      final hour = hourFromPosition(
                                        details.localPosition,
                                        constraints,
                                      );
                                      if (hour == null || isDisabledHour(hour)) {
                                        return;
                                      }
                                      setModalState(() {
                                        setRange(origin, hour);
                                      });
                                    },
                                    onPanEnd: (_) => dragOriginHour = null,
                                    child: GridView.builder(
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      itemCount: hours.length,
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        mainAxisSpacing: mainAxisSpacing,
                                        crossAxisSpacing: crossAxisSpacing,
                                        childAspectRatio: childAspectRatio,
                                      ),
                                      itemBuilder: (context, index) {
                                        final hour = hours[index];
                                        final time = atHour(selectedDate, hour);
                                        final disabled = isDisabledHour(hour);
                                        final isStart = tempStart != null &&
                                            _isSameDay(tempStart!, selectedDate) &&
                                            tempStart!.hour == hour;
                                        final isEnd = tempEnd != null &&
                                            _isSameDay(tempEnd!, selectedDate) &&
                                            tempEnd!.hour == hour;
                                        final inRange = tempStart != null &&
                                            tempEnd != null &&
                                            time.isAfter(tempStart!) &&
                                            time.isBefore(tempEnd!);
                                        final highlighted = isStart || isEnd;
                                        final night = hour >= 20;

                                        return AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 150),
                                          decoration: BoxDecoration(
                                            color: highlighted
                                                ? const Color(0xFFC8F26D)
                                                : inRange
                                                    ? const Color(0xFFF0F6DA)
                                                    : disabled
                                                        ? const Color(0xFFF4F3F8)
                                                        : Colors.white.withValues(
                                                            alpha: 0.82,
                                                          ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: highlighted
                                                  ? const Color(0xFFC8F26D)
                                                  : const Color(0xFFD5D8E2),
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              if (night)
                                                const Positioned(
                                                  top: 5,
                                                  left: 8,
                                                  child: Text(
                                                    '夜间',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFFC78F3A),
                                                    ),
                                                  ),
                                                ),
                                              Center(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      '${hour.toString().padLeft(2, '0')}:00',
                                                      style: TextStyle(
                                                        fontSize: 17,
                                                        fontWeight: highlighted
                                                            ? FontWeight.w800
                                                            : FontWeight.w500,
                                                        color: disabled
                                                            ? const Color(
                                                                0xFFC9C7D1,
                                                              )
                                                            : AppColors
                                                                .textPrimary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      isStart
                                                          ? '开始'
                                                          : isEnd
                                                              ? '结束'
                                                              : '可选',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: disabled
                                                            ? const Color(
                                                                0xFFD5D2DC,
                                                              )
                                                            : highlighted
                                                                ? AppColors
                                                                    .textPrimary
                                                                : AppColors
                                                                    .textHint,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  summaryText,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                totalHours > 0 ? '共计 ${totalHours}h' : '请选择时长',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: totalHours > 0
                                      ? AppColors.primary
                                      : AppColors.textHint,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
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
                              backgroundColor: const Color(0xFF242934),
                              disabledBackgroundColor: const Color(0xFFB6B8C1),
                              foregroundColor: const Color(0xFFC8F26D),
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              canConfirm
                                  ? '共计 ${totalHours}h 确定'
                                  : '请选择至少 ${minHours} 小时',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
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
                  onTap: _pickLocationApiReady,
                ),
                const Divider(height: 24),
                _buildInfoTile(
                  icon: Icons.schedule_outlined,
                  label: '服务时间：',
                  value: _startAt == null || _endAt == null
                      ? '请选择服务时间'
                      : '${_formatDateTime(_startAt)} - ${_formatDateTime(_endAt)}',
                  onTap: _pickTimeRangeV2,
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
