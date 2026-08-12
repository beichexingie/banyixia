import 'package:flutter/foundation.dart';
import 'package:flutter_application_1/services/ecs_api_client.dart';
import 'package:flutter_application_1/services/session_service.dart';

class GuideServiceItemData {
  final String id;
  final String name;
  final String description;
  final double pricePerHour;
  final double pricePerDay;
  final bool enabled;

  const GuideServiceItemData({
    required this.id,
    required this.name,
    required this.description,
    required this.pricePerHour,
    required this.pricePerDay,
    required this.enabled,
  });

  factory GuideServiceItemData.fromJson(Map<String, dynamic> json) {
    double value(dynamic raw) =>
        raw is num ? raw.toDouble() : double.tryParse('$raw') ?? 0;
    return GuideServiceItemData(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      pricePerHour: value(json['price_per_hour']),
      pricePerDay: value(json['price_per_day']),
      enabled: json['enabled'] != false,
    );
  }
}

class GuideBackendProvider extends ChangeNotifier {
  final EcsApiClient _api;
  final SessionService _sessionService;

  bool _loading = false;
  String? _error;
  Map<String, dynamic> _settings = {};
  List<String> _guideTags = [];
  List<GuideServiceItemData> _serviceItems = [];
  List<Map<String, dynamic>> _availability = [];
  List<Map<String, dynamic>> _reviews = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _training = [];
  List<Map<String, dynamic>> _blockedUsers = [];
  List<Map<String, dynamic>> _supportRequests = [];
  Map<String, dynamic>? _insurance;

  GuideBackendProvider({
    required SessionService sessionService,
    EcsApiClient? api,
  }) : _sessionService = sessionService,
       _api = api ?? EcsApiClient();

  bool get isLoading => _loading;
  String? get error => _error;
  Map<String, dynamic> get settings => _settings;
  List<String> get guideTags => _guideTags;
  List<GuideServiceItemData> get serviceItems => _serviceItems;
  List<Map<String, dynamic>> get availability => _availability;
  List<Map<String, dynamic>> get reviews => _reviews;
  List<Map<String, dynamic>> get tasks => _tasks;
  List<Map<String, dynamic>> get training => _training;
  List<Map<String, dynamic>> get blockedUsers => _blockedUsers;
  List<Map<String, dynamic>> get supportRequests => _supportRequests;
  Map<String, dynamic>? get insurance => _insurance;

  String? get _token => _sessionService.currentSession?.accessToken;

