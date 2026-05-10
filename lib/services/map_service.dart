import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

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
      final location = _parseLocation(item['location']?.toString());
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
    final location = _parseLocation(first['location']?.toString());

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

    final uri = Uri.https(
      'restapi.amap.com',
      '/v3/geocode/regeo',
      <String, String>{
        'key': apiKey.trim(),
        'location': '$longitude,$latitude',
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
    return Uri.https(
      'restapi.amap.com',
      '/v3/staticmap',
      <String, String>{
        'key': apiKey.trim(),
        'location': '$longitude,$latitude',
        'zoom': zoom.toString(),
        'size': '${width}*${height}',
        'markers': 'mid,,A:$longitude,$latitude',
      },
    ).toString();
  }

  @override
  Future<MapPosition?> currentPosition() async {
    if (!_isEnabled) return null;

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
      desiredAccuracy: LocationAccuracy.high,
    );
    return reverseGeocode(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<Map<String, dynamic>?> _getJson(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
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
