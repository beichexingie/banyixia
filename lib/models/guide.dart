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
  final List<Map<String, dynamic>> serviceItems;
  final List<Map<String, dynamic>> reviews;
  final int totalOrders;
  final int completedOrders;
  final double goodRate;
  final String ethnicity;
  final String education;
  final double heightCm;
  final double weightKg;
  final String serviceDescription;
  final String extraFeeDescription;
  final double? currentLat;
  final double? currentLng;
  final String currentLocationText;

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
    this.serviceItems = const [],
    this.reviews = const [],
    this.totalOrders = 0,
    this.completedOrders = 0,
    this.goodRate = 0,
    this.ethnicity = '',
    this.education = '',
    this.heightCm = 0,
    this.weightKg = 0,
    this.serviceDescription = '',
    this.extraFeeDescription = '',
    this.currentLat,
    this.currentLng,
    this.currentLocationText = '',
  });

  factory Guide.fromJson(Map<String, dynamic> json) {
    return Guide(
      id: _asString(json['id']),
      name: _asString(json['name']),
      avatar: _asString(json['avatar']),
      rating: _parseDouble(json['rating']) ?? 0,
      gender: _asString(json['gender']),
      verified: _asBool(json['verified']),
      tags: _strings(json['tags']),
      description: _asString(json['description']),
      images: _strings(json['images']),
      views: _asInt(json['views']),
      likes: _asInt(json['likes']),
      fans: _asInt(json['fans']),
      city: _asString(json['city']),
      serviceItems: _maps(json['service_items']),
      reviews: _maps(json['reviews']),
      totalOrders: _asInt(json['total_orders'] ?? json['totalOrders']),
      completedOrders: _asInt(
        json['completed_orders'] ?? json['completedOrders'],
      ),
      goodRate: _parseDouble(json['good_rate'] ?? json['goodRate']) ?? 0,
      ethnicity: _asString(json['ethnicity']),
      education: _asString(json['education']),
      heightCm: _parseDouble(json['height_cm'] ?? json['heightCm']) ?? 0,
      weightKg: _parseDouble(json['weight_kg'] ?? json['weightKg']) ?? 0,
      serviceDescription: _asString(json['service_description']),
      extraFeeDescription: _asString(json['extra_fee_description']),
      currentLat: _parseDouble(
        json['current_lat'] ?? json['guide_current_lat'],
      ),
      currentLng: _parseDouble(
        json['current_lng'] ?? json['guide_current_lng'],
      ),
      currentLocationText: _asString(json['current_location_text']),
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
      'service_items': serviceItems,
      'reviews': reviews,
      'total_orders': totalOrders,
      'completed_orders': completedOrders,
      'good_rate': goodRate,
      'ethnicity': ethnicity,
      'education': education,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'service_description': serviceDescription,
      'extra_fee_description': extraFeeDescription,
      'current_lat': currentLat,
      'current_lng': currentLng,
      'current_location_text': currentLocationText,
    };
  }

  static double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  static List<String> _strings(dynamic raw) {
    if (raw is List) {
      return raw
          .where((item) => item != null)
          .map((item) => item.toString())
          .toList();
    }
    if (raw == null) return const [];
    final value = raw.toString().trim();
    return value.isEmpty ? const [] : [value];
  }

  static List<Map<String, dynamic>> _maps(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }
}
