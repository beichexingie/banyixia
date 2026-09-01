import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/amap_config.dart';
import 'map_service.dart';

/// Keeps a recent foreground location available to pages that need it.
///
/// The cache is intentionally in memory only. It is not a background location
/// service and stops its timer while the app is not in the foreground.
class LocationCacheService with WidgetsBindingObserver {
  LocationCacheService._();

  static final LocationCacheService instance = LocationCacheService._();

  static const Duration refreshInterval = Duration(minutes: 5);
  static const Duration cacheLifetime = Duration(minutes: 10);

  final MapService _mapService = const AmapMapService(
    apiKey: AmapConfig.webServiceKey,
  );

  Timer? _timer;
  Future<MapPosition?>? _refreshFuture;
  MapPosition? _cachedPosition;
  DateTime? _updatedAt;
  bool _started = false;

  MapPosition? get cachedPosition => _cachedPosition;
  DateTime? get updatedAt => _updatedAt;

  /// Accepts a coordinate reported by the native AMap widget. AMap reports
  /// coordinates in GCJ-02, so normalize them before sharing with API calls
  /// and distance calculations that use WGS-84.
  void updateFromNativeMap({
    required double latitude,
    required double longitude,
  }) {
    if (latitude == 0 && longitude == 0) return;
    final point = const AmapMapService().toWgs84LatLng(
      LatLng(latitude, longitude),
    );
    _cachedPosition = MapPosition(
      formattedAddress: '当前位置',
      city: '',
      latitude: point.latitude,
      longitude: point.longitude,
    );
    _updatedAt = DateTime.now();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addObserver(this);
    }
    _scheduleTimer();
  }

  /// Starts only when permission was already granted, so app launch does not
  /// unexpectedly show a system permission dialog.
  Future<void> startIfAuthorized() async {
    final permission = await Geolocator.checkPermission();
    if (!_hasLocationPermission(permission)) return;
    await start();
  }

  Future<void> start() async {
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addObserver(this);
    }
    _scheduleTimer();

    // Do not delay runApp while the platform obtains a GPS fix.
    unawaited(_refreshInBackground());
  }

  /// Returns a recent cached position, refreshing only when necessary.
  /// Set [forceRefresh] when the user explicitly taps the locate button.
  Future<MapPosition?> getPosition({bool forceRefresh = false}) async {
    if (!forceRefresh && _isFresh) return _cachedPosition;

    try {
      final position = await refresh(forceRefresh: forceRefresh);
      if (position != null) return position;
    } catch (_) {
      // If a recent fix exists, it is more useful than failing sorting or
      // address selection because a new fix timed out.
      if (_cachedPosition != null) return _cachedPosition;
      rethrow;
    }

    return _cachedPosition;
  }

  Future<MapPosition?> refresh({bool forceRefresh = false}) async {
    final existing = _refreshFuture;
    if (existing != null) return existing;

    final future = _refreshFromPlatform(
      forceRefresh: forceRefresh,
      allowActiveRequest: true,
    );
    _refreshFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_refreshFuture, future)) _refreshFuture = null;
    }
  }

  Future<void> _refreshInBackground() async {
    try {
      // Only warm from the platform cache. The user's explicit locate action
      // owns active GPS requests and cannot be blocked by this task.
      await _refreshFromPlatform(
        forceRefresh: false,
        allowActiveRequest: false,
      );
    } catch (_) {
      // Location is opportunistic. A denied permission, disabled service, or
      // timeout must not become an uncaught error during app startup/ticks.
      // The next foreground request can retry it, so do not surface expected
      // platform location failures in the terminal on every timer tick.
    }
  }

  Future<MapPosition?> _refreshFromPlatform({
    required bool forceRefresh,
    required bool allowActiveRequest,
  }) async {
    final position = await _mapService.currentPosition(
      forceRefresh: forceRefresh,
      allowActiveRequest: allowActiveRequest,
    );
    if (position != null &&
        position.latitude != null &&
        position.longitude != null) {
      _cachedPosition = position;
      _updatedAt = DateTime.now();
      if (_hasLocationPermission(await Geolocator.checkPermission())) {
        if (!_started) {
          _started = true;
          WidgetsBinding.instance.addObserver(this);
        }
        _scheduleTimer();
      }
    }
    return position;
  }

  bool get _isFresh =>
      _cachedPosition != null &&
      _updatedAt != null &&
      DateTime.now().difference(_updatedAt!) <= cacheLifetime;

  bool _hasLocationPermission(LocationPermission permission) =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  void _scheduleTimer() {
    if (!_started ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.detached) {
      return;
    }
    _timer ??= Timer.periodic(refreshInterval, (_) {
      unawaited(_refreshInBackground());
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleTimer();
      if (!_isFresh) unawaited(_refreshInBackground());
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopTimer();
    }
  }

  void stop() {
    _stopTimer();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }
}
