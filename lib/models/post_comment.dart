import '../utils/time_utils.dart';

class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String userAvatar;
  final String replyToUserId;
  final String replyToUserName;
  final String replyToUserAvatar;
  final String content;
  final DateTime createdAt;
  final int likeCount;
  final bool isLiked;
  final String parentCommentId;
  final String replyToCommentId;

  PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    this.replyToUserId = '',
    this.replyToUserName = '',
    this.replyToUserAvatar = '',
    required this.content,
    required this.createdAt,
    this.likeCount = 0,
    this.isLiked = false,
    this.parentCommentId = '',
    this.replyToCommentId = '',
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    final nestedUser =
        _asMap(json['users']) ??
        _asMap(json['user']) ??
        _asMap(json['profiles']) ??
        _asMap(json['profile']);

    return PostComment(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      parentCommentId: json['parent_comment_id']?.toString() ?? '',
      replyToCommentId: json['reply_to_comment_id']?.toString() ?? '',
      userName:
          _firstNonEmptyString([
            nestedUser?['nickname'],
            nestedUser?['name'],
            json['nickname'],
            json['user_name'],
            json['userName'],
            json['author_name'],
            json['authorName'],
          ]) ??
          '匿名用户',
      userAvatar:
          _firstNonEmptyString([
            nestedUser?['avatar'],
            nestedUser?['avatar_url'],
            nestedUser?['photo_url'],
            json['avatar'],
            json['user_avatar'],
            json['userAvatar'],
            json['author_avatar'],
            json['authorAvatar'],
          ]) ??
          '',
      replyToUserId: json['reply_to_user_id']?.toString() ?? '',
      replyToUserName:
          _firstNonEmptyString([
            json['reply_to_user_name'],
            json['replyToUserName'],
          ]) ??
          '',
      replyToUserAvatar:
          _firstNonEmptyString([
            json['reply_to_user_avatar'],
            json['replyToUserAvatar'],
          ]) ??
          '',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      likeCount:
          _parseInt(json['likeCount']) ??
          _parseInt(json['likes']) ??
          _parseInt(json['like_count']) ??
          0,
      isLiked:
          _parseBool(json['is_liked']) ?? _parseBool(json['isLiked']) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'user_id': userId,
      'parent_comment_id': parentCommentId,
      'reply_to_comment_id': replyToCommentId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'likeCount': likeCount,
      'is_liked': isLiked,
    };
  }

  PostComment copyWith({
    String? id,
    String? postId,
    String? userId,
    String? userName,
    String? userAvatar,
    String? replyToUserId,
    String? replyToUserName,
    String? replyToUserAvatar,
    String? content,
    DateTime? createdAt,
    int? likeCount,
    bool? isLiked,
    String? parentCommentId,
    String? replyToCommentId,
  }) {
    return PostComment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      replyToUserId: replyToUserId ?? this.replyToUserId,
      replyToUserName: replyToUserName ?? this.replyToUserName,
      replyToUserAvatar: replyToUserAvatar ?? this.replyToUserAvatar,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      replyToCommentId: replyToCommentId ?? this.replyToCommentId,
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    return value is Map<String, dynamic> ? value : null;
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

  String get timeLabel => TimeUtils.format(createdAt);
}
