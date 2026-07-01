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
    return items.whereType<Map<String, dynamic>>().map((data) {
      final contentText =
          _firstNonEmptyString([
            data['content'],
            data['title'],
            data['subtitle'],
          ]) ??
          '';
      final lines = contentText
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      final parsedTitle =
          _firstNonEmptyString([
            data['title'],
            lines.isNotEmpty ? lines.first : null,
          ]) ??
          '';
      final parsedContent =
          _firstNonEmptyString([
            data['body'],
            data['description'],
            lines.length > 1 ? lines.sublist(1).join('\n') : null,
            contentText,
          ]) ??
          '';
      final images = _asStringList(data['images']);
      final nestedAuthor =
          _asMap(data['author']) ??
          _asMap(data['user']) ??
          _asMap(data['users']);

      return TravelPost(
        id: data['id']?.toString() ?? '',
        title: parsedTitle,
        subtitle: parsedContent.length > 20
            ? '${parsedContent.substring(0, 20)}...'
            : parsedContent,
        content: parsedContent,
        coverImage: images.isNotEmpty
            ? images.first
            : 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&q=80&w=800&h=600',
        images: images,
        authorId: data['user_id']?.toString() ?? '',
        authorName:
            _firstNonEmptyString([
              data['author_name'],
              data['authorName'],
              nestedAuthor?['nickname'],
              nestedAuthor?['name'],
            ]) ??
            '匿名用户',
        authorAvatar:
            _firstNonEmptyString([
              data['author_avatar'],
              data['authorAvatar'],
              nestedAuthor?['avatar'],
              nestedAuthor?['avatar_url'],
            ]) ??
            '',
        likes: _parseInt(data['likes']) ?? 0,
        favorites: _parseInt(data['favorites']) ?? 0,
        commentCount: _parseInt(data['comments']) ?? 0,
        tag: data['location']?.toString() ?? '',
        createdAt: _parseDateTime(data['created_at']) ?? DateTime.now(),
        isLiked:
            _parseBool(data['is_liked']) ??
            _parseBool(data['isLiked']) ??
            false,
        isFavorited:
            _parseBool(data['is_favorited']) ??
            _parseBool(data['isFavorited']) ??
            false,
      );
    }).toList();
  }

  Future<void> loadPosts({String? query}) async {
    _isLoading = true;
    if (query != null) {
      _searchQuery = query;
    }
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
      } else {
        _posts = [];
      }
    } catch (e) {
      debugPrint('Load posts error: $e');
      _posts = [];
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
      final response = await _api.get(
        '/users/$userId/posts',
        authToken: _token(),
      );
      final data = response['data'];
      if (data is List) {
        return _decodePosts(data);
      }
    } catch (e) {
      debugPrint('fetchPostsByUser error: $e');
    }
    return [];
  }

  Future<void> toggleLike(TravelPost post) async {
    final token = _token();
    if (token == null || post.id == '1') {
      return;
    }

    post.isLiked = !post.isLiked;
    post.likes += post.isLiked ? 1 : -1;
    if (post.likes < 0) {
      post.likes = 0;
    }
    notifyListeners();

    try {
      if (post.isLiked) {
        await _api.post('/posts/${post.id}/like', authToken: token);
      } else {
        await _api.delete('/posts/${post.id}/like', authToken: token);
      }
    } catch (e) {
      post.isLiked = !post.isLiked;
      post.likes += post.isLiked ? 1 : -1;
      if (post.likes < 0) {
        post.likes = 0;
      }
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
    if (token == null || post.id == '1') {
      return;
    }

    post.isFavorited = !post.isFavorited;
    post.favorites += post.isFavorited ? 1 : -1;
    if (post.favorites < 0) {
      post.favorites = 0;
    }
    notifyListeners();

    try {
      if (post.isFavorited) {
        await _api.post('/posts/${post.id}/favorite', authToken: token);
      } else {
        await _api.delete('/posts/${post.id}/favorite', authToken: token);
      }
    } catch (e) {
      post.isFavorited = !post.isFavorited;
      post.favorites += post.isFavorited ? 1 : -1;
      if (post.favorites < 0) {
        post.favorites = 0;
      }
      notifyListeners();
      debugPrint('toggleFavorite error: $e');
    }
  }

  Future<List<TravelPost>> fetchFavoritedPosts() async {
    try {
      final response = await _api.get('/posts/favorites', authToken: _token());
      final data = response['data'];
      if (data is List) {
        return _decodePosts(data);
      }
    } catch (e) {
      debugPrint('fetchFavoritedPosts error: $e');
    }
    return [];
  }

  Future<List<TravelPost>> fetchLikedPosts() async {
    try {
      final response = await _api.get('/posts/liked', authToken: _token());
      final data = response['data'];
      if (data is List) {
        return _decodePosts(data);
      }
    } on EcsApiException catch (e) {
      if (e.statusCode == 404) {
        debugPrint(
          'fetchLikedPosts fallback: backend /posts/liked not deployed yet',
        );
        return [];
      }
      debugPrint('fetchLikedPosts error: $e');
    } catch (e) {
      debugPrint('fetchLikedPosts error: $e');
    }
    return [];
  }

  Future<List<PostComment>> loadComments(String postId) async {
    try {
      final response = await _api.get(
        '/posts/$postId/comments',
        authToken: _token(),
      );
      final data = response['data'];
      if (data is List) {
        final comments = data
            .whereType<Map<String, dynamic>>()
            .map(PostComment.fromJson)
            .toList();
        return _hydrateCommentAuthors(comments);
      }
    } catch (e) {
      debugPrint('Load comments error: $e');
    }
    return [];
  }

  Future<List<PostComment>> _hydrateCommentAuthors(
    List<PostComment> comments,
  ) async {
    final idsToFetch = comments
        .where((comment) {
          final missingName =
              comment.userName.trim().isEmpty || comment.userName == '匿名用户';
          final missingAvatar = comment.userAvatar.trim().isEmpty;
          return comment.userId.trim().isNotEmpty &&
              (missingName || missingAvatar);
        })
        .map((comment) => comment.userId.trim())
        .toSet()
        .toList();

    if (idsToFetch.isEmpty) {
      return comments;
    }

    final profileFutures = <String, Future<User?>>{};
    for (final userId in idsToFetch) {
      profileFutures[userId] = _fetchUserById(userId);
    }

    final profiles = <String, User?>{};
    for (final entry in profileFutures.entries) {
      profiles[entry.key] = await entry.value;
    }

    return comments.map((comment) {
      final profile = profiles[comment.userId.trim()];
      final resolvedName =
          comment.userName.trim().isNotEmpty && comment.userName != '匿名用户'
          ? comment.userName
          : (profile?.nickname.trim().isNotEmpty == true
                ? profile!.nickname.trim()
                : '匿名用户');
      final resolvedAvatar = comment.userAvatar.trim().isNotEmpty
          ? comment.userAvatar
          : (profile?.avatar.trim() ?? '');
      return comment.copyWith(
        userName: resolvedName,
        userAvatar: resolvedAvatar,
      );
    }).toList();
  }

  Future<User?> _fetchUserById(String userId) async {
    try {
      final response = await _api.get('/users/$userId', authToken: _token());
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return User.fromJson(data);
      }
    } catch (e) {
      debugPrint('fetchUserById error: $e');
    }
    return null;
  }

  Future<void> addComment(
    String postId,
    String content, {
    String? parentCommentId,
    String? replyToCommentId,
  }) async {
    await _api.post(
      '/posts/$postId/comments',
      authToken: _token(),
      body: {
        'content': content,
        if (parentCommentId != null && parentCommentId.trim().isNotEmpty)
          'parent_comment_id': parentCommentId.trim(),
        if (replyToCommentId != null && replyToCommentId.trim().isNotEmpty)
          'reply_to_comment_id': replyToCommentId.trim(),
      },
    );
    notifyListeners();
  }

  Future<PostComment> toggleCommentLike(PostComment comment) async {
    final token = _token();
    if (token == null || comment.id.trim().isEmpty) {
      return comment;
    }

    final nextLiked = !comment.isLiked;
    final nextLikeCount = nextLiked
        ? comment.likeCount + 1
        : (comment.likeCount - 1).clamp(0, 1 << 30);

    try {
      if (nextLiked) {
        await _api.post('/posts/comments/${comment.id}/like', authToken: token);
      } else {
        await _api.delete(
          '/posts/comments/${comment.id}/like',
          authToken: token,
        );
      }
      return comment.copyWith(isLiked: nextLiked, likeCount: nextLikeCount);
    } catch (e) {
      debugPrint('toggleCommentLike error: $e');
      rethrow;
    }
  }

  Future<void> recordFootprint(String postId) async {
    if (postId == '1') {
      return;
    }
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
      if (data is List) {
        return _decodePosts(data);
      }
    } catch (e) {
      debugPrint('Fetch footprints error: $e');
    }
    return [];
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
  }

  static List<String> _asStringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item?.toString().trim() ?? '')
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static String? _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static bool? _parseBool(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase();
    switch (text) {
      case 'true':
      case '1':
        return true;
      case 'false':
      case '0':
        return false;
      default:
        return null;
    }
  }

  static DateTime? _parseDateTime(dynamic value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) {
      return null;
    }
    return DateTime.tryParse(text);
  }
}
