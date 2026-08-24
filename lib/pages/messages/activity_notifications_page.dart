import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../models/activity.dart';
import '../../services/ecs_api_client.dart';

class ActivityNotificationsPage extends StatefulWidget {
  const ActivityNotificationsPage({super.key});

  @override
  State<ActivityNotificationsPage> createState() =>
      _ActivityNotificationsPageState();
}

class _ActivityNotificationsPageState extends State<ActivityNotificationsPage> {
  final EcsApiClient _api = EcsApiClient();
  List<Activity> _activities = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _api.get('/activities');
      final data = response['data'];
      final activities = data is List
          ? data
                .whereType<Map>()
                .map(
                  (item) => Activity.fromJson(Map<String, dynamic>.from(item)),
                )
                .where(
                  (activity) =>
                      activity.id.isNotEmpty && activity.title.isNotEmpty,
                )
                .toList()
          : <Activity>[];
      if (!mounted) return;
      setState(() => _activities = activities);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('活动通知')),
      body: RefreshIndicator(
        color: AppColors.primaryDeep,
        onRefresh: _loadActivities,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _activities.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryDeep),
      );
    }
    if (_error != null && _activities.isEmpty) {
      return _messageState(
        icon: Icons.wifi_off_outlined,
        title: '活动加载失败',
        message: _error!,
        actionLabel: '重新加载',
      );
    }
    if (_activities.isEmpty) {
      return _messageState(
        icon: Icons.campaign_outlined,
        title: '暂无新活动',
        message: '管理后台发布的新活动会显示在这里',
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _activities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _activityCard(_activities[index]),
    );
  }

  Widget _activityCard(Activity activity) {
    final image = activity.bannerImage.trim();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/activity/${activity.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (image.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 7,
                child: CachedNetworkImage(
                  imageUrl: _imageUrl(image),
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _bannerFallback(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          activity.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textHint,
                      ),
                    ],
                  ),
                  if (activity.summary.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      activity.summary.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(_activityTime(activity), style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(28, 130, 28, 40),
      children: [
        Icon(icon, size: 54, color: AppColors.textHint),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: AppTextStyles.title),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.subtitle,
        ),
        if (actionLabel != null) ...[
          const SizedBox(height: 20),
          Center(
            child: FilledButton(
              onPressed: _loadActivities,
              child: Text(actionLabel),
            ),
          ),
        ],
      ],
    );
  }

  String _imageUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    final host = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return '$host/${value.replaceFirst(RegExp(r'^/'), '')}';
  }

  String _activityTime(Activity activity) {
    if (activity.startsAt != null || activity.endsAt != null) {
      final start = activity.startsAt == null
          ? '现在'
          : _dateText(activity.startsAt!);
      final end = activity.endsAt == null
          ? '长期有效'
          : _dateText(activity.endsAt!);
      return '活动时间  $start - $end';
    }
    if (activity.createdAt != null) {
      return '发布于 ${_dateTimeText(activity.createdAt!)}';
    }
    return '平台活动';
  }

  String _dateText(DateTime value) {
    final date = value.toLocal();
    return '${date.year}.${_twoDigits(date.month)}.${_twoDigits(date.day)}';
  }

  String _dateTimeText(DateTime value) {
    final date = value.toLocal();
    return '${_dateText(date)} ${_twoDigits(date.hour)}:${_twoDigits(date.minute)}';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  Widget _bannerFallback() {
    return Container(
      color: AppColors.primarySoft,
      alignment: Alignment.center,
      child: const Icon(
        Icons.campaign_outlined,
        size: 42,
        color: AppColors.primaryDeep,
      ),
    );
  }
}
