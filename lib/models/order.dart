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
  final String? merchantOrderNo;
  final String? providerTradeNo;
  final DateTime? paidAt;
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
    this.merchantOrderNo,
    this.providerTradeNo,
    this.paidAt,
    DateTime? createdAt,
    this.serviceDate,
  }) : createdAt = createdAt ?? DateTime.now();

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      guideId: json['guide_id']?.toString() ?? '',
      guideName: json['guide_name'] ?? '',
      guideAvatar: json['guide_avatar'] ?? '',
      status: OrderStatus.values[json['status'] ?? 0],
      amount: _asDouble(json['amount']),
      serviceName: json['service_name'] ?? '',
      paymentMethod: json['payment_method'] ?? '',
      paymentStatus: json['payment_status'] ?? '',
      paymentRequestId: json['payment_request_id']?.toString(),
      merchantOrderNo: json['merchant_order_no']?.toString(),
      providerTradeNo: json['provider_trade_no']?.toString(),
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'])
          : null,
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
      if (merchantOrderNo != null) 'merchant_order_no': merchantOrderNo,
      if (providerTradeNo != null) 'provider_trade_no': providerTradeNo,
      if (paidAt != null) 'paid_at': paidAt!.toIso8601String(),
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

  Order copyWith({
    String? id,
    String? userId,
    String? guideId,
    String? guideName,
    String? guideAvatar,
    OrderStatus? status,
    double? amount,
    String? serviceName,
    String? paymentMethod,
    String? paymentStatus,
    String? paymentRequestId,
    String? merchantOrderNo,
    String? providerTradeNo,
    DateTime? paidAt,
    DateTime? createdAt,
    DateTime? serviceDate,
  }) {
    return Order(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      guideId: guideId ?? this.guideId,
      guideName: guideName ?? this.guideName,
      guideAvatar: guideAvatar ?? this.guideAvatar,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      serviceName: serviceName ?? this.serviceName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentRequestId: paymentRequestId ?? this.paymentRequestId,
      merchantOrderNo: merchantOrderNo ?? this.merchantOrderNo,
      providerTradeNo: providerTradeNo ?? this.providerTradeNo,
      paidAt: paidAt ?? this.paidAt,
      createdAt: createdAt ?? this.createdAt,
      serviceDate: serviceDate ?? this.serviceDate,
    );
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
