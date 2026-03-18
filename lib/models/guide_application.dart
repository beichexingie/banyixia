/// 地陪申请模型
class GuideApplication {
  final String id;
  final String userId;
  final String fullName;
  final String? idCardNum;
  final String? gender;
  final String? city;
  final String? avatar;
  final String? bio;
  final List<String> serviceTags;
  final List<String> images;
  final String status; // 'pending', 'approved', 'rejected'
  final String? rejectReason;
  final DateTime createdAt;

  GuideApplication({
    required this.id,
    required this.userId,
    required this.fullName,
    this.idCardNum,
    this.gender,
    this.city,
    this.avatar,
    this.bio,
    this.serviceTags = const [],
    this.images = const [],
    this.status = 'pending',
    this.rejectReason,
    required this.createdAt,
  });

  factory GuideApplication.fromJson(Map<String, dynamic> json) {
    return GuideApplication(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name'] ?? '',
      idCardNum: json['id_card_num'],
      gender: json['gender'],
      city: json['city'],
      avatar: json['avatar'],
      bio: json['bio'],
      serviceTags: List<String>.from(json['service_tags'] ?? []),
      images: List<String>.from(json['images'] ?? []),
      status: json['status'] ?? 'pending',
      rejectReason: json['reject_reason'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'id_card_num': idCardNum,
      'gender': gender,
      'city': city,
      'avatar': avatar,
      'bio': bio,
      'service_tags': serviceTags,
      'images': images,
      'status': status,
    };
  }
}
