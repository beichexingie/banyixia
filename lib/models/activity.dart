class Activity {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String bannerImage;
  final String status;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? createdAt;

  const Activity({
    required this.id,
    required this.title,
    this.summary = '',
    this.content = '',
    this.bannerImage = '',
    this.status = 'published',
    this.startsAt,
    this.endsAt,
    this.createdAt,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      bannerImage:
          json['banner_image']?.toString() ??
          json['bannerImage']?.toString() ??
          '',
      status: json['status']?.toString() ?? 'published',
      startsAt: _parseDate(json['starts_at'] ?? json['startsAt']),
      endsAt: _parseDate(json['ends_at'] ?? json['endsAt']),
      createdAt: _parseDate(json['created_at'] ?? json['createdAt']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : DateTime.tryParse(text);
  }
}
