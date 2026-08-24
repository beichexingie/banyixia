import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../models/activity.dart';
import '../../services/ecs_api_client.dart';

class ActivityDetailPage extends StatefulWidget {
  final String activityId;

  const ActivityDetailPage({super.key, required this.activityId});

  @override
  State<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends State<ActivityDetailPage> {
  final EcsApiClient _api = EcsApiClient();
  Activity? _activity;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActivity();
  }

  Future<void> _loadActivity() async {
    try {
      final response = await _api.get('/activities/${widget.activityId}');
      final data = response['data'];
      if (!mounted) return;
      if (data is Map) {
        setState(
          () => _activity = Activity.fromJson(Map<String, dynamic>.from(data)),
        );
      } else {
        setState(() => _error = '活动不存在或已下线');
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  String _imageUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    return '${AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '')}/'
        '${value.replaceFirst(RegExp(r'^/'), '')}';
  }

  String _dateText(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      appBar: AppBar(
        title: const Text('活动详情'),
        backgroundColor: const Color(0xFFF7F7F2),
        surfaceTintColor: Colors.transparent,
      ),
      body: activity == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator(color: Color(0xFF8BC429))
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 32),
              children: [
                if (activity.bannerImage.trim().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 7,
                      child: Image.network(
                        _imageUrl(activity.bannerImage),
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stackTrace) =>
                            _fallbackBanner(),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  activity.title,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF20231A),
                  ),
                ),
                if (activity.startsAt != null || activity.endsAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    '活动时间：${_dateText(activity.startsAt)}${activity.endsAt == null ? '' : ' - ${_dateText(activity.endsAt)}'}',
                    style: const TextStyle(color: Color(0xFF858A7C)),
                  ),
                ],
                if (activity.summary.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    activity.summary,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.55,
                      color: Color(0xFF656A5D),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Text(
                  activity.content,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.8,
                    color: Color(0xFF33372D),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _fallbackBanner() {
    return Image.asset('assets/home/banner/Rectangle 8.png', fit: BoxFit.cover);
  }
}
