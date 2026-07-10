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
    }
  }

  bool get isLocked => this != GuideServiceType.localCompanion;
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
  goToService,
  arrived,
  navigate,
}

extension GuideOrderActionX on GuideOrderAction {
  String get label {
    switch (this) {
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
    required this.imageUrls,
    required this.primaryAction,
    required this.serviceTime,
  });
}
