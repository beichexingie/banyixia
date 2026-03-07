// Mock 数据和常量

class MockData {
  /// 旅行内容卡片
  static final List<Map<String, dynamic>> travelCards = [
    {
      'title': '重庆二日游线路攻略',
      'subtitle': '两日暴走行程',
      'image': 'https://picsum.photos/seed/chongqing/400/300',
      'author': 'YUYU',
      'avatar': 'https://picsum.photos/seed/avatar1/100/100',
      'likes': 16,
      'tag': '苏州',
    },
    {
      'title': '带你2天游遍天津市区，探寻历史与现代…',
      'image': 'https://picsum.photos/seed/tianjin/400/300',
      'author': '游鸭784755',
      'avatar': 'https://picsum.photos/seed/avatar2/100/100',
      'likes': 36,
      'tag': '苏州',
    },
    {
      'title': '成都三天深度游，感受巴蜀文化魅力',
      'image': 'https://picsum.photos/seed/chengdu/400/300',
      'author': '旅行达人',
      'avatar': 'https://picsum.photos/seed/avatar3/100/100',
      'likes': 52,
      'tag': '成都',
    },
    {
      'title': '西安古城墙下的千年故事',
      'image': 'https://picsum.photos/seed/xian/400/300',
      'author': '历史探索者',
      'avatar': 'https://picsum.photos/seed/avatar4/100/100',
      'likes': 28,
      'tag': '西安',
    },
    {
      'title': '杭州西湖畔的诗意之旅',
      'image': 'https://picsum.photos/seed/hangzhou/400/300',
      'author': '诗意旅人',
      'avatar': 'https://picsum.photos/seed/avatar5/100/100',
      'likes': 41,
      'tag': '杭州',
    },
    {
      'title': '长沙美食之旅，吃遍橘子洲',
      'image': 'https://picsum.photos/seed/changsha/400/300',
      'author': '吃货小王',
      'avatar': 'https://picsum.photos/seed/avatar6/100/100',
      'likes': 99,
      'tag': '长沙',
    },
  ];

  /// 地陪人员
  static final List<Map<String, dynamic>> guides = [
    {
      'name': '小树',
      'avatar': 'https://picsum.photos/seed/guide1/100/100',
      'rating': 4.9,
      'gender': '男',
      'verified': true,
      'tags': ['今天来过'],
      'description': '本人02年在京工作，偏i但e性格细腻温柔，共情能力强，可以跟我吐槽您的烦恼哦~',
      'images': [
        'https://picsum.photos/seed/g1img1/200/200',
      ],
      'views': 902,
      'likes': 1123,
      'fans': 652,
    },
    {
      'name': 'Allysa艾丽莎',
      'avatar': 'https://picsum.photos/seed/guide2/100/100',
      'rating': 4.8,
      'gender': '女',
      'verified': true,
      'tags': ['今天来过'],
      'description': '帮助提前规划路线，专车接送，安排拍照打卡，帮忙排队，讲解景点详情，各色建筑…',
      'images': [
        'https://picsum.photos/seed/g2img1/200/200',
      ],
      'views': 1022,
      'likes': 1523,
      'fans': 863,
    },
    {
      'name': '小树',
      'avatar': 'https://picsum.photos/seed/guide3/100/100',
      'rating': 4.7,
      'gender': '男',
      'verified': false,
      'tags': ['今天来过'],
      'description': '本人02年在京工作，偏i但e性格细腻温柔，共情能力强，可以跟我吐槽您的烦恼哦~',
      'images': [],
      'views': 500,
      'likes': 800,
      'fans': 300,
    },
    {
      'name': 'Allysa艾丽莎游鸭YOY…',
      'avatar': 'https://picsum.photos/seed/guide4/100/100',
      'rating': 4.6,
      'gender': '女',
      'verified': false,
      'tags': [],
      'description': '帮助提前规划路线，专车接送，安排拍照打卡，帮忙排队，讲解景点详情，各色建筑…',
      'images': [
        'https://picsum.photos/seed/g4img1/200/200',
      ],
      'views': 780,
      'likes': 1200,
      'fans': 560,
    },
  ];

  /// 消息列表
  static final List<Map<String, dynamic>> messages = [
    {
      'name': '系统通知',
      'avatar': 'https://picsum.photos/seed/sys1/100/100',
      'lastMessage': '欢迎加入伴一下！开启您的旅行社交之旅',
      'time': '刚刚',
      'unread': 1,
    },
    {
      'name': '小助手',
      'avatar': 'https://picsum.photos/seed/helper/100/100',
      'lastMessage': '您好，有什么可以帮您的吗？',
      'time': '2小时前',
      'unread': 0,
    },
    {
      'name': '旅行达人',
      'avatar': 'https://picsum.photos/seed/traveler/100/100',
      'lastMessage': '明天的行程已经为您安排好了！',
      'time': '昨天',
      'unread': 3,
    },
  ];
}
