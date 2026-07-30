import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/order.dart';
import '../../models/user.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../models/guide_app_models.dart';

class GuideConsoleProvider extends ChangeNotifier {
  static const _modeKey = 'guide_console_mode';
  static const _cityKey = 'guide_console_city';
  static const _nearbyOnlyKey = 'guide_console_nearby_only';
  static const _enabledTypesKey = 'guide_console_types';
  static const _onlineKey = 'guide_console_online';

  GuideDutyMode _mode = GuideDutyMode.nearby;
  String _selectedCity = '苏州';
  bool _isOnline = false;
  bool _nearbyOnly = true;
  List<String> _serviceCities = const ['苏州', '北京', '上海', '深圳'];
  List<String> _historyCities = const ['苏州', '北京', '上海', '深圳', '杭州'];
  Set<GuideServiceType> _enabledTypes = {GuideServiceType.localCompanion};
  int _routeTabIndex = 0;
  GuideAddress _currentLocation = const GuideAddress(
    city: '江苏省苏州市',
    title: '姑苏区观前街',
    detail: '（自动定位所在城市的具体位置）',
    contactName: '刘小林女士',
    maskedPhone: '159****6890',
  );
  List<GuideAddress> _serviceAddresses = const [
    GuideAddress(
      city: '苏州市工业园区',
      title: '金鸡湖大酒店',
      detail: '金鸡湖大道 122 号',
      contactName: '刘小林女士',
      maskedPhone: '159****6890',
    ),
    GuideAddress(
      city: '苏州市工业园区',
      title: '金鸡湖大酒店',
      detail: '星港街 88 号',
      contactName: '刘小林女士',
      maskedPhone: '159****6890',
    ),
    GuideAddress(
      city: '苏州市工业园区',
      title: '金鸡湖大酒店',
      detail: '月光码头 B2 栋',
      contactName: '刘小林女士',
      maskedPhone: '159****6890',
    ),
  ];

  final List<GuideServiceOption> _serviceOptions = [
    GuideServiceOption(
      id: 'relax_1',
      name: '城市漫步陪同',
      description: '适合半日或一日轻松出行，含路线建议、景点串联与拍照打卡陪同。',
      pricePerDay: 400,
      imageUrl: 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=320&q=80',
      count: 1,
    ),
    GuideServiceOption(
      id: 'relax_2',
      name: '美食探店陪同',
      description: '根据客户口味与时间安排本地探店路线，适合情侣、朋友和亲子出行。',
      pricePerDay: 400,
      imageUrl: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=320&q=80',
      count: 1,
    ),
    GuideServiceOption(
      id: 'relax_3',
      name: '夜游行程陪同',
      description: '偏向夜景、散步、拍照与轻社交氛围，适合晚间短时段服务。',
      pricePerDay: 400,
      imageUrl: 'https://images.unsplash.com/photo-1493246507139-91e8fad9978e?auto=format&fit=crop&w=320&q=80',
      count: 1,
    ),
    GuideServiceOption(
      id: 'relax_4',
      name: '定制陪同服务',
      description: '根据客户目的地、节奏和人数做个性化安排，适合高客单定制单。',
      pricePerDay: 400,
      imageUrl: 'https://images.unsplash.com/photo-1469474968028-56623f02e42e?auto=format&fit=crop&w=320&q=80',
      count: 1,
    ),
  ];

  bool _isInitialized = false;

  GuideDutyMode get mode => _mode;
  String get selectedCity => _selectedCity;
  bool get isOnline => _isOnline;
  bool get nearbyOnly => _nearbyOnly;
  List<String> get serviceCities => _serviceCities;
  List<String> get historyCities => _historyCities;
  Set<GuideServiceType> get enabledTypes => _enabledTypes;
  int get routeTabIndex => _routeTabIndex;
  GuideAddress get currentLocation => _currentLocation;
  List<GuideAddress> get serviceAddresses => _serviceAddresses;
  List<GuideServiceOption> get serviceOptions => _serviceOptions;
  bool get isInitialized => _isInitialized;

