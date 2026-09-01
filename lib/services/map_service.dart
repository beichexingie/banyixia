import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class MapSuggestion {
  final String name;
  final String city;
  final String district;
  final double? latitude;
  final double? longitude;

  const MapSuggestion({
    required this.name,
    required this.city,
    this.district = '',
    this.latitude,
    this.longitude,
  });
}

class MapPosition {
  final String formattedAddress;
  final String city;
  final String district;
  final double? latitude;
  final double? longitude;

  const MapPosition({
    required this.formattedAddress,
    required this.city,
    this.district = '',
    this.latitude,
    this.longitude,
  });
}

class MapRouteStep {
  final String instruction;
  final String road;
  final int distanceMeters;
  final int durationSeconds;
  final List<LatLng> polyline;

  const MapRouteStep({
    required this.instruction,
    required this.road,
    required this.distanceMeters,
    required this.durationSeconds,
    this.polyline = const [],
  });
}

class MapRoute {
  final int distanceMeters;
  final int durationSeconds;
  final String? taxiCostText;
  final List<LatLng> polyline;
  final List<MapRouteStep> steps;

  const MapRoute({
    required this.distanceMeters,
    required this.durationSeconds,
    this.taxiCostText,
    this.polyline = const [],
    this.steps = const [],
  });
}

abstract class MapService {
  Future<List<MapSuggestion>> searchPlaces({
    required String keyword,
    String? city,
  });

  Future<MapPosition?> geocodeAddress({required String address, String? city});

  Future<MapPosition?> reverseGeocode({
    required double latitude,
    required double longitude,
  });

  Future<MapPosition?> currentPosition({
    bool forceRefresh = false,
    bool allowActiveRequest = true,
  });

  Future<MapRoute?> planDrivingRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  });

  String? staticMapUrl({
    required double latitude,
    required double longitude,
    int zoom,
    int width,
    int height,
  });
}

class AmapApiException implements Exception {
  final String code;
  final String info;
  final Map<String, dynamic>? raw;

  const AmapApiException({required this.code, required this.info, this.raw});

  @override
  String toString() => 'AmapApiException($code): $info';
}

class AmapMapService implements MapService {
  final String apiKey;
  static const double _earthRadius = 6378245.0;
  static const double _eccentricity = 0.00669342162296594323;

  const AmapMapService({this.apiKey = ''});

  bool get _isEnabled => apiKey.trim().isNotEmpty;

  @override
  Future<List<MapSuggestion>> searchPlaces({
    required String keyword,
    String? city,
  }) async {
    if (!_isEnabled || keyword.trim().isEmpty) {
      return [];
    }

    final uri = Uri.https(
      'restapi.amap.com',
      '/v3/assistant/inputtips',
      <String, String>{
        'key': apiKey.trim(),
        'keywords': keyword.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        'datatype': 'all',
      },
    );

    final data = await _getJson(uri);
    _ensureSuccess(data);
    final tips = data?['tips'];
    if (tips is! List) return [];

    return tips
        .map<MapSuggestion>((item) {
          if (item is! Map) {
            return const MapSuggestion(name: '', city: '');
          }
          final gcjLocation = _parseLocation(item['location']?.toString());
          final location = gcjLocation == null
              ? null
              : _gcj02ToWgs84Exact(gcjLocation.$1!, gcjLocation.$2!);
          return MapSuggestion(
            name: item['name']?.toString() ?? '',
            city: item['city']?.toString() ?? city?.trim() ?? '',
            district: item['district']?.toString() ?? '',
            latitude: location?.$1,
            longitude: location?.$2,
          );
        })
        .where((item) => item.name.isNotEmpty)
        .toList();
  }

  @override
  Future<MapPosition?> geocodeAddress({
    required String address,
    String? city,
  }) async {
    if (!_isEnabled || address.trim().isEmpty) return null;

    final uri =
        Uri.https('restapi.amap.com', '/v3/geocode/geo', <String, String>{
          'key': apiKey.trim(),
          'address': address.trim(),
          if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
        });

    final data = await _getJson(uri);
    _ensureSuccess(data);
    final geocodes = data?['geocodes'];
    if (geocodes is! List || geocodes.isEmpty) return null;

    final first = geocodes.first;
    if (first is! Map) return null;
    final gcjLocation = _parseLocation(first['location']?.toString());
    final location = gcjLocation == null
        ? null
        : _gcj02ToWgs84Exact(gcjLocation.$1!, gcjLocation.$2!);

    return MapPosition(
      formattedAddress:
          first['formatted_address']?.toString() ?? address.trim(),
      city: first['city']?.toString() ?? city?.trim() ?? '',
      district: first['district']?.toString() ?? '',
      latitude: location?.$1,
      longitude: location?.$2,
    );
  }

