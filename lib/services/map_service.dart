import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

abstract class MapService {
  Future<List<MapSuggestion>> searchPlaces({
    required String keyword,
    String? city,
  });

  Future<MapPosition?> geocodeAddress({
    required String address,
    String? city,
  });

  Future<MapPosition?> reverseGeocode({
    required double latitude,
    required double longitude,
  });

  Future<MapPosition?> currentPosition();

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

  const AmapApiException({
    required this.code,
    required this.info,
    this.raw,
  });

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

    return tips.map<MapSuggestion>((item) {
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
    }).where((item) => item.name.isNotEmpty).toList();
  }

  @override
  Future<MapPosition?> geocodeAddress({
    required String address,
    String? city,
  }) async {
    if (!_isEnabled || address.trim().isEmpty) return null;

    final uri = Uri.https(
      'restapi.amap.com',
      '/v3/geocode/geo',
      <String, String>{
        'key': apiKey.trim(),
        'address': address.trim(),
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      },
    );

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
      formattedAddress: first['formatted_address']?.toString() ?? address.trim(),
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

    final uri = Uri.https(
      'restapi.amap.com',
      '/v3/geocode/regeo',
      <String, String>{
        'key': apiKey.trim(),
        'location': '${gcjLocation.$2},${gcjLocation.$1}',
        'radius': '1000',
        'extensions': 'base',
      },
    );

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
    return Uri.https(
      'restapi.amap.com',
      '/v3/staticmap',
      <String, String>{
        'key': apiKey.trim(),
        'location': '${gcjLocation.$2},${gcjLocation.$1}',
        'zoom': zoom.toString(),
        'size': '${width}*${height}',
        'markers': 'mid,,A:${gcjLocation.$2},${gcjLocation.$1}',
      },
    ).toString();
  }

  @override
  Future<MapPosition?> currentPosition() async {
    if (!_isEnabled) return null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const AmapApiException(
        code: 'LOCATION_SERVICE_DISABLED',
        info: '定位服务未开启',
      );
    }

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

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
    final rawPoint = LatLng(position.latitude, position.longitude);
    final normalizedPoint =
        _shouldTreatDeviceLocationAsGcj(rawPoint)
            ? toWgs84LatLng(rawPoint)
            : rawPoint;

    return reverseGeocode(
      latitude: normalizedPoint.latitude,
      longitude: normalizedPoint.longitude,
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
      throw AmapApiException(code: code.isEmpty ? 'UNKNOWN' : code, info: info, raw: data);
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
    final mgLat = latitude +
        (dLat * 180.0) /
            ((_earthRadius * (1 - _eccentricity)) / (magic * sqrtMagic) *
                3.1415926535897932384626);
    final mgLng = longitude +
        (dLng * 180.0) /
            (_earthRadius / sqrtMagic *
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
    var value = -100.0 +
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
                40.0 *
                    math.sin(latitude / 3.0 * 3.1415926535897932384626)) *
            2.0 /
            3.0;
    value +=
        (160.0 *
                    math.sin(latitude / 12.0 * 3.1415926535897932384626) +
                320 *
                    math.sin(
                      latitude * 3.1415926535897932384626 / 30.0,
                    )) *
            2.0 /
            3.0;
    return value;
  }

  double _transformLongitude(double longitude, double latitude) {
    var value = 300.0 +
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
                40.0 *
                    math.sin(longitude / 3.0 * 3.1415926535897932384626)) *
            2.0 /
            3.0;
    value +=
        (150.0 *
                    math.sin(longitude / 12.0 * 3.1415926535897932384626) +
                300.0 *
                    math.sin(
                      longitude / 30.0 * 3.1415926535897932384626,
                    )) *
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
  Future<MapPosition?> currentPosition() async {
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