  List<GuideServiceType> get serviceTypeList => GuideServiceType.values;
  List<GuideDutyMode> get modeList => GuideDutyMode.values;

  GuideWorkbenchStats _stats = const GuideWorkbenchStats(
    totalOrders: 0,
    completedOrders: 0,
    positiveReviews: 0,
    cancelOrders: 0,
    cancellationRate: 0,
  );

  GuideWorkbenchStats get stats => _stats;

  List<GuideDashboardShortcut> get shortcuts => const [
        GuideDashboardShortcut(
          title: '时间管理',
          subtitle: '灵活排班',
          icon: Icons.calendar_month_outlined,
          color: Color(0xFFE8FFF3),
        ),
        GuideDashboardShortcut(
          title: '服务项目',
          subtitle: '配置上架项目',
          icon: Icons.handshake_outlined,
          color: Color(0xFFFFF7E3),
        ),
        GuideDashboardShortcut(
          title: '客户评价',
          subtitle: '查看口碑',
          icon: Icons.sticky_note_2_outlined,
          color: Color(0xFFF1F4FF),
        ),
        GuideDashboardShortcut(
          title: '需求大厅',
          subtitle: '查看并报名',
          icon: Icons.assignment_turned_in_outlined,
          color: Color(0xFFFFF1E9),
        ),
      ];

  List<GuideTaskCard> get taskCards => const [
        GuideTaskCard(
          title: '拉新赚钱',
          subtitle: '空闲拉新，动动手指日日赚现',
          icon: Icons.savings_outlined,
          backgroundColor: Color(0xFFB8FF1A),
          foregroundColor: Color(0xFF171717),
        ),
        GuideTaskCard(
          title: '任务中心',
          subtitle: '做任务·领福利',
          icon: Icons.inventory_2_outlined,
          backgroundColor: Color(0xFFFFE37B),
          foregroundColor: Color(0xFF171717),
        ),
        GuideTaskCard(
          title: '培训中心',
          subtitle: '操作流程一点通',
          icon: Icons.school_outlined,
          backgroundColor: Color(0xFFFFB547),
          foregroundColor: Color(0xFF171717),
        ),
      ];

  Future<void> initialize(UserProvider userProvider) async {
    if (_isInitialized) {
      _refreshLoginState(userProvider.user);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_modeKey);
    if (modeIndex != null && modeIndex >= 0 && modeIndex < GuideDutyMode.values.length) {
      _mode = GuideDutyMode.values[modeIndex];
    }
    final savedCity = prefs.getString(_cityKey);
    if (savedCity != null && savedCity.trim().isNotEmpty) {
      _selectedCity = savedCity.trim();
    }
    _nearbyOnly = prefs.getBool(_nearbyOnlyKey) ?? true;
    _isOnline = prefs.getBool(_onlineKey) ?? userProvider.isGuide;
    final storedTypes = prefs.getStringList(_enabledTypesKey);
    if (storedTypes != null && storedTypes.isNotEmpty) {
      final parsed = storedTypes
          .map(_serviceTypeFromName)
          .whereType<GuideServiceType>()
          .toSet();
      if (parsed.isNotEmpty) {
        _enabledTypes = parsed;
      }
    }
    _syncEnabledTypesFromUser(userProvider.user);
    _refreshLoginState(userProvider.user);
    _isInitialized = true;
    notifyListeners();
  }

  void _refreshLoginState(User user) {
    if (!user.isGuideApproved) {
      _isOnline = false;
    }
  }

  Future<void> hydrateFromUser(UserProvider userProvider) async {
    _refreshLoginState(userProvider.user);
    _syncEnabledTypesFromUser(userProvider.user);
    notifyListeners();
  }

  void _syncEnabledTypesFromUser(User user) {
    if (user.guideTags.isEmpty) return;
    final parsed = user.guideTags
        .map(_serviceTypeFromLabel)
        .whereType<GuideServiceType>()
        .toSet();
    if (parsed.isNotEmpty) {
      _enabledTypes = parsed;
    }
  }

