/// 订单状态枚举
enum OrderStatus {
  pendingPayment, // 待付款
  inProgress,     // 进行中
  pendingReview,  // 待评价
  completed,      // 已完成
  cancelled,      // 已取消
}

/// 订单模型
class Order {
  final String id;
  final String userId;
  final String guideId;
  final String guideName;
  final String guideAvatar;
  final OrderStatus status;
  final double amount;
  final String serviceName;
  final DateTime createdAt;
  final DateTime? serviceDate;

  Order({
    required this.id,
    required this.userId,
    required this.guideId,
    required this.guideName,
    this.guideAvatar = '',
    required this.status,
    required this.amount,
    this.serviceName = '',
    DateTime? createdAt,
    this.serviceDate,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      guideId: json['guideId']?.toString() ?? '',
      guideName: json['guideName'] ?? '',
      guideAvatar: json['guideAvatar'] ?? '',
      status: OrderStatus.values[json['status'] ?? 0],
      amount: (json['amount'] ?? 0).toDouble(),
      serviceName: json['serviceName'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      serviceDate: json['serviceDate'] != null
          ? DateTime.tryParse(json['serviceDate'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'guideId': guideId,
      'guideName': guideName,
      'guideAvatar': guideAvatar,
      'status': status.index,
      'amount': amount,
      'serviceName': serviceName,
      'createdAt': createdAt.toIso8601String(),
      'serviceDate': serviceDate?.toIso8601String(),
    };
  }

  String get statusLabel {
    switch (status) {
      case OrderStatus.pendingPayment:
        return '待付款';
      case OrderStatus.inProgress:
        return '进行中';
      case OrderStatus.pendingReview:
        return '待评价';
      case OrderStatus.completed:
        return '已完成';
      case OrderStatus.cancelled:
        return '已取消';
    }
  }
}
