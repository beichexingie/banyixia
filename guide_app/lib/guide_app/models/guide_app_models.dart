import 'package:flutter/material.dart';

enum GuideDutyMode {
  nearby,
  sameCity,
  crossCity,
}

extension GuideDutyModeX on GuideDutyMode {
  String get label {
    switch (this) {
      case GuideDutyMode.nearby:
        return '近单模式';
      case GuideDutyMode.sameCity:
        return '同城模式';
      case GuideDutyMode.crossCity:
        return '跨城模式';
    }
  }

  String get rangeLabel {
    switch (this) {
      case GuideDutyMode.nearby:
        return '5公里';
      case GuideDutyMode.sameCity:
        return '当前所在城市';
      case GuideDutyMode.crossCity:
        return '所有接单城市';
    }
  }

  String get description {
    switch (this) {
      case GuideDutyMode.nearby:
        return '优先展示近单，按距离从近到远展示';
      case GuideDutyMode.sameCity:
        return '优先展示同城订单，适合常驻服务';
      case GuideDutyMode.crossCity:
        return '展示已开通城市的订单，适合跨城接单';
    }
  }
}

enum GuideServiceType {
  localCompanion,
  customTrip,
  errandHelp,
  foodie,
  cityWalk,
  storeVisit,
  localPlay,
  movieShow,
  campingDrive,
  amusementPark,
  boardGame,
  escapeRoom,
  billiards,
  gamePartner,
  shoppingQueue,
  hiking,
  jogging,
  fitness,
  wellness,
  cycling,
  surfing,
  badminton,
  tennis,
  golf,
  swimming,
  archery,
  climbing,
  drinks,
  karaoke,
  businessReception,
  performance,
  etiquetteExpo,
  listening,
  eventHost,
  translation,
  medicalEscort,
  teaArt,
  assistant,
  businessDriver,
}

extension GuideServiceTypeX on GuideServiceType {
  String get label {
    switch (this) {
      case GuideServiceType.localCompanion:
        return '地陪单';
      case GuideServiceType.customTrip:
        return '定制单';
      case GuideServiceType.errandHelp:
        return '帮忙单';
      case GuideServiceType.foodie:
        return '老吃家';
      case GuideServiceType.cityWalk:
        return '城市漫步';
      case GuideServiceType.storeVisit:
        return '打卡探店';
      case GuideServiceType.localPlay:
        return '本地陪玩';
      case GuideServiceType.movieShow:
        return '观影赏剧';
      case GuideServiceType.campingDrive:
        return '露营自驾';
      case GuideServiceType.amusementPark:
        return '游乐园';
      case GuideServiceType.boardGame:
        return '桌游娱乐';
      case GuideServiceType.escapeRoom:
        return '剧本密室';
      case GuideServiceType.billiards:
        return '桌球陪练';
      case GuideServiceType.gamePartner:
        return '开黑搭子';
      case GuideServiceType.shoppingQueue:
        return '代排购物';
      case GuideServiceType.hiking:
        return '徒步爬山';
      case GuideServiceType.jogging:
        return '轻氧慢跑';
      case GuideServiceType.fitness:
        return '健身陪同';
      case GuideServiceType.wellness:
        return '养生气功';
      case GuideServiceType.cycling:
        return '骑行竞走';
      case GuideServiceType.surfing:
        return '滑板冲浪';
      case GuideServiceType.badminton:
        return '羽毛球';
      case GuideServiceType.tennis:
        return '网球';
      case GuideServiceType.golf:
        return '高尔夫';
      case GuideServiceType.swimming:
        return '游泳';
      case GuideServiceType.archery:
        return '射箭击靶';
      case GuideServiceType.climbing:
        return '攀岩登壁';
      case GuideServiceType.drinks:
        return '微醺小酌';
      case GuideServiceType.karaoke:
        return '欢乐K歌';
      case GuideServiceType.businessReception:
        return '商务接待';
      case GuideServiceType.performance:
        return '乐器表演';
      case GuideServiceType.etiquetteExpo:
        return '礼仪展会';
      case GuideServiceType.listening:
        return '树洞倾诉';
      case GuideServiceType.eventHost:
        return '会务主持';
      case GuideServiceType.translation:
        return '专业翻译';
      case GuideServiceType.medicalEscort:
        return '医疗陪同';
      case GuideServiceType.teaArt:
        return '茶艺师';
      case GuideServiceType.assistant:
        return '秘书助理';
      case GuideServiceType.businessDriver:
        return '商务司机';
    }
  }

