import 'package:flutter/material.dart';

import '../models/demand_request.dart';
import '../services/ecs_api_client.dart';
import '../services/session_service.dart';

class DemandProvider extends ChangeNotifier {
  final EcsApiClient _api = EcsApiClient();
  final SessionService _sessionService;

  List<DemandRequest> _demands = [];
  List<DemandRequest> _myDemands = [];
  List<DemandRequest> _appliedDemands = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCity = '全国';
  String? _selectedStatus;

  DemandProvider({SessionService? sessionService})
      : _sessionService = sessionService ?? EcsSessionService();

  List<DemandRequest> get demands => _demands;
  List<DemandRequest> get myDemands => _myDemands;
  List<DemandRequest> get appliedDemands => _appliedDemands;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedCity => _selectedCity;
  String? get selectedStatus => _selectedStatus;

  List<DemandRequest> get filteredDemands {
    return _demands.where((demand) {
      if (_selectedCity != '全国' &&
          _normalizeCityName(demand.city) != _normalizeCityName(_selectedCity)) {
        return false;
      }
      if (_selectedStatus != null && demand.status != _selectedStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matched =
            demand.title.toLowerCase().contains(query) ||
            demand.content.toLowerCase().contains(query) ||
            demand.city.toLowerCase().contains(query) ||
            demand.location.toLowerCase().contains(query);
        if (!matched) return false;
      }
      return true;
    }).toList();
  }

  void setSearchQuery(String value) {
    _searchQuery = value;
    notifyListeners();
  }

  void setCity(String city) {
    _selectedCity = city == '全国' ? city : _normalizeCityName(city);
    notifyListeners();
  }

  void setStatus(String? status) {
    _selectedStatus = status;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCity = '全国';
    _selectedStatus = null;
    notifyListeners();
  }

  String? _token() => _sessionService.currentSession?.accessToken;

  Future<void> loadDemands({String? query}) async {
    _isLoading = true;
    if (query != null) _searchQuery = query;
    notifyListeners();
    try {
      final response = await _api.get(
        '/demands',
        authToken: _token(),
        query: _searchQuery.isNotEmpty ? {'q': _searchQuery} : null,
      );
      final data = response['data'];
      if (data is List) {
        _demands = data
            .whereType<Map<String, dynamic>>()
            .map(DemandRequest.fromJson)
            .toList();
      } else if (_demands.isEmpty) {
        _loadMockDemands();
      }
    } catch (e) {
      if (_demands.isEmpty) {
        _loadMockDemands();
      }
      debugPrint('Load demands fallback: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyDemands() async {
    final response = await _api.get('/demands/me', authToken: _token());
    final data = response['data'];
    if (data is List) {
      _myDemands = data
          .whereType<Map<String, dynamic>>()
          .map(DemandRequest.fromJson)
          .toList();
      notifyListeners();
    }
  }

  Future<void> loadAppliedDemands() async {
    final response = await _api.get('/demands/applied', authToken: _token());
    final data = response['data'];
    if (data is List) {
      _appliedDemands = data
          .whereType<Map<String, dynamic>>()
          .map(DemandRequest.fromJson)
          .toList();
      notifyListeners();
    }
  }

  Future<DemandRequest> getDemandDetail(String demandId) async {
    final response = await _api.get('/demands/$demandId', authToken: _token());
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return DemandRequest.fromJson(data);
    }
    throw Exception('需求详情加载失败');
  }

  Future<List<DemandApplication>> getDemandApplications(String demandId) async {
    final response = await _api.get(
      '/demands/$demandId/applications',
      authToken: _token(),
    );
    final data = response['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map(DemandApplication.fromJson)
          .toList();
    }
    return const [];
  }

  Future<DemandRequest> createDemand({
    required String title,
    required String content,
    required String city,
    required String location,
    double? serviceLat,
    double? serviceLng,
    required DateTime serviceStartAt,
    required DateTime serviceEndAt,
    required int peopleCount,
    required String gender,
    required String budget,
    required List<String> tags,
  }) async {
    final response = await _api.post(
      '/demands',
      authToken: _token(),
      body: {
        'title': title,
        'content': content,
        'city': city,
        'location': location,
        'service_lat': serviceLat,
        'service_lng': serviceLng,
        'service_start_at': serviceStartAt.toIso8601String(),
        'service_end_at': serviceEndAt.toIso8601String(),
        'people_count': peopleCount,
        'gender': gender,
        'budget': budget,
        'status': 'open',
        'author_id': _sessionService.currentSession?.userId,
        'author_name': '我',
        'author_avatar': '',
        'tags': tags,
      },
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final demand = DemandRequest.fromJson(data);
      _demands.removeWhere((item) => item.id == demand.id);
      _demands.insert(0, demand);
      _myDemands.removeWhere((item) => item.id == demand.id);
      _myDemands.insert(0, demand);
      notifyListeners();
      return demand;
    }
    throw Exception('创建失败');
  }

  Future<void> applyToDemand(
    String demandId, {
    String note = '',
  }) async {
    await _api.post(
      '/demands/$demandId/apply',
      authToken: _token(),
      body: {'note': note},
    );
    await loadAppliedDemands();
    await loadDemands();
  }

  Future<Map<String, dynamic>> selectGuideAndCreateOrder({
    required String demandId,
    required String applicationId,
    required double amount,
  }) async {
    final response = await _api.post(
      '/demands/$demandId/select-guide',
      authToken: _token(),
      body: {
        'application_id': applicationId,
        'amount': amount,
      },
    );
    await loadMyDemands();
    await loadDemands();
    return response['data'] as Map<String, dynamic>;
  }

  void registerInterest(String id) {
    final index = _demands.indexWhere((item) => item.id == id);
    if (index == -1) return;
    final updated = _demands[index].copyWith(
      applicantCount: _demands[index].applicantCount + 1,
    );
    _demands[index] = updated;
    notifyListeners();
  }

  void _loadMockDemands() {
    _demands = [
      DemandRequest(
        id: 'd1',
        title: '苏州金鸡湖一日陪游',
        content: '想找熟悉苏州本地的地陪，带我逛金鸡湖、拍照和吃本地小吃，时间灵活。',
        city: '苏州',
        location: '金鸡湖',
        serviceStartAt: DateTime.now().add(const Duration(days: 1, hours: 2)),
        serviceEndAt: DateTime.now().add(const Duration(days: 1, hours: 10)),
        peopleCount: 1,
        gender: '不限',
        budget: '300-500',
        status: 'open',
        authorId: 'u1',
        authorName: '晓晓',
        authorAvatar: 'https://picsum.photos/seed/demand-user1/100/100',
        images: [
          'https://picsum.photos/seed/demand1-a/400/300',
          'https://picsum.photos/seed/demand1-b/400/300',
        ],
        tags: const ['摄影', 'CityWalk'],
        applicantCount: 3,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];
  }

  String _normalizeCityName(String? raw) {
    final city = (raw ?? '').trim();
    if (city.isEmpty) return '';
    const suffixes = ['特别行政区', '自治州', '自治区', '地区', '盟', '市'];
    for (final suffix in suffixes) {
      if (city.endsWith(suffix) && city.length > suffix.length) {
        return city.substring(0, city.length - suffix.length);
      }
    }
    return city;
  }
}
