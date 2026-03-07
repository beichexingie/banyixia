import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .get();

      if (snapshot.docs.isNotEmpty) {
        _posts = snapshot.docs.map((doc) {
          final data = doc.data();
          return TravelPost(
            id: doc.id,
            title: data['title'] ?? '',
            subtitle: data['subtitle'],
            content: data['content'],
            coverImage: data['coverImage'] ?? '',
            images: List<String>.from(data['images'] ?? []),
            authorId: data['authorId'] ?? '',
            authorName: data['authorName'] ?? '匿名用户',
            authorAvatar: data['authorAvatar'] ?? '',
            likes: data['likes'] ?? 0,
            tag: data['tag'] ?? '',
            createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : DateTime.now(),
          );
        }).toList();
        
        // 简单处理前端点赞状态（实际业务需用户关联的 likes 表记录）
        // 这里只是为了避免覆盖列表原有点赞状态的复杂性做个简化
      } else {
        _loadMockPosts();
      }
    } catch (e) {
      debugPrint('Firestore fetch posts error: $e');
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
  Future<void> toggleLike(String postId) async {
    final index = _posts.indexWhere((p) => p.id == postId);
    if (index != -1) {
      final post = _posts[index];
      final newLikedState = !post.isLiked;
      
      // 乐观更新 UI
      _posts[index].isLiked = newLikedState;
      _posts[index].likes += newLikedState ? 1 : -1;
      notifyListeners();

      try {
        await FirebaseFirestore.instance.collection('posts').doc(postId).update({
          'likes': FieldValue.increment(newLikedState ? 1 : -1),
        });
      } catch (e) {
        // 如果失败，回滚状态
        _posts[index].isLiked = !newLikedState;
        _posts[index].likes -= newLikedState ? 1 : -1;
        notifyListeners();
        debugPrint('Firestore toggle like error: $e');
      }
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
      final docRef = await FirebaseFirestore.instance.collection('posts').add({
        'title': title,
        'subtitle': content.length > 20 ? '${content.substring(0, 20)}...' : content,
        'content': content,
        'coverImage': images.isNotEmpty ? images.first : '',
        'images': images,
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
        'likes': 0,
        'tag': tag,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 成功后插入到本地首位并刷新 UI
      final newPost = TravelPost(
        id: docRef.id,
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
        createdAt: DateTime.now(),
      );
      
      _posts.insert(0, newPost);
      
    } catch (e) {
      debugPrint('Firestore add post error: $e');
      throw Exception('发布失败: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
