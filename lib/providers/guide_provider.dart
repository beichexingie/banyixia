import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../models/guide.dart';

/// 地陪人员状态管理
class GuideProvider extends ChangeNotifier {
  final _client = supabase.Supabase.instance.client;
  List<Guide> _guides = [];
  bool _isLoading = false;
  String _selectedCity = '全国';
  
  // 维护当前用户的交互状态
  Set<String> _favoriteIds = {};
  Set<String> _likedIds = {};
  List<Guide> _footprints = [];

  // 筛选状态
  String? _filterGender; // '男' / '女' / null (全部)
  double? _filterMaxPrice;
  String? _filterTag;
  String _searchQuery = '';

  List<Guide> get guides => _guides;
  bool get isLoading => _isLoading;
  String get selectedCity => _selectedCity;
  Set<String> get favoriteIds => _favoriteIds;
  Set<String> get likedIds => _likedIds;
  List<Guide> get footprints => _footprints;

  String? get filterGender => _filterGender;
  double? get filterMaxPrice => _filterMaxPrice;
  String? get filterTag => _filterTag;
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<Guide> get favoriteGuides {
    return _guides.where((g) => _favoriteIds.contains(g.id)).toList();
  }

  /// 按城市及多重过滤后的列表
  List<Guide> get filteredGuides {
    return _guides.where((g) {
      // 关键词过滤
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matches = g.name.toLowerCase().contains(query) ||
            g.city.toLowerCase().contains(query) ||
            g.description.toLowerCase().contains(query);
        if (!matches) return false;
      }

      // 城市过滤
      if (_selectedCity != '全国' && g.city != _selectedCity) return false;
      
      // 性别过滤
      if (_filterGender != null && g.gender != _filterGender) return false;
      
      // 标签过滤 (简单搜索 tags 数组)
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

  GuideProvider() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      final userId = session?.user.id;
      if (userId != null) {
        debugPrint('GuideProvider: Auth change detected. User signed in ($userId). Reloading everything...');
        loadGuides(); // 全量加载，内部会自动同步交互
      } else {
        debugPrint('GuideProvider: Auth change detected. User signed out. Clearing local state.');
        _favoriteIds.clear();
        _likedIds.clear();
        _footprints.clear();
        notifyListeners();
      }
    });
  }

  /// 加载地陪列表
  Future<void> loadGuides() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('GuideProvider: Loading guides from Supabase...');
      final data = await _client.from('guides').select().order('created_at');
      if (data != null) {
        _guides = (data as List).map((json) => Guide.fromJson(json)).toList();
        debugPrint('GuideProvider: Loaded ${_guides.length} guides.');
      }
      
      // 尝试加载当前登录用户的交互数据
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        await _loadUserInteractions(userId);
      } else {
        debugPrint('GuideProvider: No user logged in, skipping interactions load.');
      }
    } catch (e) {
      debugPrint('Error loading guides: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadUserInteractions(String userId) async {
    try {
      debugPrint('GuideProvider: Loading interactions for user $userId...');
      // 加载收藏
      final favData = await _client.from('favorites').select('guide_id').eq('user_id', userId);
      _favoriteIds = (favData as List).map((item) => item['guide_id'].toString()).toSet();

      // 加载点赞
      final likeData = await _client.from('guide_likes').select('guide_id').eq('user_id', userId);
      _likedIds = (likeData as List).map((item) => item['guide_id'].toString()).toSet();
      
      debugPrint('GuideProvider: Fetched ${favData.length} favorites, ${likeData.length} likes');
      debugPrint('GuideProvider: Favorite IDs: $_favoriteIds');

      try {
        // 加载足迹
        final footData = await _client
            .from('footprints')
            .select('guide_id, guides(*)')
            .eq('user_id', userId)
            .order('last_visited_at', ascending: false);
        
        _footprints = (footData as List)
            .where((item) => item['guides'] != null)
            .map((item) {
              try {
                final json = item['guides'];
                if (json is List && json.isNotEmpty) {
                  return Guide.fromJson(json[0]);
                }
                return Guide.fromJson(json);
              } catch (e) {
                debugPrint('Error parsing footprint guide: $e');
                return null;
              }
            })
            .whereType<Guide>()
            .toList();
        
        debugPrint('GuideProvider: Interactions results: Favs: ${_favoriteIds.length}, Likes: ${_likedIds.length}, Footprints: ${_footprints.length}');
      } catch (e) {
        debugPrint('Error loading user footprints specifically: $e');
      }
    } catch (e) {
      debugPrint('Error loading user interactions: $e');
    }
  }

  /// 切换收藏状态
  Future<void> toggleFavorite(String guideId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('GuideProvider: Cannot toggle favorite, user not logged in.');
      return;
    }

    final isFavorited = _favoriteIds.contains(guideId);
    debugPrint('GuideProvider: Toggling favorite for $guideId (Current: $isFavorited)');
    
    try {
      if (isFavorited) {
        await _client.from('favorites').delete().eq('user_id', userId).eq('guide_id', guideId);
        _favoriteIds.remove(guideId);
      } else {
        await _client.from('favorites').insert({'user_id': userId, 'guide_id': guideId});
        _favoriteIds.add(guideId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      if (e is supabase.PostgrestException) {
        debugPrint('Supabase Postgrest Error Details: ${e.message}, Hint: ${e.hint}, Code: ${e.code}');
      }
    }
  }

  /// 切换点赞状态
  Future<void> toggleLike(String guideId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
       debugPrint('GuideProvider: Cannot toggle like, user not logged in.');
       return;
    }

    final isLiked = _likedIds.contains(guideId);
    debugPrint('GuideProvider: Toggling like for $guideId (Current: $isLiked)');
    
    try {
      if (isLiked) {
        await _client.from('guide_likes').delete().eq('user_id', userId).eq('guide_id', guideId);
        _likedIds.remove(guideId);
      } else {
        await _client.from('guide_likes').insert({'user_id': userId, 'guide_id': guideId});
        _likedIds.add(guideId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  /// 记录足迹
  Future<void> recordFootprint(String guideId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client.from('footprints').upsert({
        'user_id': userId,
        'guide_id': guideId,
        'last_visited_at': DateTime.now().toIso8601String(),
      });
      
      // 重新加载本地状态
      final footData = await _client
          .from('footprints')
          .select('guide_id, guides(*)')
          .eq('user_id', userId)
          .order('last_visited_at', ascending: false);
      
      _footprints = (footData as List)
          .where((item) => item['guides'] != null)
          .map((item) {
            final json = item['guides'];
            if (json is List && json.isNotEmpty) {
              return Guide.fromJson(json[0]);
            }
            return Guide.fromJson(json);
          })
          .toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Error recording footprint: $e');
    }
  }

  /// 切换城市筛选
  void setCity(String city) {
    _selectedCity = city;
    notifyListeners();
  }
}
