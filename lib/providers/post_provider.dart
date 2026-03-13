import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/travel_post.dart';

/// 旅行帖子状态管理
class PostProvider extends ChangeNotifier {
  List<TravelPost> _posts = [];
  bool _isLoading = false;

  List<TravelPost> get posts => _posts;
  bool get isLoading => _isLoading;

  /// 加载帖子列表（优先从云端获取）
  Future<void> loadPosts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await Supabase.instance.client
          .from('posts')
          .select()
          .order('created_at', ascending: false);

      if (response.isNotEmpty) {
        // Fetch current user's favorites to sync isFavorited state
        final userId = Supabase.instance.client.auth.currentUser?.id;
        final Set<String> favoritedPostIds = {};
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
        }

        _posts = response.map<TravelPost>((data) {
          final contentStr = data['content']?.toString() ?? '分享动态';
          final postId = data['id'].toString();
          return TravelPost(
            id: postId,
            title: contentStr.length > 10 ? contentStr.substring(0, 10).split('\n').first : contentStr,
            subtitle: contentStr.length > 20 ? '${contentStr.substring(0, 20)}...' : contentStr,
            content: contentStr,
            coverImage: (data['images'] != null && (data['images'] as List).isNotEmpty) ? (data['images'] as List).first : '',
            images: List<String>.from(data['images'] ?? []),
            authorId: data['user_id'] ?? '',
            authorName: data['author_name'] ?? '匿名用户',
            authorAvatar: data['author_avatar'] ?? '',
            likes: data['likes'] ?? 0,
            tag: data['location'] ?? '',
            createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : DateTime.now(),
            isFavorited: favoritedPostIds.contains(postId),
          );
        }).toList();
      } else {
        _loadMockPosts();
      }
    } catch (e) {
      debugPrint('Supabase fetch posts error: $e');
      _loadMockPosts();
    }

    _isLoading = false;
    notifyListeners();
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

    try {
      // Warning: if RLS policy prevents update of other's posts, this will fail silently and rollback UI
      await Supabase.instance.client.from('posts').update({
        'likes': post.likes,
      }).eq('id', postId);
    } catch (e) {
      // 失败回滚
      post.isLiked = !newLikedState;
      post.likes -= newLikedState ? 1 : -1;
      if (index != -1 && _posts[index] != post) {
        _posts[index].isLiked = !newLikedState;
        _posts[index].likes -= newLikedState ? 1 : -1;
      }
      notifyListeners();
      debugPrint('Supabase toggle like error: $e');
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
        await Supabase.instance.client.from('post_favorites').insert({
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
      final response = await Supabase.instance.client
          .from('post_favorites')
          .select('..., posts(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (response.isNotEmpty) {
        final dbPosts = response.map<TravelPost>((data) {
          final postData = data['posts'];
          if (postData == null) return TravelPost(id: 'err', title: 'Error', coverImage: '', authorId: '', authorName: '', authorAvatar: '');
          
          final contentStr = postData['content']?.toString() ?? '分享动态';
          return TravelPost(
            id: postData['id'].toString(),
            title: contentStr.length > 10 ? contentStr.substring(0, 10).split('\n').first : contentStr,
            subtitle: contentStr.length > 20 ? '${contentStr.substring(0, 20)}...' : contentStr,
            content: contentStr,
            coverImage: (postData['images'] != null && (postData['images'] as List).isNotEmpty) ? (postData['images'] as List).first : '',
            images: List<String>.from(postData['images'] ?? []),
            authorId: postData['user_id'] ?? '',
            authorName: postData['author_name'] ?? '匿名用户',
            authorAvatar: postData['author_avatar'] ?? '',
            likes: postData['likes'] ?? 0,
            tag: postData['location'] ?? '',
            createdAt: postData['created_at'] != null ? DateTime.parse(postData['created_at']) : DateTime.now(),
            isFavorited: true, // It is in the favorites table
          );
        }).where((p) => p.id != 'err').toList();
        
        result.addAll(dbPosts);
      }
    } catch (e) {
      debugPrint('Supabase fetch favorited posts error: $e');
    }
    return result;
  }
}
