import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class TimeRangeSelection {
  final DateTime start;
  final DateTime end;

  const TimeRangeSelection({required this.start, required this.end});

  int get hours => end.difference(start).inMinutes ~/ 60;
}

Future<TimeRangeSelection?> showAppTimeRangePicker(
  BuildContext context, {
  DateTime? initialStart,
  DateTime? initialEnd,
  DateTime? firstDate,
  int dateCount = 90,
  int minHours = 1,
  String title = '选择服务时间',
  String subtitle = '点击开始时间，再点击结束时间',
  bool Function(DateTime slot)? isSlotAvailable,
}) {
  final now = DateTime.now();
  final start = initialStart ?? now.add(const Duration(days: 1));
  return showModalBottomSheet<TimeRangeSelection>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TimeRangeSheet(
      initialStart: start,
      initialEnd: initialEnd,
      firstDate: firstDate ?? DateTime(now.year, now.month, now.day),
      dateCount: dateCount,
      minHours: minHours,
      title: title,
      subtitle: subtitle,
      isSlotAvailable: isSlotAvailable,
    ),
  );
}

class _TimeRangeSheet extends StatefulWidget {
  final DateTime initialStart;
  final DateTime? initialEnd;
  final DateTime firstDate;
  final int dateCount;
  final int minHours;
  final String title;
  final String subtitle;
  final bool Function(DateTime slot)? isSlotAvailable;

  const _TimeRangeSheet({
    required this.initialStart,
    required this.initialEnd,
    required this.firstDate,
    required this.dateCount,
    required this.minHours,
    required this.title,
    required this.subtitle,
    required this.isSlotAvailable,
  });

  @override
  State<_TimeRangeSheet> createState() => _TimeRangeSheetState();
}

class _TimeRangeSheetState extends State<_TimeRangeSheet> {
  late DateTime _selectedDate;
  DateTime? _start;
  DateTime? _end;
  int? _pressedIndex;

  final List<int> _hours = List<int>.generate(17, (index) => index + 6);

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(
      widget.initialStart.year,
      widget.initialStart.month,
      widget.initialStart.day,
    );
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _atHour(int hour) => DateTime(
    _selectedDate.year,
    _selectedDate.month,
    _selectedDate.day,
    hour,
  );

  bool _available(int hour) {
    final slot = _atHour(hour);
    if (_sameDay(slot, DateTime.now()) && slot.isBefore(DateTime.now())) {
      return false;
    }
    return widget.isSlotAvailable?.call(slot) ?? true;
  }

  bool _rangeAvailable(DateTime start, DateTime end) {
    if (!end.isAfter(start)) return false;
    for (
      var slot = start;
      slot.isBefore(end);
      slot = slot.add(const Duration(hours: 1))
    ) {
      if (!_available(slot.hour)) return false;
    }
    return true;
  }

  bool _sameHour(DateTime? value, int hour) {
    return value != null &&
        value.year == _selectedDate.year &&
        value.month == _selectedDate.month &&
        value.day == _selectedDate.day &&
        value.hour == hour;
  }

  String _timeText(DateTime? value) {
    if (value == null) return '未选择';
    return '${value.hour.toString().padLeft(2, '0')}:00';
  }

  void _handleHourTap(int index) {
    if (index < 0 || index >= _hours.length) return;
    final candidate = _atHour(_hours[index]);
    if (_start == null || _end != null) {
      if (!_available(_hours[index])) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('这个时间段当前不可选择')));
        return;
      }
      setState(() {
        _start = candidate;
        _end = null;
      });
      return;
    }

    if (candidate.isAfter(_start!)) {
      if (!_rangeAvailable(_start!, candidate)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('所选时间段包含不可用时间，请重新选择')));
        return;
      }
      setState(() => _end = candidate);
      return;
    }

    if (_available(_hours[index])) {
      setState(() {
        _start = candidate;
        _end = null;
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('这个时间段当前不可选择')));
    }
  }

  bool _isInRange(int index) {
    if (_start == null || _end == null) return false;
    final slot = _atHour(_hours[index]);
    return !slot.isBefore(_start!) && slot.isBefore(_end!);
  }

  @override
  Widget build(BuildContext context) {
    final dates = List<DateTime>.generate(
      widget.dateCount,
      (index) => widget.firstDate.add(Duration(days: index)),
    );
    final hours = _start != null && _end != null
        ? _end!.difference(_start!).inHours
        : 0;
    final canConfirm = hours >= widget.minHours;

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
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
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
                Text(
                  widget.subtitle,
                  style: const TextStyle(
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
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (_, index) {
                      final date = dates[index];
                      final selected = _sameDay(_selectedDate, date);
                      final label = index == 0
                          ? '今天'
                          : index == 1
                          ? '明天'
                          : <String>[
                              '周一',
                              '周二',
                              '周三',
                              '周四',
                              '周五',
                              '周六',
                              '周日',
                            ][date.weekday - 1];
                      return GestureDetector(
                        onTap: () => setState(() {
                          _selectedDate = DateTime(
                            date.year,
                            date.month,
                            date.day,
                          );
                          _start = null;
                          _end = null;
                        }),
                        child: Container(
                          width: 84,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary
                                : const Color(0xFFF6F6F0),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
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
                const SizedBox(height: 22),
                const Text(
                  '选择时间段',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  _start == null
                      ? '请点击开始时间，灰色时间不可选择'
                      : _end == null
                      ? '已选开始 ${_timeText(_start)}，请点击结束时间'
                      : '已选 ${_timeText(_start)} - ${_timeText(_end)}，可重新点击调整',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _hours.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              mainAxisExtent: 62,
                            ),
                        itemBuilder: (_, index) {
                          final hour = _hours[index];
                          final available = _available(hour);
                          final active = _isInRange(index);
                          final isStart = _sameHour(_start, hour);
                          final isEnd = _sameHour(_end, hour);
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTapDown: (_) =>
                                  setState(() => _pressedIndex = index),
                              onTapCancel: () =>
                                  setState(() => _pressedIndex = null),
                              onTap: () {
                                _handleHourTap(index);
                                if (mounted) {
                                  setState(() => _pressedIndex = null);
                                }
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: AnimatedScale(
                                scale: _pressedIndex == index ? 0.94 : 1,
                                duration: const Duration(milliseconds: 90),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  decoration: BoxDecoration(
                                    color: !available
                                        ? const Color(0xFFE9E9E9)
                                        : isStart || isEnd
                                        ? AppColors.primaryDark
                                        : active
                                        ? AppColors.primary
                                        : const Color(0xFFF8F8F3),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: isStart || isEnd
                                        ? const [
                                            BoxShadow(
                                              color: Color(0x553E5E00),
                                              blurRadius: 8,
                                              offset: Offset(0, 3),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${hour.toString().padLeft(2, '0')}:00',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: isStart || isEnd
                                              ? Colors.white
                                              : available
                                              ? AppColors.textPrimary
                                              : const Color(0xFFB8B8B8),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        !available
                                            ? '不可用'
                                            : isStart
                                            ? '开始'
                                            : isEnd
                                            ? '结束'
                                            : active
                                            ? '已选'
                                            : '可选',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isStart || isEnd
                                              ? Colors.white
                                              : available
                                              ? AppColors.textHint
                                              : const Color(0xFFB8B8B8),
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
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: canConfirm
                        ? () => Navigator.pop(
                            context,
                            TimeRangeSelection(start: _start!, end: _end!),
                          )
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
                          ? '共计 ${hours}h 确定'
                          : '请选择至少 ${widget.minHours} 小时',
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
  }
}
