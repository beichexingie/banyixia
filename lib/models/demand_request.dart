class DemandRequest {
  final String id;
  final String title;
  final String content;
  final String city;
  final String location;
  final DateTime serviceStartAt;
  final DateTime serviceEndAt;
  final int peopleCount;
  final String gender;
  final String budget;
  final String status;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final List<String> images;
  final List<String> tags;
  final int applicantCount;
  final DateTime createdAt;

  const DemandRequest({
    required this.id,
    required this.title,
    required this.content,
    required this.city,
    required this.location,
    required this.serviceStartAt,
    required this.serviceEndAt,
    required this.peopleCount,
    required this.gender,
    required this.budget,
    required this.status,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    this.images = const [],
    this.tags = const [],
    this.applicantCount = 0,
    required this.createdAt,
  });

  factory DemandRequest.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value, {DateTime? fallback}) {
      if (value == null) return fallback ?? DateTime.now();
      if (value is DateTime) return value;
      return DateTime.tryParse(value.toString()) ??
          (fallback ?? DateTime.now());
    }

    return DemandRequest(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      city: json['city'] ?? '',
      location: json['location'] ?? '',
      serviceStartAt: parseDate(json['service_start_at']),
      serviceEndAt: parseDate(
        json['service_end_at'],
        fallback: parseDate(json['service_start_at']),
      ),
      peopleCount: json['people_count'] is num
          ? (json['people_count'] as num).toInt()
          : int.tryParse(json['people_count']?.toString() ?? '') ?? 1,
      gender: json['gender'] ?? '不限',
      budget: json['budget'] ?? '',
      status: json['status'] ?? 'open',
      authorId: json['author_id']?.toString() ?? '',
      authorName: json['author_name'] ?? '匿名用户',
      authorAvatar: json['author_avatar'] ?? '',
      images: List<String>.from(json['images'] ?? const []),
      tags: List<String>.from(json['tags'] ?? const []),
      applicantCount: json['applicant_count'] is num
          ? (json['applicant_count'] as num).toInt()
          : int.tryParse(json['applicant_count']?.toString() ?? '') ?? 0,
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'city': city,
      'location': location,
      'service_start_at': serviceStartAt.toIso8601String(),
      'service_end_at': serviceEndAt.toIso8601String(),
      'people_count': peopleCount,
      'gender': gender,
      'budget': budget,
      'status': status,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'images': images,
      'tags': tags,
      'applicant_count': applicantCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DemandRequest copyWith({
    String? id,
    String? title,
    String? content,
    String? city,
    String? location,
    DateTime? serviceStartAt,
    DateTime? serviceEndAt,
    int? peopleCount,
    String? gender,
    String? budget,
    String? status,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    List<String>? images,
    List<String>? tags,
    int? applicantCount,
    DateTime? createdAt,
  }) {
    return DemandRequest(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      city: city ?? this.city,
      location: location ?? this.location,
      serviceStartAt: serviceStartAt ?? this.serviceStartAt,
      serviceEndAt: serviceEndAt ?? this.serviceEndAt,
      peopleCount: peopleCount ?? this.peopleCount,
      gender: gender ?? this.gender,
      budget: budget ?? this.budget,
      status: status ?? this.status,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      images: images ?? this.images,
      tags: tags ?? this.tags,
      applicantCount: applicantCount ?? this.applicantCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get timeLabel {
    final start =
        '${serviceStartAt.month}月${serviceStartAt.day}日 ${serviceStartAt.hour.toString().padLeft(2, '0')}:${serviceStartAt.minute.toString().padLeft(2, '0')}';
    final end =
        '${serviceEndAt.month}月${serviceEndAt.day}日 ${serviceEndAt.hour.toString().padLeft(2, '0')}:${serviceEndAt.minute.toString().padLeft(2, '0')}';
    return '$start - $end';
  }
}