  String get description {
    switch (this) {
      case GuideServiceType.localCompanion:
        return '为客户提供“本地陪同”服务，可在规定范围内自定价格';
      case GuideServiceType.customTrip:
        return '定制单为客户提供“定制陪同”服务，单价高';
      case GuideServiceType.errandHelp:
        return '为客户提供“帮忙”服务，可帮忙“代排”等更多服务类型';
      default:
        return '展示在地陪主页与服务列表中，方便用户按具体服务能力筛选和下单。';
    }
  }

  IconData get icon {
    switch (this) {
      case GuideServiceType.localCompanion:
        return Icons.flag_rounded;
      case GuideServiceType.customTrip:
        return Icons.sell_rounded;
      case GuideServiceType.errandHelp:
        return Icons.volunteer_activism_rounded;
      case GuideServiceType.foodie:
        return Icons.restaurant_outlined;
      case GuideServiceType.cityWalk:
        return Icons.directions_walk;
      case GuideServiceType.storeVisit:
        return Icons.storefront_outlined;
      case GuideServiceType.localPlay:
        return Icons.map_outlined;
      case GuideServiceType.movieShow:
        return Icons.palette_outlined;
      case GuideServiceType.campingDrive:
        return Icons.directions_car_outlined;
      case GuideServiceType.amusementPark:
        return Icons.attractions_outlined;
      case GuideServiceType.boardGame:
        return Icons.dashboard_customize_outlined;
      case GuideServiceType.escapeRoom:
        return Icons.rocket_launch_outlined;
      case GuideServiceType.billiards:
        return Icons.sports_baseball_outlined;
      case GuideServiceType.gamePartner:
        return Icons.sports_esports_outlined;
      case GuideServiceType.shoppingQueue:
        return Icons.shopping_bag_outlined;
      case GuideServiceType.hiking:
        return Icons.hiking_outlined;
      case GuideServiceType.jogging:
        return Icons.directions_run;
      case GuideServiceType.fitness:
        return Icons.fitness_center;
      case GuideServiceType.wellness:
        return Icons.self_improvement_outlined;
      case GuideServiceType.cycling:
        return Icons.pedal_bike_outlined;
      case GuideServiceType.surfing:
        return Icons.surfing_outlined;
      case GuideServiceType.badminton:
        return Icons.sports_tennis_outlined;
      case GuideServiceType.tennis:
        return Icons.sports_baseball_outlined;
      case GuideServiceType.golf:
        return Icons.golf_course_outlined;
      case GuideServiceType.swimming:
        return Icons.pool_outlined;
      case GuideServiceType.archery:
        return Icons.ads_click_outlined;
      case GuideServiceType.climbing:
        return Icons.filter_hdr_outlined;
      case GuideServiceType.drinks:
        return Icons.sports_bar_outlined;
      case GuideServiceType.karaoke:
        return Icons.mic_external_on_outlined;
      case GuideServiceType.businessReception:
        return Icons.record_voice_over_outlined;
      case GuideServiceType.performance:
        return Icons.music_note_outlined;
      case GuideServiceType.etiquetteExpo:
        return Icons.apartment_outlined;
      case GuideServiceType.listening:
        return Icons.favorite_border;
      case GuideServiceType.eventHost:
        return Icons.support_agent_outlined;
      case GuideServiceType.translation:
        return Icons.translate_outlined;
      case GuideServiceType.medicalEscort:
        return Icons.local_hospital_outlined;
      case GuideServiceType.teaArt:
        return Icons.spa_outlined;
      case GuideServiceType.assistant:
        return Icons.badge_outlined;
      case GuideServiceType.businessDriver:
        return Icons.local_taxi_outlined;
    }
  }

