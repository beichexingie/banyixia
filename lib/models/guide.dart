/// 地陪（本地向导）模型
class Guide {
  final String id;
  final String name;
  final String avatar;
  final double rating;
  final String gender; // '男' / '女'
  final bool verified;
  final List<String> tags;
  final String description;
  final List<String> images;
  final int views;
  final int likes;
  final int fans;
  final String city;

  Guide({
    required this.id,
    required this.name,
    required this.avatar,
    this.rating = 0.0,
    this.gender = '',
    this.verified = false,
    this.tags = const [],
    this.description = '',
    this.images = const [],
    this.views = 0,
    this.likes = 0,
    this.fans = 0,
    this.city = '',
  });

  factory Guide.fromJson(Map<String, dynamic> json) {
    return Guide(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar'] ?? '',
      rating: (json['rating'] ?? 0).toDouble(),
      gender: json['gender'] ?? '',
      verified: json['verified'] ?? false,
      tags: List<String>.from(json['tags'] ?? []),
      description: json['description'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      views: json['views'] ?? 0,
      likes: json['likes'] ?? 0,
      fans: json['fans'] ?? 0,
      city: json['city'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'rating': rating,
      'gender': gender,
      'verified': verified,
      'tags': tags,
      'description': description,
      'images': images,
      'views': views,
      'likes': likes,
      'fans': fans,
      'city': city,
    };
  }
}
