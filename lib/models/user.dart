/// 用户模型
class User {
  final String id;
  final String nickname;
  final String avatar;
  final int vipLevel;
  final String title; // 身份称号，如"资深玩家"
  final double balance;
  final int couponCount;
  final int followCount;
  final int fansCount;

  User({
    required this.id,
    required this.nickname,
    this.avatar = '',
    this.vipLevel = 0,
    this.title = '',
    this.balance = 0.0,
    this.couponCount = 0,
    this.followCount = 0,
    this.fansCount = 0,
  });

  /// 默认未登录用户
  factory User.guest() {
    return User(
      id: '',
      nickname: '未登录',
    );
  }

  /// 从 JSON 构造（后续对接 API 用）
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      nickname: json['nickname'] ?? '',
      avatar: json['avatar'] ?? '',
      vipLevel: json['vipLevel'] ?? 0,
      title: json['title'] ?? '',
      balance: (json['balance'] ?? 0).toDouble(),
      couponCount: json['couponCount'] ?? 0,
      followCount: json['followCount'] ?? 0,
      fansCount: json['fansCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nickname': nickname,
      'avatar': avatar,
      'vipLevel': vipLevel,
      'title': title,
      'balance': balance,
      'couponCount': couponCount,
      'followCount': followCount,
      'fansCount': fansCount,
    };
  }

  bool get isLoggedIn => id.isNotEmpty;

  String get vipLabel => vipLevel > 0 ? 'VIP$vipLevel' : '';
}
