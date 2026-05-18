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
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentRequestId;
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
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.paymentRequestId,
    DateTime? createdAt,
    this.serviceDate,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      guideId: json['guide_id']?.toString() ?? '',
      guideName: json['guide_name'] ?? '',
      guideAvatar: json['guide_avatar'] ?? '',
      status: OrderStatus.values[json['status'] ?? 0],
      amount: (json['amount'] ?? 0).toDouble(),
      serviceName: json['service_name'] ?? '',
      paymentMethod: json['payment_method'] ?? '',
      paymentStatus: json['payment_status'] ?? '',
      paymentRequestId: json['payment_request_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      serviceDate: json['service_date'] != null
          ? DateTime.tryParse(json['service_date'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'user_id': userId,
      'guide_id': guideId,
      'guide_name': guideName,
      'guide_avatar': guideAvatar,
      'status': status.index,
      'amount': amount,
      'service_name': serviceName,
      'payment_method': paymentMethod,
      'payment_status': paymentStatus,
      if (paymentRequestId != null) 'payment_request_id': paymentRequestId,
      'created_at': createdAt.toIso8601String(),
    };
    if (id.isNotEmpty) {
      map['id'] = id;
    }
    if (serviceDate != null) {
      map['service_date'] = serviceDate!.toIso8601String();
    }
    return map;
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
