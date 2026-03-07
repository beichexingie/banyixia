import 'package:flutter/material.dart';
import '../models/guide.dart';

/// 地陪人员状态管理
class GuideProvider extends ChangeNotifier {
  List<Guide> _guides = [];
  bool _isLoading = false;
  String _selectedCity = '全国';

  List<Guide> get guides => _guides;
  bool get isLoading => _isLoading;
  String get selectedCity => _selectedCity;

  /// 按城市筛选后的列表
  List<Guide> get filteredGuides {
    if (_selectedCity == '全国') return _guides;
    return _guides.where((g) => g.city == _selectedCity).toList();
  }

  /// 加载地陪列表（后续替换为 API 调用）
  Future<void> loadGuides() async {
    _isLoading = true;
    notifyListeners();

    // TODO: 替换为真实 API 调用
    await Future.delayed(const Duration(milliseconds: 500));

    _guides = [
      Guide(
        id: 'g1',
        name: '小树',
        avatar: 'https://picsum.photos/seed/guide1/100/100',
        rating: 4.9,
        gender: '男',
        verified: true,
        tags: ['今天来过'],
        description: '本人02年在京工作，偏i但e性格细腻温柔，共情能力强，可以跟我吐槽您的烦恼哦~',
        images: ['https://picsum.photos/seed/g1img1/200/200'],
        views: 902,
        likes: 1123,
        fans: 652,
        city: '北京',
      ),
      Guide(
        id: 'g2',
        name: 'Allysa艾丽莎',
        avatar: 'https://picsum.photos/seed/guide2/100/100',
        rating: 4.8,
        gender: '女',
        verified: true,
        tags: ['今天来过'],
        description: '帮助提前规划路线，专车接送，安排拍照打卡，帮忙排队，讲解景点详情，各色建筑…',
        images: ['https://picsum.photos/seed/g2img1/200/200'],
        views: 1022,
        likes: 1523,
        fans: 863,
        city: '苏州',
      ),
      Guide(
        id: 'g3',
        name: '小树',
        avatar: 'https://picsum.photos/seed/guide3/100/100',
        rating: 4.7,
        gender: '男',
        verified: false,
        tags: ['今天来过'],
        description: '本人02年在京工作，偏i但e性格细腻温柔，共情能力强，可以跟我吐槽您的烦恼哦~',
        images: [],
        views: 500,
        likes: 800,
        fans: 300,
        city: '北京',
      ),
      Guide(
        id: 'g4',
        name: 'Allysa艾丽莎游鸭YOY',
        avatar: 'https://picsum.photos/seed/guide4/100/100',
        rating: 4.6,
        gender: '女',
        verified: false,
        tags: [],
        description: '帮助提前规划路线，专车接送，安排拍照打卡，帮忙排队，讲解景点详情，各色建筑…',
        images: ['https://picsum.photos/seed/g4img1/200/200'],
        views: 780,
        likes: 1200,
        fans: 560,
        city: '杭州',
      ),
    ];

    _isLoading = false;
    notifyListeners();
  }

  /// 切换城市筛选
  void setCity(String city) {
    _selectedCity = city;
    notifyListeners();
  }
}