  Future<void> setMode(GuideDutyMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, mode.index);
  }

  Future<void> setSelectedCity(String city) async {
    if (city.trim().isEmpty) return;
    _selectedCity = city.trim();
    if (!_serviceCities.contains(_selectedCity)) {
      _serviceCities = [_selectedCity, ..._serviceCities.where((item) => item != _selectedCity)];
    }
    _historyCities = [_selectedCity, ..._historyCities.where((item) => item != _selectedCity)];
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cityKey, _selectedCity);
  }

  Future<void> setNearbyOnly(bool value) async {
    _nearbyOnly = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_nearbyOnlyKey, value);
  }

  Future<void> setOnline(bool value) async {
    _isOnline = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onlineKey, value);
  }

  Future<void> toggleServiceType(GuideServiceType type) async {
    if (type.isLocked) return;
    if (_enabledTypes.contains(type)) {
      if (_enabledTypes.length == 1) return;
      _enabledTypes.remove(type);
    } else {
      _enabledTypes.add(type);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _enabledTypesKey,
      _enabledTypes.map((item) => item.name).toList(),
    );
  }

  Future<void> saveServiceTypesToProfile(UserProvider userProvider) async {
    final selectedLabels = _enabledTypes
        .map((item) => item.label)
        .where((item) => item.trim().isNotEmpty)
        .toSet()
        .toList();
    await userProvider.updateUser(
      User(
        id: userProvider.user.id,
        nickname: userProvider.user.nickname,
        avatar: userProvider.user.avatar,
        bio: userProvider.user.bio,
        gender: userProvider.user.gender,
        city: userProvider.user.city,
        birthday: userProvider.user.birthday,
        wechat: userProvider.user.wechat,
        occupation: userProvider.user.occupation,
        guideIntroduction: userProvider.user.guideIntroduction,
        guideTags: selectedLabels,
        vipLevel: userProvider.user.vipLevel,
        title: userProvider.user.title,
        balance: userProvider.user.balance,
        couponCount: userProvider.user.couponCount,
        followCount: userProvider.user.followCount,
        fansCount: userProvider.user.fansCount,
        isBanned: userProvider.user.isBanned,
        cancelCount: userProvider.user.cancelCount,
        isAdmin: userProvider.user.isAdmin,
        isGuide: userProvider.user.isGuide,
        guideApplicationStatus: userProvider.user.guideApplicationStatus,
      ),
    );
  }

  void changeServiceOptionCount(String serviceId, int delta) {
    final index = _serviceOptions.indexWhere((item) => item.id == serviceId);
    if (index == -1) return;
    final current = _serviceOptions[index];
    final nextCount = (current.count + delta).clamp(0, 99);
    if (nextCount == current.count) return;
    _serviceOptions[index] = current.copyWith(count: nextCount);
    notifyListeners();
  }

  void addMockServiceAddress() {
    final nextIndex = _serviceAddresses.length + 1;
    addServiceAddress(
      GuideAddress(
        city: '苏州市工业园区',
        title: '新增服务点 $nextIndex',
        detail: '月廊街 ${100 + nextIndex} 号',
        contactName: '刘小林女士',
        maskedPhone: '159****6890',
      ),
    );
  }

  void cycleMockCurrentLocation() {
    const candidates = [
      GuideAddress(
        city: '江苏省苏州市',
        title: '姑苏区平江路',
        detail: '（重新定位后已切换到平江路附近）',
        contactName: '刘小林女士',
        maskedPhone: '159****6890',
      ),
      GuideAddress(
        city: '江苏省苏州市',
        title: '工业园区金鸡湖',
        detail: '（重新定位后已切换到金鸡湖商圈）',
        contactName: '刘小林女士',
        maskedPhone: '159****6890',
      ),
      GuideAddress(
        city: '江苏省苏州市',
        title: '高新区狮山路',
        detail: '（重新定位后已切换到狮山商务区）',
        contactName: '刘小林女士',
        maskedPhone: '159****6890',
      ),
    ];
    final currentIndex = candidates.indexWhere(
      (item) => item.title == _currentLocation.title,
    );
    final next = candidates[(currentIndex + 1) % candidates.length];
    updateCurrentLocation(next);
  }

  void setRouteTabIndex(int value) {
    _routeTabIndex = value;
    notifyListeners();
  }

  void updateCurrentLocation(GuideAddress address) {
    _currentLocation = address;
    notifyListeners();
  }

  void addServiceAddress(GuideAddress address) {
    _serviceAddresses = [address, ..._serviceAddresses];
    notifyListeners();
  }

  List<GuideOrderCardData> buildGuideOrders(List<Order> orders) {
    final guideSideOrders = orders.where((item) => item.guideId.isNotEmpty).toList();
    if (guideSideOrders.isEmpty) {
      return const [];
    }
    return guideSideOrders.map((order) {
      final stage = switch (order.status) {
        OrderStatus.pendingPayment => GuideOrderStage.pendingPayment,
        OrderStatus.inProgress => GuideOrderStage.inProgress,
        OrderStatus.pendingReview || OrderStatus.completed => GuideOrderStage.inProgress,
        OrderStatus.cancelled => GuideOrderStage.newOrder,
      };
      final primaryAction = switch (stage) {
        GuideOrderStage.newOrder => GuideOrderAction.goToService,
        GuideOrderStage.pendingPayment => GuideOrderAction.accept,
        GuideOrderStage.inProgress => GuideOrderAction.arrived,
      };
      return GuideOrderCardData(
        id: order.id,
        stage: stage,
        serviceLabel: _serviceLabelForOrder(order),
        etaText: _etaTextForOrder(order),
        distanceText: _distanceTextForOrder(order),
        amount: order.amount,
        content: _contentForOrder(order),
        address: order.serviceAddress.isNotEmpty
            ? order.serviceAddress
            : _currentLocation.summary,
        serviceCity: order.serviceCity,
        serviceLat: order.serviceLat,
        serviceLng: order.serviceLng,
        imageUrls: _mockOrderImages,
        primaryAction: primaryAction,
        serviceTime: order.serviceDate ?? order.createdAt.add(const Duration(hours: 6)),
      );
    }).toList();
  }

  List<GuideOrderCardData> get _mockGuideOrders => [
        GuideOrderCardData(
          id: 'guide_order_1',
          stage: GuideOrderStage.inProgress,
          serviceLabel: '地陪',
          etaText: '剩余：5小时23分钟',
          distanceText: '距服务地 2.3km',
          amount: 480,
          content: '苏州平江路半日陪同，客户希望安排轻松路线，含拍照打卡与晚餐建议。',
          address: '苏州市姑苏区平江路历史街区游客中心',
          serviceCity: '苏州',
          serviceLat: 31.3202,
          serviceLng: 120.6336,
          imageUrls: _mockOrderImages,
          primaryAction: GuideOrderAction.arrived,
          serviceTime: DateTime.now().add(const Duration(hours: 5)),
        ),
        GuideOrderCardData(
          id: 'guide_order_2',
          stage: GuideOrderStage.newOrder,
          serviceLabel: '定制',
          etaText: '剩余：5小时23分钟',
          distanceText: '距服务地 8.6km',
          amount: 480,
          content: '金鸡湖夜游定制单，客户两人出行，希望包含拍照点和夜景路线建议。',
          address: '苏州市工业园区金鸡湖音乐喷泉广场',
          serviceCity: '苏州',
          serviceLat: 31.3148,
          serviceLng: 120.7072,
          imageUrls: _mockOrderImages,
          primaryAction: GuideOrderAction.goToService,
          serviceTime: DateTime.now().add(const Duration(hours: 7)),
        ),
      ];

  static const List<String> _mockOrderImages = [
    'https://images.unsplash.com/photo-1506744038136-46273834b3fb?auto=format&fit=crop&w=360&q=80',
    'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?auto=format&fit=crop&w=360&q=80',
    'https://images.unsplash.com/photo-1493246507139-91e8fad9978e?auto=format&fit=crop&w=360&q=80',
  ];

  String _serviceLabelForOrder(Order order) {
    final text = order.serviceName;
    if (text.contains('定制')) return '定制';
    if (text.contains('帮忙')) return '帮忙';
    return '地陪';
  }

  String _etaTextForOrder(Order order) {
    final date = order.serviceDate ?? order.createdAt.add(const Duration(hours: 5));
    final diff = date.difference(DateTime.now());
    final hours = diff.inHours.abs();
    final minutes = diff.inMinutes.abs() % 60;
    return '剩余：${hours}小时${minutes}分钟';
  }

  String _distanceTextForOrder(Order order) {
    if ((order.routeDistanceMeters ?? order.distanceMeters) != null) {
      return '距服务地 ${order.distanceText}';
    }
    final seed = order.id.codeUnits.fold<int>(0, (sum, item) => sum + item);
    final kilometers = ((seed % 120) + 8) / 10;
    return '距服务地 ${kilometers.toStringAsFixed(1)}km';
  }

  String _contentForOrder(Order order) {
    if (order.serviceName.trim().isNotEmpty) {
      return order.serviceName.trim();
    }
    if (order.serviceAddress.trim().isNotEmpty) {
      return '客户已预约 ${order.serviceAddress.trim()} 附近服务，请尽快联系确认具体行程安排。';
    }
    return '客户已提交服务需求，请尽快联系确认服务细节。';
  }

  Future<void> bootstrapForGuide(UserProvider userProvider) async {
    await initialize(userProvider);
  }

  Future<void> syncFromProviders({
    required UserProvider userProvider,
    required OrderProvider orderProvider,
  }) async {
    await initialize(userProvider);
    await hydrateFromUser(userProvider);
    if (orderProvider.orders.isEmpty) {
      await orderProvider.loadOrders();
    }
    _stats = _buildStats(orderProvider.orders);
    final derivedAddresses = _buildServiceAddresses(orderProvider.orders);
    if (derivedAddresses.isNotEmpty) {
      _serviceAddresses = derivedAddresses;
    }
    notifyListeners();
  }

  GuideWorkbenchStats _buildStats(List<Order> orders) {
    if (orders.isEmpty) {
      return const GuideWorkbenchStats(
        totalOrders: 0,
        completedOrders: 0,
        positiveReviews: 0,
        cancelOrders: 0,
        cancellationRate: 0,
      );
    }
    final totalOrders = orders.length;
    final completedOrders = orders
        .where((item) => item.status == OrderStatus.completed)
        .length;
    final positiveReviews = orders
        .where((item) => item.status == OrderStatus.pendingReview)
        .length;
    final cancelOrders = orders
        .where((item) => item.status == OrderStatus.cancelled)
        .length;
    final cancellationRate = totalOrders == 0
        ? 0
        : ((cancelOrders / totalOrders) * 100).round();
    return GuideWorkbenchStats(
      totalOrders: totalOrders,
      completedOrders: completedOrders,
      positiveReviews: positiveReviews,
      cancelOrders: cancelOrders,
      cancellationRate: cancellationRate,
    );
  }

  List<GuideAddress> _buildServiceAddresses(List<Order> orders) {
    final seen = <String>{};
    final result = <GuideAddress>[];
    for (final order in orders) {
      final address = order.serviceAddress.trim();
      if (address.isEmpty || seen.contains(address)) {
        continue;
      }
      seen.add(address);
      result.add(
        GuideAddress(
          city: order.serviceCity.isNotEmpty ? order.serviceCity : _selectedCity,
          title: address,
          detail: order.serviceName.isNotEmpty ? order.serviceName : '订单服务地点',
          contactName: order.guideName.isNotEmpty ? order.guideName : '客户',
          maskedPhone: '待联系',
        ),
      );
    }
    return result;
  }

  GuideServiceType? _serviceTypeFromName(String raw) {
    for (final item in GuideServiceType.values) {
      if (item.name == raw) {
        return item;
      }
    }
    return null;
  }

  GuideServiceType? _serviceTypeFromLabel(String raw) {
    for (final item in GuideServiceType.values) {
      if (item.label == raw) {
        return item;
      }
    }
    return null;
  }
}