  @override
  Future<MapPosition?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (!_isEnabled) return null;
    final gcjLocation = _wgs84ToGcj02(latitude, longitude);

    final uri =
        Uri.https('restapi.amap.com', '/v3/geocode/regeo', <String, String>{
          'key': apiKey.trim(),
          'location': '${gcjLocation.$2},${gcjLocation.$1}',
          'radius': '1000',
          'extensions': 'base',
        });

    final data = await _getJson(uri);
    _ensureSuccess(data);
    final regeocode = data?['regeocode'];
    if (regeocode is! Map) return null;
    final addressComponent = regeocode['addressComponent'];
    final formattedAddress = regeocode['formatted_address']?.toString() ?? '';

    return MapPosition(
      formattedAddress: formattedAddress,
      city: _extractCity(addressComponent),
      district: _extractDistrict(addressComponent),
      latitude: latitude,
      longitude: longitude,
    );
  }

  @override
  String? staticMapUrl({
    required double latitude,
    required double longitude,
    int zoom = 15,
    int width = 640,
    int height = 320,
  }) {
    if (!_isEnabled) return '';
    final gcjLocation = _wgs84ToGcj02(latitude, longitude);
    return Uri.https('restapi.amap.com', '/v3/staticmap', <String, String>{
      'key': apiKey.trim(),
      'location': '${gcjLocation.$2},${gcjLocation.$1}',
      'zoom': zoom.toString(),
      'size': '${width}*${height}',
      'markers': 'mid,,A:${gcjLocation.$2},${gcjLocation.$1}',
    }).toString();
  }

  @override
  Future<MapPosition?> currentPosition({
    bool forceRefresh = false,
    bool allowActiveRequest = true,
  }) async {
    final permission = await Geolocator.checkPermission();
    var resolvedPermission = permission;
    if (resolvedPermission == LocationPermission.denied) {
      resolvedPermission = await Geolocator.requestPermission();
    }
    if (resolvedPermission == LocationPermission.denied ||
        resolvedPermission == LocationPermission.deniedForever) {
      throw const AmapApiException(
        code: 'LOCATION_PERMISSION_DENIED',
        info: '定位权限未授予',
      );
    }

    // Read the platform cache before starting a new GPS request. Background
    // warming uses this path only and must never occupy the active request.
    Position? lastKnown;
    try {
      lastKnown = await Geolocator.getLastKnownPosition();
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final managerPosition = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true,
        );
        if (managerPosition != null &&
            (lastKnown == null ||
                managerPosition.timestamp.isAfter(lastKnown.timestamp))) {
          lastKnown = managerPosition;
        }
      }
    } catch (_) {
      // A failed fused-provider read should not prevent the Android fallback.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          lastKnown = await Geolocator.getLastKnownPosition(
            forceAndroidLocationManager: true,
          );
        } catch (_) {
          lastKnown = null;
        }
      } else {
        lastKnown = null;
      }
    }

    late final Position position;
    if (!forceRefresh && lastKnown != null) {
      // Distance sorting does not need turn-by-turn GPS precision. Reuse a
      // recent fix immediately instead of blocking the list on GPS startup.
      position = lastKnown;
    } else if (!allowActiveRequest) {
      return lastKnown == null ? null : _positionToMapPosition(lastKnown);
    } else {
      try {
        // Do not gate this call with isLocationServiceEnabled(). On some
        // Android vendors that status can briefly report false even while the
        // system location switch is on. The actual location request is the
        // reliable source of truth here.
        position = await _requestCurrentPosition(forceRefresh: forceRefresh);
      } on LocationServiceDisabledException {
        throw const AmapApiException(
          code: 'LOCATION_SERVICE_DISABLED',
          info: '定位服务未开启',
        );
      } on TimeoutException {
        if (lastKnown != null) {
          return _positionToMapPosition(lastKnown);
        }
        throw const AmapApiException(
          code: 'LOCATION_TIMEOUT',
          info: '定位超时，请稍后重试',
        );
      }
    }

    final rawPoint = LatLng(position.latitude, position.longitude);
    final normalizedPoint = _shouldTreatDeviceLocationAsGcj(rawPoint)
        ? toWgs84LatLng(rawPoint)
        : rawPoint;

    // Distance sorting only needs coordinates. Reverse geocoding is optional;
    // an invalid Web Service key must not make a valid GPS position unusable.
    if (!_isEnabled) {
      return MapPosition(
        formattedAddress: '当前位置',
        city: '',
        latitude: normalizedPoint.latitude,
        longitude: normalizedPoint.longitude,
      );
    }

    try {
      final resolved = await reverseGeocode(
        latitude: normalizedPoint.latitude,
        longitude: normalizedPoint.longitude,
      );
      return resolved ??
          MapPosition(
            formattedAddress: '当前位置',
            city: '',
            latitude: normalizedPoint.latitude,
            longitude: normalizedPoint.longitude,
          );
    } on AmapApiException {
      return MapPosition(
        formattedAddress: '当前位置',
        city: '',
        latitude: normalizedPoint.latitude,
        longitude: normalizedPoint.longitude,
      );
    }
  }

  Future<Position> _requestCurrentPosition({required bool forceRefresh}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final nativePosition = await _requestNativeSystemPosition(
        forceRefresh: forceRefresh,
      );
      if (nativePosition != null) return nativePosition;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Some phones return a network/fused fix while others only return a
      // fix through LocationManager. Run both providers instead of waiting
      // for one provider to time out before trying the other.
      return _firstSuccessfulPosition([
        Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            intervalDuration: const Duration(seconds: 5),
            timeLimit: const Duration(seconds: 20),
          ),
        ),
        Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            forceLocationManager: true,
            accuracy: LocationAccuracy.high,
            distanceFilter: 0,
            timeLimit: const Duration(seconds: 20),
          ),
        ),
      ]);
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
  }

  Future<Position?> _requestNativeSystemPosition({
    required bool forceRefresh,
  }) async {
    try {
      final data =
          await const MethodChannel(
            'flutter_application_1/system_location',
          ).invokeMethod<dynamic>('getCurrentLocation', <String, dynamic>{
            'forceRefresh': forceRefresh,
          });
      if (data is! Map) return null;
      final latitude = (data['latitude'] as num?)?.toDouble();
      final longitude = (data['longitude'] as num?)?.toDouble();
      if (latitude == null ||
          longitude == null ||
          (latitude == 0 && longitude == 0)) {
        return null;
      }
      return Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        accuracy: (data['accuracy'] as num?)?.toDouble() ?? 0,
        altitude: (data['altitude'] as num?)?.toDouble() ?? 0,
        altitudeAccuracy: 0,
        heading: (data['bearing'] as num?)?.toDouble() ?? 0,
        headingAccuracy: 0,
        speed: (data['speed'] as num?)?.toDouble() ?? 0,
        speedAccuracy: 0,
      );
    } on PlatformException catch (error) {
      debugPrint(
        'Native system location unavailable: ${error.code} ${error.message}',
      );
      return null;
    } on MissingPluginException {
      return null;
    } catch (error) {
      debugPrint('Native system location unavailable: $error');
      return null;
    }
  }

  Future<Position> _firstSuccessfulPosition(List<Future<Position>> requests) {
    final completer = Completer<Position>();
    var pending = requests.length;
    Object? lastError;
    StackTrace? lastStackTrace;
    var serviceDisabled = false;

    for (final request in requests) {
      request.then<void>(
        (position) {
          if (!completer.isCompleted) completer.complete(position);
        },
        onError: (Object error, StackTrace stackTrace) {
          pending--;
          lastError = error;
          lastStackTrace = stackTrace;
          serviceDisabled =
              serviceDisabled || error is LocationServiceDisabledException;
          if (pending != 0 || completer.isCompleted) return;
          if (serviceDisabled) {
            completer.completeError(
              const LocationServiceDisabledException(),
              lastStackTrace,
            );
          } else {
            completer.completeError(lastError!, lastStackTrace);
          }
        },
      );
    }

    return completer.future;
  }

  MapPosition _positionToMapPosition(Position position) {
    final rawPoint = LatLng(position.latitude, position.longitude);
    final normalizedPoint = _shouldTreatDeviceLocationAsGcj(rawPoint)
        ? toWgs84LatLng(rawPoint)
        : rawPoint;
    return MapPosition(
      formattedAddress: '当前位置',
      city: '',
      latitude: normalizedPoint.latitude,
      longitude: normalizedPoint.longitude,
    );
  }

  @override
  Future<MapRoute?> planDrivingRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    if (!_isEnabled) return null;

    final originGcj = _wgs84ToGcj02(originLatitude, originLongitude);
    final destinationGcj = _wgs84ToGcj02(
      destinationLatitude,
      destinationLongitude,
    );

    final uri =
        Uri.https('restapi.amap.com', '/v3/direction/driving', <String, String>{
          'key': apiKey.trim(),
          'origin': '${originGcj.$2},${originGcj.$1}',
          'destination': '${destinationGcj.$2},${destinationGcj.$1}',
          'extensions': 'all',
          'strategy': '0',
        });

    final data = await _getJson(uri);
    _ensureSuccess(data);
    final route = data?['route'];
    if (route is! Map) return null;
    final paths = route['paths'];
    if (paths is! List || paths.isEmpty) return null;
    final firstPath = paths.first;
    if (firstPath is! Map) return null;

    final steps = <MapRouteStep>[];
    final allPoints = <LatLng>[];
    final rawSteps = firstPath['steps'];
    if (rawSteps is List) {
      for (final item in rawSteps) {
        if (item is! Map) continue;
        final stepPoints = _parsePolyline(item['polyline']?.toString());
        allPoints.addAll(stepPoints);
        steps.add(
          MapRouteStep(
            instruction: item['instruction']?.toString() ?? '',
            road: item['road']?.toString() ?? '',
            distanceMeters:
                int.tryParse(item['distance']?.toString() ?? '') ?? 0,
            durationSeconds:
                int.tryParse(item['duration']?.toString() ?? '') ?? 0,
            polyline: stepPoints,
          ),
        );
      }
    }

    return MapRoute(
      distanceMeters:
          int.tryParse(firstPath['distance']?.toString() ?? '') ?? 0,
      durationSeconds:
          int.tryParse(firstPath['duration']?.toString() ?? '') ?? 0,
      taxiCostText: route['taxi_cost']?.toString(),
      polyline: allPoints,
      steps: steps,
    );
  }

  LatLng toGcj02LatLng(LatLng point) {
    final converted = _wgs84ToGcj02(point.latitude, point.longitude);
    return LatLng(converted.$1, converted.$2);
  }

  LatLng toWgs84LatLng(LatLng point) {
    final converted = _gcj02ToWgs84Exact(point.latitude, point.longitude);
    return LatLng(converted.$1, converted.$2);
  }

  bool _shouldTreatDeviceLocationAsGcj(LatLng point) {
    if (_outOfChina(point.latitude, point.longitude)) {
      return false;
    }

    if (kIsWeb) {
      return true;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    try {
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _ensureSuccess(Map<String, dynamic>? data) {
    if (data == null) {
      throw const AmapApiException(code: 'NETWORK', info: '请求失败或返回空数据');
    }
    final status = data['status']?.toString();
    final info = data['info']?.toString() ?? '未知错误';
    final code = data['infocode']?.toString() ?? '';
    if (status != null && status != '1' && status != 'OK') {
      throw AmapApiException(
        code: code.isEmpty ? 'UNKNOWN' : code,
        info: info,
        raw: data,
      );
    }
  }

  (double?, double?)? _parseLocation(String? location) {
    if (location == null || location.isEmpty) return null;
    final parts = location.split(',');
    if (parts.length != 2) return null;
    final longitude = double.tryParse(parts[0]);
    final latitude = double.tryParse(parts[1]);
    if (latitude == null || longitude == null) return null;
    return (latitude, longitude);
  }

  List<LatLng> _parsePolyline(String? rawPolyline) {
    if (rawPolyline == null || rawPolyline.trim().isEmpty) {
      return const [];
    }
    final points = <LatLng>[];
    final segments = rawPolyline.split(';');
    for (final segment in segments) {
      final location = _parseLocation(segment.trim());
      if (location == null || location.$1 == null || location.$2 == null) {
        continue;
      }
      final wgs84 = _gcj02ToWgs84Exact(location.$1!, location.$2!);
      points.add(LatLng(wgs84.$1, wgs84.$2));
    }
    return points;
  }

  String _extractCity(dynamic addressComponent) {
    if (addressComponent is! Map) return '';
    final city = addressComponent['city'];
    if (city is String) {
      return city;
    }
    if (city is List && city.isNotEmpty) {
      return city.first?.toString() ?? '';
    }
    return addressComponent['province']?.toString() ?? '';
  }

  String _extractDistrict(dynamic addressComponent) {
    if (addressComponent is! Map) return '';
    return addressComponent['district']?.toString() ?? '';
  }

  (double, double) _wgs84ToGcj02(double latitude, double longitude) {
    if (_outOfChina(latitude, longitude)) return (latitude, longitude);
    final dLat = _transformLatitude(longitude - 105.0, latitude - 35.0);
    final dLng = _transformLongitude(longitude - 105.0, latitude - 35.0);
    final radLat = latitude / 180.0 * 3.1415926535897932384626;
    final magic = 1 - _eccentricity * math.sin(radLat) * math.sin(radLat);
    final sqrtMagic = math.sqrt(magic);
    final mgLat =
        latitude +
        (dLat * 180.0) /
            ((_earthRadius * (1 - _eccentricity)) /
                (magic * sqrtMagic) *
                3.1415926535897932384626);
    final mgLng =
        longitude +
        (dLng * 180.0) /
            (_earthRadius /
                sqrtMagic *
                math.cos(radLat) *
                3.1415926535897932384626);
    return (mgLat, mgLng);
  }

  (double, double) _gcj02ToWgs84(double latitude, double longitude) {
    if (_outOfChina(latitude, longitude)) return (latitude, longitude);
    final converted = _wgs84ToGcj02(latitude, longitude);
    return (latitude * 2 - converted.$1, longitude * 2 - converted.$2);
  }

  (double, double) _gcj02ToWgs84Exact(double latitude, double longitude) {
    if (_outOfChina(latitude, longitude)) return (latitude, longitude);

    var guessLat = latitude;
    var guessLng = longitude;
    for (var i = 0; i < 8; i++) {
      final converted = _wgs84ToGcj02(guessLat, guessLng);
      final dLat = converted.$1 - latitude;
      final dLng = converted.$2 - longitude;
      guessLat -= dLat;
      guessLng -= dLng;
      if (dLat.abs() < 1e-7 && dLng.abs() < 1e-7) break;
    }

    return (guessLat, guessLng);
  }

  bool _outOfChina(double latitude, double longitude) {
    return longitude < 72.004 ||
        longitude > 137.8347 ||
        latitude < 0.8293 ||
        latitude > 55.8271;
  }

  double _transformLatitude(double longitude, double latitude) {
    var value =
        -100.0 +
        2.0 * longitude +
        3.0 * latitude +
        0.2 * latitude * latitude +
        0.1 * longitude * latitude +
        0.2 * math.sqrt(longitude.abs());
    value +=
        (20.0 * math.sin(6.0 * longitude * 3.1415926535897932384626) +
            20.0 * math.sin(2.0 * longitude * 3.1415926535897932384626)) *
        2.0 /
        3.0;
    value +=
        (20.0 * math.sin(latitude * 3.1415926535897932384626) +
            40.0 * math.sin(latitude / 3.0 * 3.1415926535897932384626)) *
        2.0 /
        3.0;
    value +=
        (160.0 * math.sin(latitude / 12.0 * 3.1415926535897932384626) +
            320 * math.sin(latitude * 3.1415926535897932384626 / 30.0)) *
        2.0 /
        3.0;
    return value;
  }

  double _transformLongitude(double longitude, double latitude) {
    var value =
        300.0 +
        longitude +
        2.0 * latitude +
        0.1 * longitude * longitude +
        0.1 * longitude * latitude +
        0.1 * math.sqrt(longitude.abs());
    value +=
        (20.0 * math.sin(6.0 * longitude * 3.1415926535897932384626) +
            20.0 * math.sin(2.0 * longitude * 3.1415926535897932384626)) *
        2.0 /
        3.0;
    value +=
        (20.0 * math.sin(longitude * 3.1415926535897932384626) +
            40.0 * math.sin(longitude / 3.0 * 3.1415926535897932384626)) *
        2.0 /
        3.0;
    value +=
        (150.0 * math.sin(longitude / 12.0 * 3.1415926535897932384626) +
            300.0 * math.sin(longitude / 30.0 * 3.1415926535897932384626)) *
        2.0 /
        3.0;
    return value;
  }
}

class PlaceholderMapService extends AmapMapService {
  const PlaceholderMapService() : super();

  @override
  Future<List<MapSuggestion>> searchPlaces({
    required String keyword,
    String? city,
  }) async {
    return [];
  }

  @override
  Future<MapPosition?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    return null;
  }

  @override
  Future<MapPosition?> currentPosition({
    bool forceRefresh = false,
    bool allowActiveRequest = true,
  }) async {
    return null;
  }

  @override
  Future<MapRoute?> planDrivingRoute({
    required double originLatitude,
    required double originLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    return null;
  }

  @override
  String? staticMapUrl({
    required double latitude,
    required double longitude,
    int zoom = 15,
    int width = 640,
    int height = 320,
  }) {
    return null;
  }
}
