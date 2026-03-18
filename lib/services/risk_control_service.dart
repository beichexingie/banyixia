/// 风控与安全服务
class RiskControlService {
  /// 敏感词库 (生产环境应从服务端获取或使用三方过滤)
  static const List<String> _sensitiveWords = [
    '微信', 'WeChat', '私下交易', '手机号', '电话', '转账', '支付宝', '兼职', '加我', '联系方式'
  ];

  /// 检查文本是否包含敏感词
  /// 返回：[是否合规, 命中的敏感词]
  static Map<String, dynamic> checkText(String text) {
    for (var word in _sensitiveWords) {
      if (text.toLowerCase().contains(word.toLowerCase())) {
        return {
          'isSafe': false,
          'word': word,
        };
      }
    }
    return {
      'isSafe': true,
      'word': null,
    };
  }

  /// 阶梯分成计算逻辑
  /// 月流水 < 5000: 50% 平台抽成
  /// 月流水 > 5000: 超出部分 40% 平台抽成 (即导游拿 60%)
  static double calculateGuideShare(double amount, double monthlySales) {
    if (monthlySales + amount <= 5000) {
      return amount * 0.5;
    } else if (monthlySales >= 5000) {
      return amount * 0.6;
    } else {
      // 跨度计算
      double below5000 = 5000 - monthlySales;
      double above5000 = amount - below5000;
      return (below5000 * 0.5) + (above5000 * 0.6);
    }
  }
}
