/// 用户模型
class User {
  final String id;
  final String nickname;
  final String avatar;
  final String bio;
  final String gender;
  final String city;
  final String birthday;
  final String wechat;
  final String occupation;
  final String guideIntroduction;
  final List<String> guideTags;
  final int vipLevel;
  final String title;
  final double balance;
  final int couponCount;
  final int followCount;
  final int fansCount;
  final bool isBanned;
  final int cancelCount;
  final bool isAdmin;
  final bool isGuide;
  final String? guideApplicationStatus;

  User({
    required this.id,
    required this.nickname,
    this.avatar = '',
    this.bio = '',
    this.gender = '',
    this.city = '',
    this.birthday = '',
    this.wechat = '',
    this.occupation = '',
    this.guideIntroduction = '',
    this.guideTags = const [],
    this.vipLevel = 0,
    this.title = '',
    this.balance = 0.0,
    this.couponCount = 0,
    this.followCount = 0,
    this.fansCount = 0,
    this.isBanned = false,
    this.cancelCount = 0,
    this.isAdmin = false,
    this.isGuide = false,
    this.guideApplicationStatus,
  });

  factory User.guest() {
    return User(id: '', nickname: '未登录');
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      bio: json['bio'] ?? '',
      gender: json['gender'] ?? '',
      city: json['city'] ?? '',
      birthday: json['birthday'] ?? '',
      wechat: json['wechat'] ?? '',
      occupation: json['occupation'] ?? '',
      guideIntroduction:
          json['guideIntroduction'] ?? json['guide_introduction'] ?? '',
      guideTags: List<String>.from(
        json['guideTags'] ?? json['guide_tags'] ?? const [],
      ),
      vipLevel: json['vipLevel'] ?? json['vip_level'] ?? 0,
      title: json['title'] ?? '',
      balance: _parseDouble(json['balance']) ?? 0,
      couponCount: json['couponCount'] ?? json['coupon_count'] ?? 0,
      followCount: json['followCount'] ?? json['follow_count'] ?? 0,
      fansCount: json['fansCount'] ?? json['fans_count'] ?? 0,
      isBanned: json['is_banned'] ?? false,
      cancelCount: json['cancel_count'] ?? 0,
      isAdmin: json['is_admin'] ?? false,
      isGuide: json['is_guide'] ?? false,
      guideApplicationStatus: json['guide_application_status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar': avatar,
      'bio': bio,
      'gender': gender,
      'city': city,
      'birthday': birthday,
      'wechat': wechat,
      'occupation': occupation,
      'guide_introduction': guideIntroduction,
      'guide_tags': guideTags,
      'vip_level': vipLevel,
      'vipLevel': vipLevel,
      'title': title,
      'balance': balance,
      'coupon_count': couponCount,
      'couponCount': couponCount,
      'follow_count': followCount,
      'followCount': followCount,
      'fans_count': fansCount,
      'fansCount': fansCount,
      'is_banned': isBanned,
      'cancel_count': cancelCount,
      'is_admin': isAdmin,
      'is_guide': isGuide,
      'guide_application_status': guideApplicationStatus,
    };
  }

  User copyWith({
    String? nickname,
    String? avatar,
    String? bio,
    String? gender,
    String? city,
    String? birthday,
    String? wechat,
    String? occupation,
    String? guideIntroduction,
    List<String>? guideTags,
  }) {
    return User(
      id: id,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      city: city ?? this.city,
      birthday: birthday ?? this.birthday,
      wechat: wechat ?? this.wechat,
      occupation: occupation ?? this.occupation,
      guideIntroduction: guideIntroduction ?? this.guideIntroduction,
      guideTags: guideTags ?? this.guideTags,
      vipLevel: vipLevel,
      title: title,
      balance: balance,
      couponCount: couponCount,
      followCount: followCount,
      fansCount: fansCount,
      isBanned: isBanned,
      cancelCount: cancelCount,
      isAdmin: isAdmin,
      isGuide: isGuide,
      guideApplicationStatus: guideApplicationStatus,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  bool get isLoggedIn => id.isNotEmpty;
  bool get hasPendingGuideApplication => guideApplicationStatus == 'pending';
  bool get hasRejectedGuideApplication => guideApplicationStatus == 'rejected';
  bool get isGuideApproved => isGuide || guideApplicationStatus == 'approved';
  bool get canAccessAdmin => isLoggedIn && isAdmin && !isBanned;
  bool get canApplyAsGuide =>
      isLoggedIn &&
      !isBanned &&
      !isGuideApproved &&
      !hasPendingGuideApplication;

  String get identityLabel {
    if (isAdmin && isGuideApproved) return '管理员 / 认证地陪';
    if (isAdmin) return '管理员';
    if (isGuideApproved) return '认证地陪';
    if (hasPendingGuideApplication) return '地陪审核中';
    return '普通用户';
  }

  String get vipLabel => vipLevel > 0 ? 'VIP$vipLevel' : '';
}
