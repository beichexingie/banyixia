import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/demand_request.dart';

class DemandProvider extends ChangeNotifier {
  final _client = Supabase.instance.client;

  List<DemandRequest> _demands = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedCity = '全国';
  String? _selectedStatus;

  List<DemandRequest> get demands => _demands;
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

  Future<void> loadDemands({String? query}) async {
    _isLoading = true;
    if (query != null) _searchQuery = query;
    notifyListeners();

    try {
      final response = await _client
          .from('demands')
          .select()
          .order('created_at', ascending: false);
      if (response.isNotEmpty) {
        _demands = response
            .map((item) => DemandRequest.fromJson(item))
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

  Future<DemandRequest> createDemand({
    required String title,
    required String content,
    required String city,
    required String location,
    required DateTime serviceStartAt,
    required DateTime serviceEndAt,
    required int peopleCount,
    required String gender,
    required String budget,
    required List<String> tags,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('请先登录后再发布需求');
    }

    final payload = {
      'title': title,
      'content': content,
      'city': city,
      'location': location,
      'service_start_at': serviceStartAt.toIso8601String(),
      'service_end_at': serviceEndAt.toIso8601String(),
      'people_count': peopleCount,
      'gender': gender,
      'budget': budget,
      'status': 'open',
      'author_id': user.id,
      'author_name': user.userMetadata?['nickname']?.toString() ?? '我',
      'author_avatar': user.userMetadata?['avatar']?.toString() ?? '',
      'tags': tags,
    };

    try {
      final inserted = await _client
          .from('demands')
          .insert(payload)
          .select()
          .single();
      final demand = DemandRequest.fromJson(inserted);
      _demands.removeWhere((item) => item.id == demand.id);
      _demands.insert(0, demand);
      notifyListeners();
      return demand;
    } on PostgrestException catch (e) {
      debugPrint('Create demand failed: ${e.message}');
      throw Exception(e.message);
    } catch (e) {
      debugPrint('Create demand failed: $e');
      rethrow;
    }
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
      DemandRequest(
        id: 'd2',
        title: '周末西安博物馆搭子',
        content: '周末想去陕西历史博物馆和大唐不夜城，最好对路线熟悉、会拍照。',
        city: '西安',
        location: '陕西历史博物馆',
        serviceStartAt: DateTime.now().add(const Duration(days: 2, hours: 1)),
        serviceEndAt: DateTime.now().add(const Duration(days: 2, hours: 8)),
        peopleCount: 2,
        gender: '女',
        budget: '200-400',
        status: 'applying',
        authorId: 'u2',
        authorName: '小林',
        authorAvatar: 'https://picsum.photos/seed/demand-user2/100/100',
        images: [
          'https://picsum.photos/seed/demand2-a/400/300',
          'https://picsum.photos/seed/demand2-b/400/300',
        ],
        tags: const ['博物馆', '拍照'],
        applicantCount: 6,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      DemandRequest(
        id: 'd3',
        title: '成都美食陪吃体验',
        content: '想要一个本地人带着我吃串串、火锅、甜品，顺便聊聊成都生活。',
        city: '成都',
        location: '春熙路',
        serviceStartAt: DateTime.now().add(const Duration(days: 3, hours: 3)),
        serviceEndAt: DateTime.now().add(const Duration(days: 3, hours: 9)),
        peopleCount: 1,
        gender: '不限',
        budget: '150-300',
        status: 'open',
        authorId: 'u3',
        authorName: '阿飞',
        authorAvatar: 'https://picsum.photos/seed/demand-user3/100/100',
        images: [
          'https://picsum.photos/seed/demand3-a/400/300',
          'https://picsum.photos/seed/demand3-b/400/300',
        ],
        tags: const ['美食', '聊天'],
        applicantCount: 2,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
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
