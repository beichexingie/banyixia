class AppNotification {
  final String id;
  final String title;
  final String body;
  final String route;
  final String type;
  final String orderId;
  final String serviceName;
  final double amount;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    required this.type,
    required this.orderId,
    required this.serviceName,
    required this.amount,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawAmount = json['amount'];
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '系统通知',
      body: json['body']?.toString() ?? '',
      route: json['route']?.toString() ?? '',
      type: json['notification_type']?.toString() ?? 'general',
      orderId: json['order_id']?.toString() ?? '',
      serviceName: json['service_name']?.toString() ?? '',
      amount: rawAmount is num
          ? rawAmount.toDouble()
          : double.tryParse(rawAmount?.toString() ?? '') ?? 0,
      isRead: json['is_read'] == true,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