  bool get isLocked => false;
}

enum GuideOrderStage {
  newOrder,
  pendingPayment,
  inProgress,
}

extension GuideOrderStageX on GuideOrderStage {
  String get label {
    switch (this) {
      case GuideOrderStage.newOrder:
        return '新订单';
      case GuideOrderStage.pendingPayment:
        return '待付款';
      case GuideOrderStage.inProgress:
        return '进行中';
    }
  }
}

enum GuideOrderAction {
  accept,
  waitingPayment,
  goToService,
  arrived,
  navigate,
}

extension GuideOrderActionX on GuideOrderAction {
  String get label {
    switch (this) {
      case GuideOrderAction.accept:
        return '接单';
      case GuideOrderAction.waitingPayment:
        return '等待付款';
      case GuideOrderAction.goToService:
        return '前往服务地点';
      case GuideOrderAction.arrived:
        return '到达服务地点';
      case GuideOrderAction.navigate:
        return '查看路线';
    }
  }

  IconData get icon {
    switch (this) {
      case GuideOrderAction.accept:
        return Icons.check_circle_rounded;
      case GuideOrderAction.waitingPayment:
        return Icons.hourglass_top_rounded;
      case GuideOrderAction.goToService:
        return Icons.near_me_rounded;
      case GuideOrderAction.arrived:
        return Icons.location_on_rounded;
      case GuideOrderAction.navigate:
        return Icons.alt_route_rounded;
    }
  }
}

class GuideWorkbenchStats {
  final int totalOrders;
  final int completedOrders;
  final int positiveReviews;
  final int cancelOrders;
  final int cancellationRate;

  const GuideWorkbenchStats({
    required this.totalOrders,
    required this.completedOrders,
    required this.positiveReviews,
    required this.cancelOrders,
    required this.cancellationRate,
  });
}

class GuideAddress {
  final String city;
  final String title;
  final String detail;
  final String contactName;
  final String maskedPhone;

  const GuideAddress({
    required this.city,
    required this.title,
    required this.detail,
    required this.contactName,
    required this.maskedPhone,
  });

  String get summary => '$city$title';

  Map<String, String> toJson() => {
        'city': city,
        'title': title,
        'detail': detail,
        'contactName': contactName,
        'maskedPhone': maskedPhone,
      };

  factory GuideAddress.fromJson(Map<String, dynamic> json) {
    return GuideAddress(
      city: json['city']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      detail: json['detail']?.toString() ?? '',
      contactName: json['contactName']?.toString() ?? '',
      maskedPhone: json['maskedPhone']?.toString() ?? '',
    );
  }
}

class GuideServiceOption {
  final String id;
  final String name;
  final String description;
  final double pricePerDay;
  final String imageUrl;
  final int count;

  const GuideServiceOption({
    required this.id,
    required this.name,
    required this.description,
    required this.pricePerDay,
    required this.imageUrl,
    this.count = 0,
  });

  GuideServiceOption copyWith({
    String? id,
    String? name,
    String? description,
    double? pricePerDay,
    String? imageUrl,
    int? count,
  }) {
    return GuideServiceOption(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      imageUrl: imageUrl ?? this.imageUrl,
      count: count ?? this.count,
    );
  }
}

class GuideDashboardShortcut {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const GuideDashboardShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

class GuideTaskCard {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;

  const GuideTaskCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });
}

class GuideOrderCardData {
  final String id;
  final GuideOrderStage stage;
  final String serviceLabel;
  final String etaText;
  final String distanceText;
  final double amount;
  final String content;
  final String address;
  final String serviceCity;
  final double? serviceLat;
  final double? serviceLng;
  final List<String> imageUrls;
  final GuideOrderAction primaryAction;
  final DateTime serviceTime;

  const GuideOrderCardData({
    required this.id,
    required this.stage,
    required this.serviceLabel,
    required this.etaText,
    required this.distanceText,
    required this.amount,
    required this.content,
    required this.address,
    this.serviceCity = '',
    this.serviceLat,
    this.serviceLng,
    required this.imageUrls,
    required this.primaryAction,
    required this.serviceTime,
  });
}
