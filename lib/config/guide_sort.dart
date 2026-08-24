import '../models/guide.dart';

enum GuideSortMode { hot, time, distance }

extension GuideSortModeLabel on GuideSortMode {
  String get label => switch (this) {
    GuideSortMode.hot => '热门排序',
    GuideSortMode.time => '最近可约',
    GuideSortMode.distance => '距离排序',
  };
}

int compareGuides(Guide a, Guide b, GuideSortMode mode) {
  switch (mode) {
    case GuideSortMode.hot:
      final score = (b.likes + b.fans + b.views).compareTo(
        a.likes + a.fans + a.views,
      );
      if (score != 0) return score;
      return b.rating.compareTo(a.rating);
    case GuideSortMode.time:
      final now = DateTime.now();
      final aTime = nextAvailableGuideTime(a, from: now);
      final bTime = nextAvailableGuideTime(b, from: now);
      if (aTime == null && bTime == null) {
        return b.rating.compareTo(a.rating);
      }
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      final time = aTime.compareTo(bTime);
      if (time != 0) return time;
      return b.rating.compareTo(a.rating);
    case GuideSortMode.distance:
      if (a.distanceMeters == null && b.distanceMeters == null) {
        return b.rating.compareTo(a.rating);
      }
      if (a.distanceMeters == null) return 1;
      if (b.distanceMeters == null) return -1;
      final distance = a.distanceMeters!.compareTo(b.distanceMeters!);
      if (distance != 0) return distance;
      return b.rating.compareTo(a.rating);
  }
}

/// Returns the earliest slot that can still be booked in the next seven days.
DateTime? nextAvailableGuideTime(
  Guide guide, {
  DateTime? from,
  int lookaheadDays = 7,
}) {
  final start = from ?? DateTime.now();
  final startDate = DateTime(start.year, start.month, start.day);
  DateTime? earliest;

  for (var dayOffset = 0; dayOffset <= lookaheadDays; dayOffset++) {
    final date = startDate.add(Duration(days: dayOffset));
    for (final rule in guide.availability) {
      if (rule['is_available'] == false) continue;
      if (!_availabilityMatchesDate(rule, date)) continue;

      final startMinutes = _parseMinutes(rule['start_time']);
      final endMinutes = _parseMinutes(rule['end_time']);
      if (startMinutes == null) continue;
      if (endMinutes == null) continue;
      final candidate = DateTime(
        date.year,
        date.month,
        date.day,
        startMinutes ~/ 60,
        startMinutes % 60,
      );
      final end = DateTime(
        date.year,
        date.month,
        date.day,
        endMinutes ~/ 60,
        endMinutes % 60,
      );
      final effectiveCandidate =
          candidate.isBefore(start) &&
              date.year == start.year &&
              date.month == start.month &&
              date.day == start.day &&
              start.isBefore(end)
          ? start
          : candidate;
      if (effectiveCandidate.isBefore(start)) continue;
      if (earliest == null || effectiveCandidate.isBefore(earliest)) {
        earliest = effectiveCandidate;
      }
    }
  }
  return earliest;
}

bool _availabilityMatchesDate(Map<String, dynamic> rule, DateTime date) {
  final type = rule['recurrence_type']?.toString() ?? 'exact';
  final serviceDate = _parseDateOnly(rule['service_date']);
  final dateStart = _parseDateOnly(rule['date_start']) ?? serviceDate;
  final dateEnd = _parseDateOnly(rule['date_end']) ?? serviceDate;

  if (dateStart != null && date.isBefore(dateStart)) return false;
  if (dateEnd != null && date.isAfter(dateEnd)) return false;

  if (type == 'weekly') {
    final weekdays = (rule['weekdays'] as List?)
        ?.map((item) => int.tryParse(item.toString()))
        .whereType<int>()
        .toSet();
    return weekdays?.contains(date.weekday) ?? false;
  }

  if (type == 'exact') {
    return dateStart == null || _sameDay(dateStart, date);
  }
  return true;
}

DateTime? _parseDateOnly(dynamic value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  return parsed == null
      ? null
      : DateTime(parsed.year, parsed.month, parsed.day);
}

int? _parseMinutes(dynamic value) {
  final parts = value?.toString().split(':') ?? const <String>[];
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || hour > 23) return null;
  if (minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
