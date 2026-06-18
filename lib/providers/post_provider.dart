import 'package:flutter/material.dart';

import '../models/post_comment.dart';
import '../models/travel_post.dart';
import '../models/user.dart';
import '../services/ecs_api_client.dart';
import '../services/session_service.dart';

class PostProvider extends ChangeNotifier {
  final EcsApiClient _api = EcsApiClient();
  final SessionService _sessionService;

  List<TravelPost> _posts = [];
  bool _isLoading = false;
  String _searchQuery = '';

  PostProvider({SessionService? sessionService})
      : _sessionService = sessionService ?? EcsSessionService();

  List<TravelPost> get posts => _posts;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  String? _token() => _sessionService.currentSession?.accessToken;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  List<TravelPost> _decodePosts(List<dynamic> items) {
    return items
        .whereType<Map<String, dynamic>>()
        .map((data) {
          final contentStr = data['content']?.toString() ?? '分享动态';
          final postId = data['id'].toString();
          final lines = contentStr.split('\n');
          final parsedTitle = lines.isNotEmpty ? lines.first : '分享动态';
          final parsedContent = lines.length > 1 ? lines.sublist(1).join('\n') : contentStr;
          final images = List<String>.from(data['images'] ?? []);
          return TravelPost(
            id: postId,
            title: parsedTitle,
            subtitle: parsedContent.length > 20 ? '${parsedContent.substring(0, 20)}...' : parsedContent,
            content: parsedContent,
            coverImage: images.isNotEmpty ? images.first : 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&q=80&w=800&h=600',
            images: images,
            authorId: data['user_id']?.toString() ?? '',
            authorName: data['author_name']?.toString() ?? '匿名用户',
            authorAvatar: data['author_avatar']?.toString() ?? '',
            likes: data['likes'] ?? 0,
            commentCount: data['comments'] ?? 0,
            tag: data['location']?.toString() ?? '',
            createdAt: data['created_at'] != null ? DateTime.parse(data['created_at'].toString()) : DateTime.now(),
          );
        })
        .toList();
  }

  Future<void> loadPosts({String? query}) async {
    _isLoading = true;
    if (query != null) _searchQuery = query;
    notifyListeners();

    try {
      final response = await _api.get(
        '/posts',
        authToken: _token(),
        query: _searchQuery.isNotEmpty ? {'q': _searchQuery} : null,
      );
      final data = response['data'];
      if (data is List) {
        _posts = _decodePosts(data);
      }
      if (_posts.isEmpty && _searchQuery.isEmpty) {
        _loadMockPosts();
      }
    } catch (e) {
      debugPrint('Load posts error: $e');
      if (_searchQuery.isEmpty) {
        _loadMockPosts();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<TravelPost>> fetchFollowingPosts() async {
    try {
      final response = await _api.get('/posts/following', authToken: _token());
      final data = response['data'];
      if (data is List) {
        return _decodePosts(data);
      }
    } catch (e) {
      debugPrint('Fetch following posts error: $e');
    }
    return [];
  }

  Future<List<TravelPost>> fetchPostsByUser(String userId) async {
    try {
      final response = await _api.get('/users/$userId/posts', authToken: _token());
      final data = response['data'];
      if (data is List) {
        return _decodePosts(data);
      }
    } catch (e) {
      debugPrint('fetchPostsByUser error: $e');
    }
    return [];
  }

  void _loadMockPosts() {
    _posts = [
      TravelPost(
        id: '1',
        title: '云端暂无数据，这是本地占位 1',
        subtitle: '去发布第一篇帖子吧！',
        content: '这是本地的一条Mock测试帖子',
        coverImage: 'https://picsum.photos/seed/chongqing/400/300',
        authorId: 'u1',
        authorName: '伴一下官方',
        authorAvatar: 'https://picsum.photos/seed/avatar1/100/100',
        likes: 16,
        tag: '官方',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  Future<void> toggleLike(TravelPost post) async {
    final token = _token();
    if (token == null || post.id == '1') return;
    post.isLiked = !post.isLiked;
    post.likes += post.isLiked ? 1 : -1;
    notifyListeners();
    try {
      await _api.post('/posts/${post.id}/like', authToken: token);
    } catch (e) {
      post.isLiked = !post.isLiked;
      post.likes += post.isLiked ? 1 : -1;
      notifyListeners();
      debugPrint('toggleLike error: $e');
    }
  }

  Future<void> addPost({
    required String title,
    required String content,
    required List<String> images,
    required String authorId,
    required String authorName,
    required String authorAvatar,
    String tag = '',
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.post(
        '/posts',
        authToken: _token(),
        body: {
          'title': title,
          'content': content,
          'images': images,
          'author_id': authorId,
          'author_name': authorName,
          'author_avatar': authorAvatar,
          'tag': tag,
        },
      );
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        final created = _decodePosts([data]);
        if (created.isNotEmpty) {
          _posts.insert(0, created.first);
        }
      }
    } catch (e) {
      debugPrint('Add post error: $e');
      throw Exception('发布失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite(TravelPost post) async {
    final token = _token();
    if (token == null || post.id == '1') return;
    post.isFavorited = !post.isFavorited;
    notifyListeners();
    try {
      if (post.isFavorited) {
        await _api.post('/posts/${post.id}/favorite', authToken: token);
      } else {
        await _api.delete('/posts/${post.id}/favorite', authToken: token);
      }
    } catch (e) {
      post.isFavorited = !post.isFavorited;
      notifyListeners();
      debugPrint('toggleFavorite error: $e');
    }
  }

  Future<List<TravelPost>> fetchFavoritedPosts() async {
    try {
      final response = await _api.get('/posts/favorites', authToken: _token());
      final data = response['data'];
      if (data is List) return _decodePosts(data);
    } catch (e) {
      debugPrint('fetchFavoritedPosts error: $e');
    }
    return [];
  }

  Future<List<PostComment>> loadComments(String postId) async {
    try {
      final response = await _api.get('/posts/$postId/comments', authToken: _token());
      final data = response['data'];
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(PostComment.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('Load comments error: $e');
    }
    return [];
  }

  Future<void> addComment(String postId, String content) async {
    await _api.post(
      '/posts/$postId/comments',
      authToken: _token(),
      body: {'content': content},
    );
  }

  Future<void> recordFootprint(String postId) async {
    if (postId == '1') return;
    try {
      await _api.post('/posts/$postId/footprint', authToken: _token());
    } catch (e) {
      debugPrint('Record footprint error: $e');
    }
  }

  Future<List<TravelPost>> fetchFootprints() async {
    try {
      final response = await _api.get('/posts/footprints', authToken: _token());
      final data = response['data'];
      if (data is List) return _decodePosts(data);
    } catch (e) {
      debugPrint('Fetch footprints error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> _fetchAuthorProfiles(Iterable<String?> userIds) async {
    return {};
  }
}
