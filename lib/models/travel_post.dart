/// 旅行帖子模型
class TravelPost {
  final String id;
  final String title;
  final String? subtitle;
  final String? content;
  final String coverImage;
  final List<String>? images;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  int likes;
  final String tag;
  final DateTime createdAt;
  bool isLiked;

  TravelPost({
    required this.id,
    required this.title,
    this.subtitle,
    this.content,
    required this.coverImage,
    this.images,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    this.likes = 0,
    this.tag = '',
    DateTime? createdAt,
    this.isLiked = false,
  }) : createdAt = createdAt ?? DateTime.now();

  factory TravelPost.fromJson(Map<String, dynamic> json) {
    return TravelPost(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      content: json['content'],
      coverImage: json['coverImage'] ?? json['image'] ?? '',
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      authorId: json['authorId']?.toString() ?? '',
      authorName: json['authorName'] ?? json['author'] ?? '',
      authorAvatar: json['authorAvatar'] ?? json['avatar'] ?? '',
      likes: json['likes'] ?? 0,
      tag: json['tag'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      isLiked: json['isLiked'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'content': content,
      'coverImage': coverImage,
      'images': images,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'likes': likes,
      'tag': tag,
      'createdAt': createdAt.toIso8601String(),
      'isLiked': isLiked,
    };
  }
}
