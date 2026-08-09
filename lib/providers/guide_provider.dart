import 'package:flutter/material.dart';

import '../models/guide.dart';
import '../services/ecs_api_client.dart';
import '../services/session_service.dart';

class GuideProvider extends ChangeNotifier {
  final EcsApiClient _api = EcsApiClient();
  final SessionService _sessionService;

  List<Guide> _guides = [];
  bool _isLoading = false;
  String _selectedCity = '全国';
  Set<String> _favoriteIds = {};
  Set<String> _likedIds = {};
  Set<String> _followingIds = {};
  List<Guide> _followingGuides = [];
  List<Guide> _footprints = [];
  String? _filterGender;
  double? _filterMaxPrice;
  String? _filterTag;
  String _searchQuery = '';

  GuideProvider({SessionService? sessionService})
      : _sessionService = sessionService ?? EcsSessionService();

  List<Guide> get guides => _guides;
  bool get isLoading => _isLoading;
  String get selectedCity => _selectedCity;
  Set<String> get favoriteIds => _favoriteIds;
  Set<String> get likedIds => _likedIds;
  Set<String> get followingIds => _followingIds;
  List<Guide> get footprints => _footprints;
  String? get filterGender => _filterGender;
  double? get filterMaxPrice => _filterMaxPrice;
  String? get filterTag => _filterTag;
  String get searchQuery => _searchQuery;

  String? _token() => _sessionService.currentSession?.accessToken;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Guide> get favoriteGuides => _guides.where((g) => _favoriteIds.contains(g.id)).toList();
  List<Guide> get followingGuides => _followingGuides.isNotEmpty
      ? _followingGuides
      : _guides.where((g) => _followingIds.contains(g.id)).toList();

  List<Guide> get filteredGuides {
    return _guides.where((g) {
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matches = g.name.toLowerCase().contains(query) ||
            g.city.toLowerCase().contains(query) ||
            g.description.toLowerCase().contains(query) ||
            g.tags.join(' ').toLowerCase().contains(query);
        if (!matches) return false;
      }
      if (_selectedCity != '全国' &&
          _normalizeCityName(g.city) != _normalizeCityName(_selectedCity)) {
        return false;
      }
      if (_filterGender != null && g.gender != _filterGender) return false;
      if (_filterTag != null && !g.tags.contains(_filterTag)) return false;
      return true;
    }).toList();
  }

  void setGenderFilter(String? gender) {
    _filterGender = gender;
    notifyListeners();
  }

  void setTagFilter(String? tag) {
    _filterTag = tag;
    notifyListeners();
  }

  void clearFilters() {
    _filterGender = null;
    _filterMaxPrice = null;
    _filterTag = null;
    notifyListeners();
  }

  Future<void> loadGuides() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.get('/guides', authToken: _token());
      final data = response['data'];
      if (data is List) {
        _guides = data
            .whereType<Map<String, dynamic>>()
            .map(Guide.fromJson)
            .toList();
      }
      final me = _sessionService.currentSession;
      if (me != null) {
        await Future.wait([
          _loadUserInteractions(me.userId),
          loadFollowingGuides(notify: false),
        ]);
      }
    } catch (e) {
      debugPrint('Error loading guides: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Guide?> getGuideById(String guideId) async {
    try {
      final response = await _api.get('/guides/$guideId', authToken: _token());
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return Guide.fromJson(data);
      }
    } catch (e) {
      debugPrint('getGuideById error: $e');
    }
    return null;
  }

  Future<void> _loadUserInteractions(String userId) async {
    try {
      final response = await _api.get('/users/$userId/interactions', authToken: _token());
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        _favoriteIds = (data['favorite_ids'] as List? ?? const []).map((e) => e.toString()).toSet();
        _likedIds = (data['liked_ids'] as List? ?? const []).map((e) => e.toString()).toSet();
        _followingIds = (data['following_guide_ids'] as List? ?? const []).map((e) => e.toString()).toSet();
        final footprints = data['footprints'];
        if (footprints is List) {
          _footprints = footprints
              .whereType<Map<String, dynamic>>()
              .map(Guide.fromJson)
              .toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading user interactions: $e');
    }
  }

  /// Followed guides are fetched directly so they do not disappear when the
  /// normal guide list is filtered to a different city.
  Future<void> loadFollowingGuides({bool notify = true}) async {
    final token = _token();
    if (token == null || token.isEmpty) {
      _followingGuides = [];
      if (notify) notifyListeners();
      return;
    }
    try {
      final response = await _api.get('/users/me/following', authToken: token);
      final data = response['data'];
      if (data is List) {
        _followingGuides = data
            .whereType<Map<String, dynamic>>()
            .map(_guideFromFollowingUser)
            .where((guide) => guide.id.isNotEmpty)
            .toList();
        _followingIds = _followingGuides.map((guide) => guide.id).toSet();
      }
    } catch (error) {
      debugPrint('Load following guides error: $error');
    } finally {
      if (notify) notifyListeners();
    }
  }

  Guide _guideFromFollowingUser(Map<String, dynamic> user) {
    final rawTags = user['guide_tags'] ?? user['tags'] ?? const [];
    return Guide(
      id: user['id']?.toString() ?? '',
      name: user['nickname']?.toString() ?? user['name']?.toString() ?? '地陪',
      avatar: user['avatar']?.toString() ?? '',
      gender: user['gender']?.toString() ?? '',
      verified: user['is_guide'] == true ||
          user['guide_application_status']?.toString() == 'approved',
      tags: rawTags is List
          ? rawTags.map((item) => item.toString()).toList()
          : const [],
      description: user['guide_introduction']?.toString().trim().isNotEmpty ==
              true
          ? user['guide_introduction'].toString()
          : user['bio']?.toString() ?? '',
      city: user['city']?.toString() ?? '',
    );
  }

  Future<void> toggleFavorite(String guideId) async {
    final token = _token();
    if (token == null) return;
    final isFavorited = _favoriteIds.contains(guideId);
    try {
      if (isFavorited) {
        await _api.delete('/guides/$guideId/favorite', authToken: token);
        _favoriteIds.remove(guideId);
      } else {
        await _api.post('/guides/$guideId/favorite', authToken: token);
        _favoriteIds.add(guideId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  Future<void> toggleLike(String guideId) async {
    final token = _token();
    if (token == null) return;
    final isLiked = _likedIds.contains(guideId);
    try {
      if (isLiked) {
        await _api.delete('/guides/$guideId/like', authToken: token);
        _likedIds.remove(guideId);
      } else {
        await _api.post('/guides/$guideId/like', authToken: token);
        _likedIds.add(guideId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> recordFootprint(String guideId) async {
    final token = _token();
    if (token == null) return;
    try {
      await _api.post('/guides/$guideId/footprint', authToken: token);
      await loadGuides();
    } catch (e) {
      debugPrint('Error recording footprint: $e');
    }
  }

  void setCity(String city) {
    _selectedCity = _normalizeCityName(city);
    notifyListeners();
  }

  String _normalizeCityName(String? raw) {
    final city = (raw ?? '').trim();
    if (city.isEmpty || city == '全国') return city;
    const suffixes = ['特别行政区', '自治州', '自治县', '自治区', '地区', '盟', '市'];
    for (final suffix in suffixes) {
      if (city.endsWith(suffix) && city.length > suffix.length) {
        return city.substring(0, city.length - suffix.length);
      }
    }
    return city;
  }
}
