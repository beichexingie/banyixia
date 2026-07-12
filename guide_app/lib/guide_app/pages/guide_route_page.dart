import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_1/config/amap_config.dart';
import 'package:flutter_application_1/config/app_theme.dart';
import 'package:flutter_application_1/services/map_service.dart';

import '../models/guide_app_models.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideRoutePage extends StatefulWidget {
  final GuideOrderCardData? order;

  const GuideRoutePage({
    super.key,
    this.order,
  });

  @override
  State<GuideRoutePage> createState() => _GuideRoutePageState();
}

class _GuideRoutePageState extends State<GuideRoutePage> {
  final AmapMapService _mapService = const AmapMapService(
    apiKey: AmapConfig.webServiceKey,
  );

  bool _loading = true;
  String? _errorText;
  MapPosition? _originPosition;
  MapPosition? _destinationPosition;
  MapRoute? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRoute();
    });
  }

  Future<void> _loadRoute() async {
    final console = context.read<GuideConsoleProvider>();
    final order = widget.order;
    if (AmapConfig.webServiceKey.trim().isEmpty) {
      setState(() {
        _loading = false;
        _errorText = '未配置 AMAP_WEB_SERVICE_KEY，当前无法请求路线规划。';
      });
      return;
    }
    if (order == null) {
      setState(() {
        _loading = false;
        _errorText = '当前没有可用于路线规划的订单。请从订单卡片进入路线页。';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final origin = await _resolveOrigin(console.currentLocation);
      if (origin == null ||
          origin.latitude == null ||
          origin.longitude == null) {
        throw const AmapApiException(
          code: 'ORIGIN_NOT_FOUND',
          info: '无法确定当前地陪位置，请先完善定位信息。',
        );
      }

      final destination = await _resolveDestination(order);
      if (destination == null ||
          destination.latitude == null ||
          destination.longitude == null) {
        throw const AmapApiException(
          code: 'DESTINATION_NOT_FOUND',
          info: '当前订单缺少服务地点坐标，无法规划路线。',
        );
      }

      final route = await _mapService.planDrivingRoute(
        originLatitude: origin.latitude!,
        originLongitude: origin.longitude!,
        destinationLatitude: destination.latitude!,
        destinationLongitude: destination.longitude!,
      );
      if (route == null) {
        throw const AmapApiException(
          code: 'ROUTE_EMPTY',
          info: '高德未返回可用路线，请检查起终点坐标是否有效。',
        );
      }

      setState(() {
        _originPosition = origin;
        _destinationPosition = destination;
        _route = route;
        _loading = false;
      });
    } on AmapApiException catch (error) {
      setState(() {
        _loading = false;
        _errorText = _describeAmapError(error);
      });
    } catch (error) {
      setState(() {
        _loading = false;
        _errorText = '路线规划失败: $error';
      });
    }
  }

  Future<MapPosition?> _resolveOrigin(GuideAddress currentLocation) async {
    try {
      final current = await _mapService.currentPosition();
      if (current != null &&
          current.latitude != null &&
          current.longitude != null) {
        return current;
      }
    } catch (_) {
      // Fallback to the stored textual location when device positioning fails.
    }

    final raw = '${currentLocation.city}${currentLocation.title}${currentLocation.detail}';
    final address = raw.replaceAll('（', '').replaceAll('）', '').trim();
    return _mapService.geocodeAddress(
      address: address,
      city: currentLocation.city,
    );
  }

  Future<MapPosition?> _resolveDestination(GuideOrderCardData order) async {
    if (order.serviceLat != null && order.serviceLng != null) {
      return MapPosition(
        formattedAddress: order.address,
        city: order.serviceCity,
        latitude: order.serviceLat,
        longitude: order.serviceLng,
      );
    }
    return _mapService.geocodeAddress(
      address: order.address,
      city: order.serviceCity,
    );
  }

  String _describeAmapError(AmapApiException error) {
    if (error.code == '10001' ||
        error.code == '10002' ||
        error.code == '10003') {
      return '高德 Web Service Key 不可用，请检查 key 本身以及对应服务是否开通。';
    }
    return error.info.isNotEmpty ? error.info : '高德路线规划调用失败';
  }

  String _formatDistance(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '--';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${hours}小时${minutes}分钟';
    }
    return '${minutes}分钟';
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return GuideAppScaffold(
      safeAreaTop: false,
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _RoundIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '路线',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  GuidePillButton(
                    label: '刷新',
                    icon: Icons.refresh_rounded,
                    onTap: _loadRoute,
                    color: Colors.white,
                    foregroundColor: AppColors.textPrimary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                children: [
                  GuideSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '订单信息',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _InfoRow(label: '订单内容', value: order?.content ?? '未选择订单'),
                        _InfoRow(label: '服务地址', value: order?.address ?? '--'),
                        _InfoRow(
                          label: '服务城市',
                          value: order?.serviceCity.isNotEmpty == true
                              ? order!.serviceCity
                              : '--',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const GuideSectionCard(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              CircularProgressIndicator(color: AppColors.primary),
                              SizedBox(height: 14),
                              Text(
                                '正在请求高德路线规划...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (_errorText != null)
                    GuideSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '路线状态',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorText!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFFD55239),
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    GuideSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '路线总览',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _MetricCard(
                                  label: '总距离',
                                  value: _route == null
                                      ? '--'
                                      : _formatDistance(_route!.distanceMeters),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MetricCard(
                                  label: '预计时长',
                                  value: _route == null
                                      ? '--'
                                      : _formatDuration(_route!.durationSeconds),
                                ),
                              ),
                            ],
                          ),
                          if ((_route?.taxiCostText ?? '').isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              '打车参考: ${_route!.taxiCostText}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GuideSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '起终点',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _RouteStopTile(
                            color: const Color(0xFF21B26B),
                            title: '起点',
                            value: _originPosition?.formattedAddress ?? '--',
                          ),
                          const SizedBox(height: 10),
                          _RouteStopTile(
                            color: const Color(0xFFFF7A45),
                            title: '终点',
                            value:
                                _destinationPosition?.formattedAddress ??
                                order?.address ??
                                '--',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GuideSectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '导航步骤',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if ((_route?.steps ?? const []).isEmpty)
                            const Text(
                              '高德已返回路线总览，但未返回详细步骤。',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            )
                          else
                            ..._route!.steps.asMap().entries.map(
                              (entry) => _RouteStepTile(
                                index: entry.key + 1,
                                step: entry.value,
                                distanceText: _formatDistance(entry.value.distanceMeters),
                                durationText: _formatDuration(entry.value.durationSeconds),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;

  const _MetricCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteStopTile extends StatelessWidget {
  final Color color;
  final String title;
  final String value;

  const _RouteStopTile({
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RouteStepTile extends StatelessWidget {
  final int index;
  final MapRouteStep step;
  final String distanceText;
  final String durationText;

  const _RouteStepTile({
    required this.index,
    required this.step,
    required this.distanceText,
    required this.durationText,
  });

  @override
  Widget build(BuildContext context) {
    final title = step.instruction.trim().isNotEmpty
        ? step.instruction.trim()
        : '沿${step.road.isEmpty ? '当前道路' : step.road}行驶';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$distanceText · $durationText',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
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
