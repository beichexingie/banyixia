import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/travel_post.dart';
import '../models/post_comment.dart';

/// 旅行帖子状态管理
class PostProvider extends ChangeNotifier {
  List<TravelPost> _posts = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<TravelPost> get posts => _posts;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  void setSearchQuery(String query) {
    _searchQuery = query;
    // 不直接刷新，由页面触发 loadPosts 或由 filteredPosts 过滤
    notifyListeners();
  }

  /// 加载帖子列表
  Future<void> loadPosts({String? query}) async {
    _isLoading = true;
    if (query != null) _searchQuery = query;
    notifyListeners();

    try {
      var request = Supabase.instance.client
          .from('posts')
          .select();
      
      if (_searchQuery.isNotEmpty) {
        request = request.ilike('content', '%$_searchQuery%');
      }

      final response = await request.order('created_at', ascending: false);

      if (response.isNotEmpty) {
        // Fetch current user's favorites and likes to sync state
        final userId = Supabase.instance.client.auth.currentUser?.id;
        final Set<String> favoritedPostIds = {};
        final Set<String> likedPostIds = {};
        if (userId != null) {
          try {
            final favoritesResponse = await Supabase.instance.client
                .from('post_favorites')
                .select('post_id')
                .eq('user_id', userId);
            for (var fav in favoritesResponse) {
              favoritedPostIds.add(fav['post_id'].toString());
            }
          } catch (e) {
            debugPrint('Fetch favorites error: $e');
          }
          try {
            final likesResponse = await Supabase.instance.client
                .from('post_likes')
                .select('post_id')
                .eq('user_id', userId);
            for (var like in likesResponse) {
              likedPostIds.add(like['post_id'].toString());
            }
          } catch (e) {
            debugPrint('Fetch likes error: $e');
          }
        }

        final authorIds = (response as List).map((data) => data['user_id']?.toString());
        final usersMap = await _fetchAuthorProfiles(authorIds);

        _posts = (response as List).map<TravelPost>((data) {
          final contentStr = data['content']?.toString() ?? '分享动态';
          final postId = data['id'].toString();
          final lines = contentStr.split('\n');
          final parsedTitle = lines.isNotEmpty ? lines.first : '分享动态';
          final parsedContent = lines.length > 1 ? lines.sublist(1).join('\n') : contentStr;
          
          final authorId = data['user_id']?.toString() ?? '';
          final userData = usersMap[authorId];
          final authorName = userData?['nickname'] ?? data['author_name'] ?? '匿名用户';
          final authorAvatar = userData?['avatar'] ?? data['author_avatar'] ?? '';
          
          final images = List<String>.from(data['images'] ?? []);
          final defaultBg = 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&q=80&w=800&h=600';

          return TravelPost(
            id: postId,
            title: parsedTitle,
            subtitle: parsedContent.length > 20 ? '${parsedContent.substring(0, 20)}...' : parsedContent,
            content: parsedContent,
            coverImage: images.isNotEmpty ? images.first : defaultBg,
            images: images,
            authorId: authorId,
            authorName: authorName,
            authorAvatar: authorAvatar,
            likes: data['likes'] ?? 0,
            commentCount: data['comments'] ?? 0,
            tag: data['location'] ?? '',
            createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : DateTime.now(),
            isFavorited: favoritedPostIds.contains(postId),
            isLiked: likedPostIds.contains(postId),
          );
        }).toList();
      } else {
        _posts = []; // 清空或者保留 Mock，这里选择清空真实的搜索结果
        if (_searchQuery.isEmpty) _loadMockPosts();
      }
    } catch (e) {
      debugPrint('Supabase fetch posts error: $e');
      if (_searchQuery.isEmpty) _loadMockPosts();
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 获取关注的人发的帖子
  Future<List<TravelPost>> fetchFollowingPosts() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // 1. 获取我关注的人的 ID 列表
      final followingResponse = await Supabase.instance.client
          .from('follows')
          .select('followed_id')
          .eq('follower_id', userId);
      
      final List<String> followingIds = (followingResponse as List)
          .map((item) => item['followed_id'].toString())
          .toList();

      if (followingIds.isEmpty) return [];

      // 2. 查询这些人的帖子
      final postsResponse = await Supabase.instance.client
          .from('posts')
          .select()
          .inFilter('user_id', followingIds)
          .order('created_at', ascending: false);

      final authorIds = (postsResponse as List).map((data) => data['user_id']?.toString());
      final usersMap = await _fetchAuthorProfiles(authorIds);

      return (postsResponse as List).map<TravelPost>((data) {
        final contentStr = data['content']?.toString() ?? '分享动态';
        final postId = data['id'].toString();
        final lines = contentStr.split('\n');
        final parsedTitle = lines.isNotEmpty ? lines.first : '分享动态';
        final parsedContent = lines.length > 1 ? lines.sublist(1).join('\n') : contentStr;
        
        final authorId = data['user_id']?.toString() ?? '';
        final userData = usersMap[authorId];
        final authorName = userData?['nickname'] ?? data['author_name'] ?? '匿名用户';
        final authorAvatar = userData?['avatar'] ?? data['author_avatar'] ?? '';
        
        final images = List<String>.from(data['images'] ?? []);
        final defaultBg = 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&q=80&w=800&h=600';

        return TravelPost(
          id: postId,
          title: parsedTitle,
          subtitle: parsedContent.length > 20 ? '${parsedContent.substring(0, 20)}...' : parsedContent,
          content: parsedContent,
          coverImage: images.isNotEmpty ? images.first : defaultBg,
          images: images,
          authorId: authorId,
          authorName: authorName,
          authorAvatar: authorAvatar,
          likes: data['likes'] ?? 0,
          tag: data['location'] ?? '',
          createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Fetch following posts error: $e');
      return [];
    }
  }

  /// 获取某用户发布的所有帖子
  Future<List<TravelPost>> fetchPostsByUser(String userId) async {
    try {
      final response = await Supabase.instance.client
          .from('posts')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final authorIds = (response as List).map((data) => data['user_id']?.toString());
      final usersMap = await _fetchAuthorProfiles(authorIds);

      return (response as List).map<TravelPost>((data) {
        final contentStr = data['content']?.toString() ?? '分享动态';
        final postId = data['id'].toString();
        final lines = contentStr.split('\n');
        final parsedTitle = lines.isNotEmpty ? lines.first : '分享动态';
        final parsedContent = lines.length > 1 ? lines.sublist(1).join('\n') : contentStr;

        final authorId = data['user_id']?.toString() ?? '';
        final userData = usersMap[authorId];
        final authorName = userData?['nickname'] ?? data['author_name'] ?? '匿名用户';
        final authorAvatar = userData?['avatar'] ?? data['author_avatar'] ?? '';

        final images = List<String>.from(data['images'] ?? []);
        final defaultBg = 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&q=80&w=800&h=600';

        return TravelPost(
          id: postId,
          title: parsedTitle,
          subtitle: parsedContent.length > 20 ? '${parsedContent.substring(0, 20)}...' : parsedContent,
          content: parsedContent,
          coverImage: images.isNotEmpty ? images.first : defaultBg,
          images: images,
          authorId: authorId,
          authorName: authorName,
          authorAvatar: authorAvatar,
          likes: data['likes'] ?? 0,
          tag: data['location'] ?? '',
          createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('fetchPostsByUser error: $e');
      return [];
    }
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
      ),
    ];
  }

  /// 点赞/取消点赞
  Future<void> toggleLike(TravelPost post) async {
    final postId = post.id;
    final newLikedState = !post.isLiked;
    
    // 乐观更新 UI
    post.isLiked = newLikedState;
    post.likes += newLikedState ? 1 : -1;
    
    // 同步更新 main list _posts (如果存在)
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1 && _posts[index] != post) {
      _posts[index].isLiked = newLikedState;
      _posts[index].likes = post.likes;
    }
    
    notifyListeners();

    if (postId == '1') return; // Skip DB call for mock post

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // 1. 先记录/删除 post_likes（关键操作）
    try {
      if (newLikedState) {
        await Supabase.instance.client.from('post_likes').upsert({
          'user_id': userId,
          'post_id': postId,
        });
      } else {
        await Supabase.instance.client.from('post_likes').delete()
            .eq('user_id', userId)
            .eq('post_id', postId);
      }
    } catch (e) {
      // post_likes 操作失败，回滚 UI
      post.isLiked = !newLikedState;
      post.likes -= newLikedState ? 1 : -1;
      if (index != -1 && _posts[index] != post) {
        _posts[index].isLiked = !newLikedState;
        _posts[index].likes -= newLikedState ? 1 : -1;
      }
      notifyListeners();
      debugPrint('Supabase post_likes error: $e');
      return;
    }

    // 2. 再更新 posts 表的 likes 计数（非关键，失败不回滚）
    try {
      await Supabase.instance.client.from('posts').update({
        'likes': post.likes,
      }).eq('id', postId);
    } catch (e) {
      debugPrint('Supabase posts.likes update error (non-critical): $e');
    }
  }

  /// 发布新帖子到云端
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
      final newPostData = {
        'user_id': authorId,
        'author_name': authorName,
        'author_avatar': authorAvatar,
        'content': title + '\n' + content, // combined title and content
        'images': images,
        'location': tag,
      };

      final response = await Supabase.instance.client.from('posts').insert(newPostData).select().single();

      // 成功后插入到本地首位并刷新 UI
      final newPost = TravelPost(
        id: response['id'],
        title: title,
        subtitle: content.length > 20 ? '${content.substring(0, 20)}...' : content,
        content: content,
        coverImage: images.isNotEmpty ? images.first : '',
        images: images,
        authorId: authorId,
        authorName: authorName,
        authorAvatar: authorAvatar,
        likes: 0,
        tag: tag,
        createdAt: DateTime.parse(response['created_at']),
      );
      
      _posts.insert(0, newPost);
      
    } catch (e) {
      debugPrint('Supabase add post error: $e');
      throw Exception('发布失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 收藏/取消收藏
  Future<void> toggleFavorite(TravelPost post) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final postId = post.id;
    final newFavoritedState = !post.isFavorited;
    
    // 乐观更新 UI
    post.isFavorited = newFavoritedState;
    
    // 同步更新 main list _posts
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1 && _posts[index] != post) {
      _posts[index].isFavorited = newFavoritedState;
    }
    
    notifyListeners();

    if (userId == null || postId == '1') {
      debugPrint('toggleFavorite warning: user not logged in or mock post, skipping DB update');
      return;
    }

    try {
      if (newFavoritedState) {
        // Add to favorites
        await Supabase.instance.client.from('post_favorites').upsert({
          'user_id': userId,
          'post_id': postId,
        });
      } else {
        // Remove from favorites
        await Supabase.instance.client.from('post_favorites').delete()
            .eq('user_id', userId)
            .eq('post_id', postId);
      }
    } catch (e) {
      // 回滚
      post.isFavorited = !newFavoritedState;
      if (index != -1 && _posts[index] != post) {
        _posts[index].isFavorited = !newFavoritedState;
      }
      notifyListeners();
      debugPrint('Supabase toggle favorite error: $e');
    }
  }

  /// 获取个人收藏的帖子列表
  Future<List<TravelPost>> fetchFavoritedPosts() async {
    List<TravelPost> result = [];

    // 先把本地收藏的占位帖子（如果是的话）加进去
    final localFavorites = _posts.where((p) => p.isFavorited && p.id == '1').toList();
    result.addAll(localFavorites);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return result;

    try {
      // Fetch liked and favorited sets to ensure correct UI toggles
      final Set<String> favoritedPostIds = {};
      final Set<String> likedPostIds = {};
      
      final favs = await Supabase.instance.client.from('post_favorites').select('post_id').eq('user_id', userId);
      for (var f in favs) favoritedPostIds.add(f['post_id'].toString());
      
      final likes = await Supabase.instance.client.from('post_likes').select('post_id').eq('user_id', userId);
      for (var l in likes) likedPostIds.add(l['post_id'].toString());

      final response = await Supabase.instance.client
          .from('post_favorites')
          .select('*, posts(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (response.isNotEmpty) {
        final authorIds = response.map((data) => (data['posts'] as Map?)?['user_id']?.toString());
        final usersMap = await _fetchAuthorProfiles(authorIds);

        final dbPosts = response.map<TravelPost>((data) {
          final postData = data['posts'];
          if (postData == null) return TravelPost(id: 'err', title: 'Error', coverImage: '', authorId: '', authorName: '', authorAvatar: '');
          
          final contentStr = postData['content']?.toString() ?? '分享动态';
          final postId = postData['id'].toString();
          final lines = contentStr.split('\n');
          final parsedTitle = lines.isNotEmpty ? lines.first : '分享动态';
          final parsedContent = lines.length > 1 ? lines.sublist(1).join('\n') : contentStr;
          
          final authorId = postData['user_id']?.toString() ?? '';
          final userData = usersMap[authorId];
          final authorName = userData?['nickname'] ?? postData['author_name'] ?? '匿名用户';
          final authorAvatar = userData?['avatar'] ?? postData['author_avatar'] ?? '';
          
          final images = List<String>.from(postData['images'] ?? []);
          final defaultBg = 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&q=80&w=800&h=600';

          return TravelPost(
            id: postId,
            title: parsedTitle,
            subtitle: parsedContent.length > 20 ? '${parsedContent.substring(0, 20)}...' : parsedContent,
            content: parsedContent,
            coverImage: images.isNotEmpty ? images.first : defaultBg,
            images: images,
            authorId: authorId,
            authorName: authorName,
            authorAvatar: authorAvatar,
            likes: postData['likes'] ?? 0,
            tag: postData['location'] ?? '',
            createdAt: postData['created_at'] != null ? DateTime.parse(postData['created_at']) : DateTime.now(),
            isFavorited: favoritedPostIds.contains(postId),
            isLiked: likedPostIds.contains(postId),
          );
        }).where((p) => p.id != 'err').toList();
        
        result.addAll(dbPosts);
      }
    } catch (e) {
      debugPrint('Supabase fetch favorited posts error: $e');
    }
    return result;
  }

  /// 获取帖子的评论列表
  Future<List<PostComment>> loadComments(String postId) async {
    try {
      final response = await Supabase.instance.client
          .from('post_comments')
          .select('*, users(nickname, avatar)')
          .eq('post_id', postId)
          .order('created_at', ascending: true);

      return (response as List).map((data) => PostComment.fromJson(data)).toList();
    } catch (e) {
      debugPrint('Load comments error: $e');
      return [];
    }
  }

  /// 发表评论
  Future<void> addComment(String postId, String content) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('请先登录');

    try {
      await Supabase.instance.client.from('post_comments').insert({
        'post_id': postId,
        'user_id': user.id,
        'content': content,
      });

      // 更新本地帖子列表中的评论数
      final index = _posts.indexWhere((p) => p.id == postId);
      if (index != -1) {
        _posts[index].commentCount++;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Add comment error: $e');
      throw Exception('评论失败');
    }
  }

  /// 记录帖子浏览足迹
  Future<void> recordFootprint(String postId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || postId == '1') return; // Skip for guest or mock post

    try {
      await Supabase.instance.client.from('post_footprints').upsert(
        {
          'user_id': userId,
          'post_id': postId,
          'last_visited_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'user_id,post_id',
      );
    } catch (e) {
      debugPrint('Record footprint error: $e');
    }
  }

  /// 获取用户浏览足迹列表
  Future<List<TravelPost>> fetchFootprints() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      // Fetch liked and favorited sets to ensure correct UI toggles
      final Set<String> favoritedPostIds = {};
      final Set<String> likedPostIds = {};
      
      final favs = await Supabase.instance.client.from('post_favorites').select('post_id').eq('user_id', userId);
      for (var f in favs) favoritedPostIds.add(f['post_id'].toString());
      
      final likes = await Supabase.instance.client.from('post_likes').select('post_id').eq('user_id', userId);
      for (var l in likes) likedPostIds.add(l['post_id'].toString());

      final response = await Supabase.instance.client
          .from('post_footprints')
          .select('*, posts(*)')
          .eq('user_id', userId)
          .order('last_visited_at', ascending: false);

      if (response.isEmpty) return [];

      final authorIds = response.map((data) => (data['posts'] as Map?)?['user_id']?.toString());
      final usersMap = await _fetchAuthorProfiles(authorIds);

      return response.map<TravelPost>((data) {
        final postData = data['posts'];
        if (postData == null) {
          return TravelPost(id: 'err', title: 'Error', coverImage: '', authorId: '', authorName: '', authorAvatar: '');
        }
        final contentStr = postData['content']?.toString() ?? '分享动态';
        final postId = postData['id'].toString();
        final lines = contentStr.split('\n');
        final parsedTitle = lines.isNotEmpty ? lines.first : '分享动态';
        final parsedContent = lines.length > 1 ? lines.sublist(1).join('\n') : contentStr;
        
        final authorId = postData['user_id']?.toString() ?? '';
        final userData = usersMap[authorId];
        final authorName = userData?['nickname'] ?? postData['author_name'] ?? '匿名用户';
        final authorAvatar = userData?['avatar'] ?? postData['author_avatar'] ?? '';
        
        final images = List<String>.from(postData['images'] ?? []);
        final defaultBg = 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&q=80&w=800&h=600';

        return TravelPost(
          id: postId,
          title: parsedTitle,
          subtitle: parsedContent.length > 20 ? '${parsedContent.substring(0, 20)}...' : parsedContent,
          content: parsedContent,
          coverImage: images.isNotEmpty ? images.first : defaultBg,
          images: images,
          authorId: authorId,
          authorName: authorName,
          authorAvatar: authorAvatar,
          likes: postData['likes'] ?? 0,
          tag: postData['location'] ?? '',
          createdAt: postData['created_at'] != null ? DateTime.parse(postData['created_at']) : DateTime.now(),
          isFavorited: favoritedPostIds.contains(postId),
          isLiked: likedPostIds.contains(postId),
        );
      }).where((p) => p.id != 'err').toList();
    } catch (e) {
      debugPrint('Fetch footprints error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _fetchAuthorProfiles(Iterable<String?> userIds) async {
    final Map<String, dynamic> usersMap = {};
    final ids = userIds.where((id) => id != null && id.isNotEmpty).map((e) => e!).toSet().toList();
    if (ids.isEmpty) return usersMap;
    
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, nickname, avatar')
          .inFilter('id', ids);
      for (var u in (response as List)) {
        usersMap[u['id'].toString()] = u;
      }
    } catch (e) {
      debugPrint('Fetch author profiles error: $e');
    }
    return usersMap;
  }
}
