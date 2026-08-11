/// 订单状态枚举
enum OrderStatus {
  pendingPayment, // 待付款
  inProgress, // 进行中
  pendingReview, // 待评价
  completed, // 已完成
  cancelled, // 已取消
}

/// 订单模型
class Order {
  final String id;
  final String userId;
  final String guideId;
  final String guideName;
  final String guideAvatar;
  final String customerName;
  final String customerAvatar;
  final OrderStatus status;
  final double amount;
  final String serviceName;
  final String serviceAddress;
  final String serviceCity;
  final double? serviceLat;
  final double? serviceLng;
  final int? distanceMeters;
  final int? routeDistanceMeters;
  final int? routeDurationSeconds;
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
    this.customerName = '',
    this.customerAvatar = '',
    required this.status,
    required this.amount,
    this.serviceName = '',
    this.serviceAddress = '',
    this.serviceCity = '',
    this.serviceLat,
    this.serviceLng,
    this.distanceMeters,
    this.routeDistanceMeters,
    this.routeDurationSeconds,
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
      customerName: json['customer_name'] ?? '',
      customerAvatar: json['customer_avatar'] ?? '',
      status: _parseStatus(json['status']),
      amount: _parseDouble(json['amount']) ?? 0,
      serviceName: json['service_name'] ?? '',
      serviceAddress: json['service_address'] ?? '',
      serviceCity: json['service_city'] ?? '',
      serviceLat: _parseDouble(json['service_lat']),
      serviceLng: _parseDouble(json['service_lng']),
      distanceMeters: _parseInt(json['distance_meters']),
      routeDistanceMeters: _parseInt(json['route_distance_meters']),
      routeDurationSeconds: _parseInt(json['route_duration_seconds']),
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
      'service_address': serviceAddress,
      'service_city': serviceCity,
      'service_lat': serviceLat,
      'service_lng': serviceLng,
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
    String? customerName,
    String? customerAvatar,
    OrderStatus? status,
    double? amount,
    String? serviceName,
    String? serviceAddress,
    String? serviceCity,
    double? serviceLat,
    double? serviceLng,
    int? distanceMeters,
    int? routeDistanceMeters,
    int? routeDurationSeconds,
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
      customerName: customerName ?? this.customerName,
      customerAvatar: customerAvatar ?? this.customerAvatar,
      status: status ?? this.status,
      amount: amount ?? this.amount,
      serviceName: serviceName ?? this.serviceName,
      serviceAddress: serviceAddress ?? this.serviceAddress,
      serviceCity: serviceCity ?? this.serviceCity,
      serviceLat: serviceLat ?? this.serviceLat,
      serviceLng: serviceLng ?? this.serviceLng,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      routeDistanceMeters: routeDistanceMeters ?? this.routeDistanceMeters,
      routeDurationSeconds: routeDurationSeconds ?? this.routeDurationSeconds,
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

  static OrderStatus _parseStatus(dynamic value) {
    if (value is int && value >= 0 && value < OrderStatus.values.length) {
      return OrderStatus.values[value];
    }
    final normalized = value?.toString().trim().toLowerCase() ?? '';
    switch (normalized) {
      case 'pendingpayment':
      case 'pending_payment':
      case 'pending':
      case '0':
        return OrderStatus.pendingPayment;
      case 'inprogress':
      case 'in_progress':
      case 'processing':
      case '1':
        return OrderStatus.inProgress;
      case 'pendingreview':
      case 'pending_review':
      case '2':
        return OrderStatus.pendingReview;
      case 'completed':
      case 'complete':
      case '3':
        return OrderStatus.completed;
      case 'cancelled':
      case 'canceled':
      case '4':
        return OrderStatus.cancelled;
      default:
        final parsedIndex = int.tryParse(normalized);
        if (parsedIndex != null &&
            parsedIndex >= 0 &&
            parsedIndex < OrderStatus.values.length) {
          return OrderStatus.values[parsedIndex];
        }
        return OrderStatus.pendingPayment;
    }
  }

  static double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String get distanceText {
    final meters = routeDistanceMeters ?? distanceMeters;
    if (meters == null) return '待定位';
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
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
