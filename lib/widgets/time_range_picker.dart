import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class TimeRangeSelection {
  final DateTime start;
  final DateTime end;

  const TimeRangeSelection({required this.start, required this.end});

  int get hours => end.difference(start).inHours;
}

Future<TimeRangeSelection?> showAppTimeRangePicker(
  BuildContext context, {
  DateTime? initialStart,
  DateTime? initialEnd,
  DateTime? firstDate,
  int dateCount = 90,
  int minHours = 1,
  String title = '选择服务时间',
  String subtitle = '按住时间格并拖动，可连续选择开始到结束时间',
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
  int? _dragStart;
  int? _dragEnd;

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

  void _selectIndex(int index) {
    if (index < 0 || index >= _hours.length) return;
    final hour = _hours[index];
    if (!_available(hour)) return;
    final candidate = _atHour(hour);
    setState(() {
      _start = candidate;
      _end = null;
      _dragStart = index;
      _dragEnd = index;
    });
  }

  void _updateIndex(int index) {
    if (_dragStart == null || index < 0 || index >= _hours.length) return;
    final low = _dragStart! <= index ? _dragStart! : index;
    final high = _dragStart! <= index ? index : _dragStart!;
    if (!_hours.sublist(low, high + 1).every(_available)) return;
    setState(() {
      _dragEnd = index;
      final startHour = _hours[low];
      final endHour = _hours[high] + 1;
      _start = _atHour(startHour);
      _end = _atHour(endHour);
    });
  }

  void _finishDrag() {
    if (_dragStart == null || _dragEnd == null) return;
    final low = _dragStart! <= _dragEnd! ? _dragStart! : _dragEnd!;
    final high = _dragStart! <= _dragEnd! ? _dragEnd! : _dragStart!;
    final start = _atHour(_hours[low]);
    final end = _atHour(_hours[high] + 1);
    if (end.difference(start).inHours < widget.minHours) {
      setState(() {
        _start = start;
        _end = null;
      });
    }
    _dragStart = null;
    _dragEnd = null;
  }

  int? _indexFromPosition(Offset position, double width) {
    const columns = 4;
    const gap = 10.0;
    const cellHeight = 62.0;
    final cellWidth = (width - gap * (columns - 1)) / columns;
    final column = (position.dx / (cellWidth + gap)).floor();
    final row = (position.dy / (cellHeight + gap)).floor();
    if (column < 0 || column >= columns || row < 0) return null;
    final localX = position.dx - column * (cellWidth + gap);
    final localY = position.dy - row * (cellHeight + gap);
    if (localX > cellWidth || localY > cellHeight) return null;
    final index = row * columns + column;
    return index < _hours.length ? index : null;
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
                  '至少选择 ${widget.minHours} 小时，灰色时间不可选择',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (details) {
                          final index = _indexFromPosition(
                            details.localPosition,
                            constraints.maxWidth,
                          );
                          if (index != null) _selectIndex(index);
                        },
                        onPanUpdate: (details) {
                          final index = _indexFromPosition(
                            details.localPosition,
                            constraints.maxWidth,
                          );
                          if (index != null) _updateIndex(index);
                        },
                        onPanEnd: (_) => _finishDrag(),
                        onTapUp: (details) {
                          final index = _indexFromPosition(
                            details.localPosition,
                            constraints.maxWidth,
                          );
                          if (index == null || !_available(_hours[index]))
                            return;
                          setState(() {
                            final candidate = _atHour(_hours[index]);
                            if (_start == null || _end != null) {
                              _start = candidate;
                              _end = null;
                            } else if (candidate.isAfter(_start!)) {
                              final low = _hours.indexOf(_start!.hour);
                              final high = index;
                              if (low >= 0 &&
                                  high >= low &&
                                  _hours
                                      .sublist(low, high + 1)
                                      .every(_available)) {
                                _end = _atHour(_hours[high] + 1);
                              }
                            } else {
                              _start = candidate;
                              _end = null;
                            }
                          });
                        },
                        child: GridView.builder(
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
                            return Container(
                              decoration: BoxDecoration(
                                color: !available
                                    ? const Color(0xFFE9E9E9)
                                    : active
                                    ? AppColors.primary
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
                                      color: available
                                          ? AppColors.textPrimary
                                          : const Color(0xFFB8B8B8),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    !available
                                        ? '不可用'
                                        : active
                                        ? '已选'
                                        : '可选',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: available
                                          ? AppColors.textHint
                                          : const Color(0xFFB8B8B8),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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