  Future<void> load({bool throwOnError = false}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _api.get('/guide/console', authToken: _token);
      final data = response['data'];
      if (data is! Map<String, dynamic>) throw Exception('地陪端数据格式错误');
      _settings = _map(data['settings']);
      _guideTags = _strings(data['guide_tags']);
      _serviceItems = _list(
        data['service_items'],
      ).map(GuideServiceItemData.fromJson).toList();
      _availability = _list(data['availability']);
      _reviews = _list(data['reviews']);
      _tasks = _list(data['tasks']);
      _training = _list(data['training']);
      _blockedUsers = _list(data['blocked_users']);
      _supportRequests = _list(data['support_requests']);
      _insurance = data['insurance'] is Map
          ? Map<String, dynamic>.from(data['insurance'] as Map)
          : null;
    } catch (error) {
      _error = error.toString();
      if (throwOnError) rethrow;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> saveSettings({
    bool? online,
    String? dutyMode,
    String? city,
    bool? nearbyOnly,
    Map<String, dynamic>? auxiliary,
  }) async {
    final body = <String, dynamic>{
      'online': online ?? _settings['online'] ?? false,
      'duty_mode': dutyMode ?? _settings['duty_mode'] ?? 'nearby',
      'city': city ?? _settings['city'] ?? '',
      'nearby_only': nearbyOnly ?? _settings['nearby_only'] ?? true,
      'auxiliary': auxiliary ?? _settings['auxiliary'] ?? <String, dynamic>{},
    };
    final response = await _api.put(
      '/guide/settings',
      authToken: _token,
      body: body,
    );
    if (response['data'] is Map)
      _settings = Map<String, dynamic>.from(response['data'] as Map);
    notifyListeners();
  }

  Future<void> addServiceItem({
    required String name,
    required String description,
    required double pricePerHour,
  }) async {
    final response = await _api.post(
      '/guide/service-items',
      authToken: _token,
      body: {
        'service_type': name,
        'description': description,
        'price_per_hour': pricePerHour,
      },
    );
    if (response['data'] is Map)
      _serviceItems.insert(
        0,
        GuideServiceItemData.fromJson(
          Map<String, dynamic>.from(response['data'] as Map),
        ),
      );
    notifyListeners();
  }

  Future<void> updateServiceItem(
    String id, {
    String? name,
    String? description,
    double? pricePerHour,
  }) async {
    final response = await _api.put(
      '/guide/service-items/$id',
      authToken: _token,
      body: {
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (pricePerHour != null) 'price_per_hour': pricePerHour,
      },
    );
    if (response['data'] is Map) {
      final item = GuideServiceItemData.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
      _serviceItems = _serviceItems
          .map((old) => old.id == id ? item : old)
          .toList();
    }
    notifyListeners();
  }

  Future<void> deleteServiceItem(String id) async {
    await _api.delete('/guide/service-items/$id', authToken: _token);
    _serviceItems = _serviceItems.where((item) => item.id != id).toList();
    notifyListeners();
  }

  Future<void> saveGuideLocation({
    required double latitude,
    required double longitude,
    String locationText = '',
  }) async {
    await _api.put(
      '/guides/me/location',
      authToken: _token,
      body: {
        'latitude': latitude,
        'longitude': longitude,
        'location_text': locationText,
      },
    );
    notifyListeners();
  }

  Future<void> addAvailability({
    required String date,
    required String start,
    required String end,
    String note = '',
    String recurrenceType = 'exact',
    List<int> weekdays = const [],
    String? dateStart,
    String? dateEnd,
  }) async {
    final response = await _api.post(
      '/guide/availability',
      authToken: _token,
      body: {
        'service_date': date,
        'date_start': dateStart ?? date,
        'date_end': dateEnd ?? dateStart ?? date,
        'start_time': start,
        'end_time': end,
        'note': note,
        'recurrence_type': recurrenceType,
        'weekdays': weekdays,
      },
    );
    if (response['data'] is Map)
      _availability.add(Map<String, dynamic>.from(response['data'] as Map));
    notifyListeners();
  }

  Future<void> deleteAvailability(String id) async {
    await _api.delete('/guide/availability/$id', authToken: _token);
    _availability = _availability
        .where((item) => item['id']?.toString() != id)
        .toList();
    notifyListeners();
  }

  Future<void> replyReview(String id, String reply) async {
    final response = await _api.post(
      '/guide/reviews/$id/reply',
      authToken: _token,
      body: {'reply': reply},
    );
    final data = response['data'];
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      _reviews = _reviews
          .map(
            (item) => item['id']?.toString() == id
                ? {
                    ...item,
                    'guide_reply': map['guide_reply'] ?? reply,
                    'replied_at': map['replied_at'],
                  }
                : item,
          )
          .toList();
    }
    notifyListeners();
  }

  Future<void> completeTask(String key) async {
    await _api.post('/guide/tasks/$key/complete', authToken: _token);
    await load(throwOnError: true);
  }

  Future<void> completeTraining(String id) async {
    await _api.post('/guide/training/$id/complete', authToken: _token);
    _training = _training
        .map(
          (item) => item['id']?.toString() == id
              ? {...item, 'completed': true}
              : item,
        )
        .toList();
    notifyListeners();
  }

  Future<void> addBlockedUser({
    String? phone,
    String? userId,
    required String reason,
  }) async {
    final response = await _api.post(
      '/guide/blocked-users',
      authToken: _token,
      body: {'phone': phone, 'user_id': userId, 'reason': reason},
    );
    if (response['data'] is Map)
      _blockedUsers.insert(
        0,
        Map<String, dynamic>.from(response['data'] as Map),
      );
    notifyListeners();
  }

  Future<void> removeBlockedUser(String id) async {
    await _api.delete('/guide/blocked-users/$id', authToken: _token);
    _blockedUsers = _blockedUsers
        .where((item) => item['blocked_user_id']?.toString() != id)
        .toList();
    notifyListeners();
  }

  Future<void> saveInsurance({
    required String provider,
    required String policyNo,
    String? expiresAt,
    String documentUrl = '',
  }) async {
    final response = await _api.put(
      '/guide/insurance',
      authToken: _token,
      body: {
        'provider': provider,
        'policy_no': policyNo,
        'expires_at': expiresAt,
        'document_url': documentUrl,
      },
    );
    if (response['data'] is Map)
      _insurance = Map<String, dynamic>.from(response['data'] as Map);
    notifyListeners();
  }

  Future<void> createSupportRequest({
    required String category,
    required String content,
  }) async {
    final response = await _api.post(
      '/guide/support-requests',
      authToken: _token,
      body: {'category': category, 'content': content},
    );
    if (response['data'] is Map)
      _supportRequests.insert(
        0,
        Map<String, dynamic>.from(response['data'] as Map),
      );
    notifyListeners();
  }

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
      : <Map<String, dynamic>>[];
  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  List<String> _strings(dynamic value) => value is List
      ? value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList()
      : <String>[];
}
