/// 时间工具类
class TimeUtils {
  /// 格式化时间显示
  /// < 1分钟: 刚刚
  /// < 1小时: X分钟前
  /// < 24小时: X小时前
  /// < 48小时: 昨天
  /// < 7天: X天前
  /// 其他: yyyy/MM/dd
  static String format(DateTime? dateTime) {
    if (dateTime == null) return '';
    
    final localTime = dateTime.toLocal(); // 转换为本地时间
    final now = DateTime.now();
    final diff = now.difference(localTime);

    if (diff.inSeconds < 60 && diff.inSeconds >= 0) {
      return '刚刚';
    } else if (diff.inMinutes < 60 && diff.inMinutes > 0) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24 && diff.inHours > 0) {
      return '${diff.inHours}小时前';
    } else if (localTime.day == now.day - 1 && localTime.month == now.month && localTime.year == now.year) {
      return '昨天';
    } else if (diff.inDays < 7 && diff.inDays > 1) {
      return '${diff.inDays}天前';
    } else {
      return '${localTime.year}/${localTime.month.toString().padLeft(2, '0')}/${localTime.day.toString().padLeft(2, '0')}';
    }
  }

  /// 聊天室专用时间格式
  static String formatChat(DateTime? dateTime) {
    if (dateTime == null) return '';
    final localTime = dateTime.toLocal(); // 转换为本地时间
    final now = DateTime.now();
    
    if (localTime.year == now.year && localTime.month == now.month && localTime.day == now.day) {
      return '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    } else if (localTime.year == now.year && localTime.month == now.month && (now.day - localTime.day == 1)) {
      return '昨天';
    } else {
      return '${localTime.month}/${localTime.day}';
    }
  }
}
