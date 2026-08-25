import 'dart:async';
import 'dart:math' as math;

import 'package:amap_flutter_base/amap_flutter_base.dart' as amap_base;
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../config/amap_config.dart';
import '../../config/app_theme.dart';
import '../../services/map_service.dart';

class LocationPickerPage extends StatefulWidget {
  final String? initialAddress;
  final String? initialCity;
  final String title;

  const LocationPickerPage({
    super.key,
    this.initialAddress,
    this.initialCity,
    this.title = '服务地点',
  });

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  static const LatLng _defaultLatLng = LatLng(31.299379, 120.619585);
  static const double _defaultZoom = 15;
  static const String _amapTileUrl =
      'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=7&x={x}&y={y}&z={z}';

  late final TextEditingController _searchController;
  late final ScrollController _scrollController;
  final MapService _mapService = const AmapMapService(
    apiKey: AmapConfig.webServiceKey,
  );
  final Map<String, GlobalKey> _sectionKeys = {};
  final ValueNotifier<int> _mapPanelVersion = ValueNotifier<int>(0);
  AMapController? _nativeMapController;
  bool _nativeMapReady = false;

  late String _selectedAddress;
  late String _selectedCity;
  MapPosition? _selectedPosition;
  bool _isSpecificPlaceSelection = false;
  List<MapSuggestion> _apiSuggestions = const [];
  String? _locationSummary;
  bool _searching = false;
  bool _locatingFromMap = false;
  bool _showAllHistory = false;
  double _mapZoom = _defaultZoom;
  LatLng _mapTarget = _defaultLatLng;
  Offset _mapDragOffset = Offset.zero;
  LatLng? _dragStartTarget;
  LatLng? _lastResolvedTarget;
  int _reverseGeocodeToken = 0;
  Timer? _reverseGeocodeDebounce;

  bool get _hasWebServiceKey => AmapConfig.webServiceKey.trim().isNotEmpty;
  bool get _preferNativeAmap =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  AmapMapService? get _amapMapService =>
      _mapService is AmapMapService ? _mapService as AmapMapService : null;

  static const List<_CityEntry> _cities = [
    _CityEntry('A', '阿坝藏族羌族自治州'),
    _CityEntry('A', '阿克苏地区'),
    _CityEntry('A', '阿拉尔市'),
    _CityEntry('A', '阿拉善盟'),
    _CityEntry('A', '阿勒泰地区'),
    _CityEntry('A', '阿里地区'),
    _CityEntry('A', '安康市'),
    _CityEntry('A', '安庆市'),
    _CityEntry('A', '安顺市'),
    _CityEntry('A', '安阳市'),
    _CityEntry('B', '白城市'),
    _CityEntry('B', '白山市'),
    _CityEntry('B', '白银市'),
    _CityEntry('B', '百色市'),
    _CityEntry('B', '蚌埠市'),
    _CityEntry('B', '保定市'),
    _CityEntry('B', '保山市'),
    _CityEntry('B', '北海市'),
    _CityEntry('B', '北京市'),
    _CityEntry('B', '本溪市'),
    _CityEntry('B', '毕节市'),
    _CityEntry('B', '滨州市'),
    _CityEntry('B', '博尔塔拉蒙古自治州'),
    _CityEntry('B', '亳州市'),
    _CityEntry('C', '沧州市'),
    _CityEntry('C', '昌都市'),
    _CityEntry('C', '昌吉回族自治州'),
    _CityEntry('C', '长春市'),
    _CityEntry('C', '长沙市'),
    _CityEntry('C', '长治市'),
    _CityEntry('C', '常德市'),
    _CityEntry('C', '常州市'),
    _CityEntry('C', '朝阳市'),
    _CityEntry('C', '潮州市'),
    _CityEntry('C', '郴州市'),
    _CityEntry('C', '成都市'),
    _CityEntry('C', '承德市'),
    _CityEntry('C', '池州市'),
    _CityEntry('C', '赤峰市'),
    _CityEntry('C', '崇左市'),
    _CityEntry('C', '楚雄彝族自治州'),
    _CityEntry('C', '滁州市'),
    _CityEntry('C', '重庆市'),
    _CityEntry('D', '大理白族自治州'),
    _CityEntry('D', '大连市'),
    _CityEntry('D', '大庆市'),
    _CityEntry('D', '大同市'),
    _CityEntry('D', '大兴安岭地区'),
    _CityEntry('D', '达州市'),
    _CityEntry('D', '德宏傣族景颇族自治州'),
    _CityEntry('D', '德阳市'),
    _CityEntry('D', '德州市'),
    _CityEntry('D', '定西市'),
    _CityEntry('D', '迪庆藏族自治州'),
    _CityEntry('D', '东莞市'),
    _CityEntry('D', '东营市'),
    _CityEntry('E', '鄂尔多斯市'),
    _CityEntry('E', '鄂州市'),
    _CityEntry('E', '恩施土家族苗族自治州'),
    _CityEntry('F', '防城港市'),
    _CityEntry('F', '佛山市'),
    _CityEntry('F', '福州市'),
    _CityEntry('F', '抚顺市'),
    _CityEntry('F', '抚州市'),
    _CityEntry('F', '阜新市'),
    _CityEntry('F', '阜阳市'),
    _CityEntry('G', '甘南藏族自治州'),
    _CityEntry('G', '赣州市'),
    _CityEntry('G', '甘孜藏族自治州'),
    _CityEntry('G', '广安市'),
    _CityEntry('G', '广元市'),
    _CityEntry('G', '广州市'),
    _CityEntry('G', '贵港市'),
    _CityEntry('G', '贵阳市'),
    _CityEntry('G', '桂林市'),
    _CityEntry('G', '果洛藏族自治州'),
    _CityEntry('G', '固原市'),
    _CityEntry('H', '哈尔滨市'),
    _CityEntry('H', '哈密市'),
    _CityEntry('H', '海北藏族自治州'),
    _CityEntry('H', '海东市'),
    _CityEntry('H', '海口市'),
    _CityEntry('H', '海南藏族自治州'),
    _CityEntry('H', '海西蒙古族藏族自治州'),
    _CityEntry('H', '邯郸市'),
    _CityEntry('H', '汉中市'),
    _CityEntry('H', '杭州市'),
    _CityEntry('H', '合肥市'),
    _CityEntry('H', '和田地区'),
    _CityEntry('H', '河池市'),
    _CityEntry('H', '河源市'),
    _CityEntry('H', '菏泽市'),
    _CityEntry('H', '贺州市'),
    _CityEntry('H', '鹤壁市'),
    _CityEntry('H', '鹤岗市'),
    _CityEntry('H', '黑河市'),
    _CityEntry('H', '衡水市'),
    _CityEntry('H', '衡阳市'),
    _CityEntry('H', '红河哈尼族彝族自治州'),
    _CityEntry('H', '呼和浩特市'),
    _CityEntry('H', '呼伦贝尔市'),
    _CityEntry('H', '湖州市'),
    _CityEntry('H', '怀化市'),
    _CityEntry('H', '淮安市'),
    _CityEntry('H', '淮北市'),
    _CityEntry('H', '淮南市'),
    _CityEntry('H', '黄冈市'),
    _CityEntry('H', '黄南藏族自治州'),
    _CityEntry('H', '黄山市'),
    _CityEntry('H', '黄石市'),
    _CityEntry('H', '惠州市'),
    _CityEntry('J', '吉安市'),
    _CityEntry('J', '吉林市'),
    _CityEntry('J', '济南市'),
    _CityEntry('J', '济宁市'),
    _CityEntry('J', '佳木斯市'),
    _CityEntry('J', '嘉兴市'),
    _CityEntry('J', '嘉峪关市'),
    _CityEntry('J', '江门市'),
    _CityEntry('J', '焦作市'),
    _CityEntry('J', '揭阳市'),
    _CityEntry('J', '金昌市'),
    _CityEntry('J', '金华市'),
    _CityEntry('J', '锦州市'),
    _CityEntry('J', '晋城市'),
    _CityEntry('J', '晋中市'),
    _CityEntry('J', '荆门市'),
    _CityEntry('J', '荆州市'),
    _CityEntry('J', '景德镇市'),
    _CityEntry('J', '九江市'),
    _CityEntry('J', '酒泉市'),
    _CityEntry('K', '开封市'),
    _CityEntry('K', '克拉玛依市'),
    _CityEntry('K', '克孜勒苏柯尔克孜自治州'),
    _CityEntry('K', '昆明市'),
    _CityEntry('L', '来宾市'),
    _CityEntry('L', '廊坊市'),
    _CityEntry('L', '兰州市'),
    _CityEntry('L', '拉萨市'),
    _CityEntry('L', '乐山市'),
    _CityEntry('L', '丽江市'),
    _CityEntry('L', '丽水市'),
    _CityEntry('L', '连云港市'),
    _CityEntry('L', '凉山彝族自治州'),
    _CityEntry('L', '辽阳市'),
    _CityEntry('L', '辽源市'),
    _CityEntry('L', '聊城市'),
    _CityEntry('L', '临沧市'),
    _CityEntry('L', '临汾市'),
    _CityEntry('L', '临夏回族自治州'),
    _CityEntry('L', '临沂市'),
    _CityEntry('L', '林芝市'),
    _CityEntry('L', '柳州市'),
    _CityEntry('L', '六安市'),
    _CityEntry('L', '六盘水市'),
    _CityEntry('L', '龙岩市'),
    _CityEntry('L', '娄底市'),
    _CityEntry('L', '漯河市'),
    _CityEntry('L', '洛阳市'),
    _CityEntry('L', '吕梁市'),
    _CityEntry('L', '泸州市'),
    _CityEntry('M', '马鞍山市'),
    _CityEntry('M', '茂名市'),
    _CityEntry('M', '眉山市'),
    _CityEntry('M', '梅州市'),
    _CityEntry('M', '绵阳市'),
    _CityEntry('M', '牡丹江市'),
    _CityEntry('N', '南昌市'),
    _CityEntry('N', '南充市'),
    _CityEntry('N', '南京市'),
    _CityEntry('N', '南宁市'),
    _CityEntry('N', '南平市'),
    _CityEntry('N', '南通市'),
    _CityEntry('N', '南阳市'),
    _CityEntry('N', '那曲市'),
    _CityEntry('N', '内江市'),
    _CityEntry('N', '宁波市'),
    _CityEntry('N', '宁德市'),
    _CityEntry('N', '怒江傈僳族自治州'),
    _CityEntry('P', '盘锦市'),
    _CityEntry('P', '攀枝花市'),
    _CityEntry('P', '平顶山市'),
    _CityEntry('P', '平凉市'),
    _CityEntry('P', '萍乡市'),
    _CityEntry('P', '莆田市'),
    _CityEntry('P', '濮阳市'),
    _CityEntry('Q', '七台河市'),
    _CityEntry('Q', '齐齐哈尔市'),
    _CityEntry('Q', '黔东南苗族侗族自治州'),
    _CityEntry('Q', '黔南布依族苗族自治州'),
    _CityEntry('Q', '黔西南布依族苗族自治州'),
    _CityEntry('Q', '庆阳市'),
    _CityEntry('Q', '清远市'),
    _CityEntry('Q', '秦皇岛市'),
    _CityEntry('Q', '钦州市'),
    _CityEntry('Q', '青岛市'),
    _CityEntry('Q', '曲靖市'),
    _CityEntry('Q', '衢州市'),
    _CityEntry('Q', '泉州市'),
    _CityEntry('R', '日喀则市'),
    _CityEntry('R', '日照市'),
    _CityEntry('S', '三门峡市'),
    _CityEntry('S', '三明市'),
    _CityEntry('S', '三沙市'),
    _CityEntry('S', '三亚市'),
    _CityEntry('S', '汕头市'),
    _CityEntry('S', '汕尾市'),
    _CityEntry('S', '商洛市'),
    _CityEntry('S', '商丘市'),
    _CityEntry('S', '上海市'),
    _CityEntry('S', '上饶市'),
    _CityEntry('S', '山南市'),
    _CityEntry('S', '韶关市'),
    _CityEntry('S', '邵阳市'),
    _CityEntry('S', '绍兴市'),
    _CityEntry('S', '深圳市'),
    _CityEntry('S', '沈阳市'),
    _CityEntry('S', '十堰市'),
    _CityEntry('S', '石家庄市'),
    _CityEntry('S', '石嘴山市'),
    _CityEntry('S', '双鸭山市'),
    _CityEntry('S', '朔州市'),
    _CityEntry('S', '四平市'),
    _CityEntry('S', '松原市'),
    _CityEntry('S', '苏州市'),
    _CityEntry('S', '宿迁市'),
    _CityEntry('S', '宿州市'),
    _CityEntry('S', '绥化市'),
    _CityEntry('S', '遂宁市'),
    _CityEntry('S', '随州市'),
    _CityEntry('T', '塔城地区'),
    _CityEntry('T', '台州市'),
    _CityEntry('T', '太原市'),
    _CityEntry('T', '泰安市'),
    _CityEntry('T', '泰州市'),
    _CityEntry('T', '唐山市'),
    _CityEntry('T', '天津市'),
    _CityEntry('T', '天水市'),
    _CityEntry('T', '铁岭市'),
    _CityEntry('T', '铜川市'),
    _CityEntry('T', '铜陵市'),
    _CityEntry('T', '铜仁市'),
    _CityEntry('T', '吐鲁番市'),
    _CityEntry('W', '潍坊市'),
    _CityEntry('W', '威海市'),
    _CityEntry('W', '渭南市'),
    _CityEntry('W', '温州市'),
    _CityEntry('W', '文山壮族苗族自治州'),
    _CityEntry('W', '乌海市'),
    _CityEntry('W', '乌兰察布市'),
    _CityEntry('W', '乌鲁木齐市'),
    _CityEntry('W', '无锡市'),
    _CityEntry('W', '芜湖市'),
    _CityEntry('W', '吴忠市'),
    _CityEntry('W', '武汉市'),
    _CityEntry('W', '武威市'),
    _CityEntry('W', '梧州市'),
    _CityEntry('X', '西安市'),
    _CityEntry('X', '西宁市'),
    _CityEntry('X', '锡林郭勒盟'),
    _CityEntry('X', '厦门市'),
    _CityEntry('X', '咸宁市'),
    _CityEntry('X', '咸阳市'),
    _CityEntry('X', '湘潭市'),
    _CityEntry('X', '湘西土家族苗族自治州'),
    _CityEntry('X', '襄阳市'),
    _CityEntry('X', '孝感市'),
    _CityEntry('X', '忻州市'),
    _CityEntry('X', '新乡市'),
    _CityEntry('X', '新余市'),
    _CityEntry('X', '信阳市'),
    _CityEntry('X', '邢台市'),
    _CityEntry('X', '兴安盟'),
    _CityEntry('X', '徐州市'),
    _CityEntry('X', '宣城市'),
    _CityEntry('Y', '延安市'),
    _CityEntry('Y', '延边朝鲜族自治州'),
    _CityEntry('Y', '盐城市'),
    _CityEntry('Y', '扬州市'),
    _CityEntry('Y', '阳江市'),
    _CityEntry('Y', '阳泉市'),
    _CityEntry('Y', '伊春市'),
    _CityEntry('Y', '伊犁哈萨克自治州'),
    _CityEntry('Y', '宜宾市'),
    _CityEntry('Y', '宜昌市'),
    _CityEntry('Y', '宜春市'),
    _CityEntry('Y', '益阳市'),
    _CityEntry('Y', '银川市'),
    _CityEntry('Y', '营口市'),
    _CityEntry('Y', '永州市'),
    _CityEntry('Y', '岳阳市'),
    _CityEntry('Y', '运城市'),
    _CityEntry('Y', '玉林市'),
    _CityEntry('Y', '玉树藏族自治州'),
    _CityEntry('Y', '榆林市'),
    _CityEntry('Y', '玉溪市'),
    _CityEntry('Z', '枣庄市'),
    _CityEntry('Z', '湛江市'),
    _CityEntry('Z', '张家界市'),
    _CityEntry('Z', '张家口市'),
    _CityEntry('Z', '张掖市'),
    _CityEntry('Z', '漳州市'),
    _CityEntry('Z', '昭通市'),
    _CityEntry('Z', '肇庆市'),
    _CityEntry('Z', '镇江市'),
    _CityEntry('Z', '郑州市'),
    _CityEntry('Z', '中山市'),
    _CityEntry('Z', '中卫市'),
    _CityEntry('Z', '舟山市'),
    _CityEntry('Z', '周口市'),
    _CityEntry('Z', '株洲市'),
    _CityEntry('Z', '珠海市'),
    _CityEntry('Z', '驻马店市'),
    _CityEntry('Z', '资阳市'),
    _CityEntry('Z', '淄博市'),
    _CityEntry('Z', '自贡市'),
    _CityEntry('Z', '遵义市'),
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _scrollController = ScrollController();
    _selectedAddress = widget.initialAddress ?? widget.initialCity ?? '苏州市';
    _selectedCity = widget.initialCity ?? '苏州市';
    _locationSummary = widget.initialAddress ?? widget.initialCity ?? '请先选择地点';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _bootstrapInitialPosition();
    });
  }

  @override
  void dispose() {
    _reverseGeocodeDebounce?.cancel();
    _mapPanelVersion.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _notifyMapPanelChanged() {
    _mapPanelVersion.value++;
  }

  Map<String, dynamic> _buildSelectionResult() {
    return {
      'address': _selectedAddress,
      'city': _normalizeCityName(_selectedCity),
      'summary': _locationSummary ?? _selectedAddress,
      'latitude': _selectedPosition?.latitude,
      'longitude': _selectedPosition?.longitude,
      'isSpecificPlace': _isSpecificPlaceSelection,
    };
  }

  List<_CityEntry> get _filteredCities {
    final query = _searchController.text.trim();
    if (query.isEmpty) return _cities;
    return _cities.where((entry) => entry.name.contains(query)).toList();
  }

  Future<void> _bootstrapInitialPosition() async {
    if (!_hasWebServiceKey) return;
    final seed = widget.initialAddress?.trim().isNotEmpty == true
        ? widget.initialAddress!.trim()
        : widget.initialCity?.trim();
    if (seed == null || seed.isEmpty) return;
    _isSpecificPlaceSelection =
        widget.initialCity?.trim().isNotEmpty == true &&
        _normalizeCityName(seed) !=
            _normalizeCityName(widget.initialCity!.trim());
    await _selectPlace(
      address: seed,
      city: widget.initialCity?.trim().isNotEmpty == true
          ? widget.initialCity!.trim()
          : seed,
    );
  }

  Future<void> _searchWithApi(String keyword) async {
    setState(() {
      _searching = true;
      _apiSuggestions = const [];
    });
    try {
      final result = await _mapService.searchPlaces(
        keyword: keyword,
        city: _selectedCity,
      );
      if (!mounted) return;
      setState(() {
        _apiSuggestions = result;
        if (result.isNotEmpty) {
          final first = result.first;
          _selectedAddress = first.name;
          if (first.city.isNotEmpty) {
            _selectedCity = first.city;
          }
          if (first.latitude != null && first.longitude != null) {
            _isSpecificPlaceSelection = true;
            _selectedPosition = MapPosition(
              formattedAddress: [
                first.city,
                first.district,
                first.name,
              ].where((value) => value.isNotEmpty).join(' '),
              city: first.city,
              district: first.district,
              latitude: first.latitude,
              longitude: first.longitude,
            );
            _locationSummary = _selectedPosition!.formattedAddress;
          }
        }
      });
    } on AmapApiException catch (e) {
      if (!mounted) return;
      _showMessage(_describeAmapError(e, fallback: '地点搜索失败'));
    } catch (e) {
      if (!mounted) return;
      _showMessage('搜索失败：$e');
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final result = await _mapService.currentPosition();
      if (!mounted) return;
      if (result == null) {
        _showMessage('暂未获取到当前位置');
        return;
      }
      _applyResolvedPosition(result);
      _isSpecificPlaceSelection = true;
      await _moveMapToResolvedPosition(result);
    } on AmapApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'LOCATION_SERVICE_DISABLED') {
        _showMessage('请先开启手机定位服务');
      } else if (e.code == 'LOCATION_PERMISSION_DENIED') {
        _showMessage('请先授予定位权限');
      } else {
        _showMessage(_describeAmapError(e, fallback: '定位失败'));
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage('定位失败：$e');
    }
  }

  Future<void> _selectCity(_CityEntry city) async {
    await _selectPlace(address: city.name, city: city.name);
    if (mounted) {
      setState(() => _isSpecificPlaceSelection = false);
    }
  }

  Future<void> _selectPlace({
    required String address,
    String? city,
    double? latitude,
    double? longitude,
  }) async {
    final normalizedCity = _normalizeCityName(
      city?.trim().isNotEmpty == true ? city!.trim() : _selectedCity,
    );
    final summary = normalizedCity.isEmpty || address.contains(normalizedCity)
        ? address
        : [
            normalizedCity,
            address,
          ].where((value) => value.isNotEmpty).join(' ');

    setState(() {
      _selectedAddress = address;
      _selectedCity = normalizedCity;
      _locationSummary = summary;
      _searchController.clear();
      _apiSuggestions = const [];
    });

    if (latitude != null && longitude != null) {
      final position = MapPosition(
        formattedAddress: summary,
        city: normalizedCity,
        latitude: latitude,
        longitude: longitude,
      );
      _applyResolvedPosition(position);
      await _moveMapToResolvedPosition(position);
      return;
    }

    try {
      final resolved = await _mapService.geocodeAddress(
        address: address,
        city: normalizedCity,
      );
      if (!mounted || resolved == null) return;
      _applyResolvedPosition(
        MapPosition(
          formattedAddress: resolved.formattedAddress.isNotEmpty
              ? resolved.formattedAddress
              : summary,
          city: resolved.city.isNotEmpty ? resolved.city : normalizedCity,
          district: resolved.district,
          latitude: resolved.latitude,
          longitude: resolved.longitude,
        ),
      );
      await _moveMapToResolvedPosition(resolved);
    } on AmapApiException catch (e) {
      if (!mounted) return;
      _showMessage(_describeAmapError(e, fallback: '地点解析失败'));
    } catch (_) {
      if (!mounted) return;
      _showMessage('地点解析失败');
    }
  }

  void _applyResolvedPosition(MapPosition position) {
    final lat = position.latitude;
    final lng = position.longitude;
    final city = position.city.isNotEmpty ? position.city : _selectedCity;
    final address = position.formattedAddress.isNotEmpty
        ? position.formattedAddress
        : _selectedAddress;

    setState(() {
      _selectedPosition = MapPosition(
        formattedAddress: address,
        city: _normalizeCityName(city),
        district: position.district,
        latitude: lat,
        longitude: lng,
      );
      _selectedAddress = address;
      _selectedCity = _normalizeCityName(city);
      _locationSummary = address;
      if (lat != null && lng != null) {
        _mapTarget = _displayTargetFromWgs84(LatLng(lat, lng));
      }
    });
    _notifyMapPanelChanged();
  }

  Future<void> _moveMapToResolvedPosition(MapPosition position) async {
    final lat = position.latitude;
    final lng = position.longitude;
    if (lat == null || lng == null) return;
    final target = LatLng(lat, lng);
    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeToken++;
    if (!mounted) return;
    final displayTarget = _displayTargetFromWgs84(target);
    setState(() {
      _mapTarget = displayTarget;
    });
    _notifyMapPanelChanged();
    if (_preferNativeAmap) {
      await _moveNativeCamera(displayTarget, zoom: _mapZoom);
    }
  }

  Future<void> _moveNativeCamera(LatLng target, {double? zoom}) async {
    final controller = _nativeMapController;
    if (controller == null) return;

    try {
      await controller.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: amap_base.LatLng(target.latitude, target.longitude),
            zoom: zoom ?? _mapZoom,
          ),
        ),
      );
    } catch (_) {
      // Ignore native camera errors and keep the current fallback state.
    }
  }

  void _scheduleReverseGeocode(LatLng target) {
    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeToken++;
    _reverseGeocodeDebounce = Timer(
      const Duration(milliseconds: 700),
      () => _handleMapMoveEnd(target),
    );
  }

  Future<void> _handleMapMoveEnd(LatLng target) async {
    _reverseGeocodeDebounce?.cancel();
    _mapTarget = target;
    _isSpecificPlaceSelection = true;
    final wgsTarget = _requestTargetFromDisplay(target);
    _applyMapCoordinateFallback(wgsTarget);
    _notifyMapPanelChanged();
    if (!_hasWebServiceKey) return;
    if (_lastResolvedTarget != null &&
        _isSamePoint(_lastResolvedTarget!, wgsTarget)) {
      return;
    }
    final token = ++_reverseGeocodeToken;
    setState(() => _locatingFromMap = true);
    _notifyMapPanelChanged();
    try {
      final result = await _mapService.reverseGeocode(
        latitude: wgsTarget.latitude,
        longitude: wgsTarget.longitude,
      );
      if (!mounted || token != _reverseGeocodeToken) return;
      _lastResolvedTarget = wgsTarget;
      if (result == null) {
        setState(() {
          _selectedPosition = MapPosition(
            formattedAddress: _locationSummary ?? _selectedAddress,
            city: _selectedCity,
            latitude: wgsTarget.latitude,
            longitude: wgsTarget.longitude,
          );
        });
        _notifyMapPanelChanged();
        return;
      }
      _applyResolvedPosition(result);
    } on AmapApiException catch (e) {
      if (!mounted || token != _reverseGeocodeToken) return;
      _showMessage(_describeAmapError(e, fallback: '逆地理编码失败'));
      _applyMapCoordinateFallback(wgsTarget);
    } catch (e) {
      if (!mounted || token != _reverseGeocodeToken) return;
      _showMessage('逆地理编码失败：$e');
      _applyMapCoordinateFallback(wgsTarget);
    } finally {
      if (mounted && token == _reverseGeocodeToken) {
        setState(() => _locatingFromMap = false);
        _notifyMapPanelChanged();
      }
    }
  }

  bool _isSamePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.00001 &&
        (a.longitude - b.longitude).abs() < 0.00001;
  }

  void _applyMapCoordinateFallback(LatLng point) {
    if (!mounted) return;
    setState(() {
      _selectedPosition = MapPosition(
        formattedAddress: _locationSummary ?? _selectedAddress,
        city: _selectedCity,
        latitude: point.latitude,
        longitude: point.longitude,
      );
    });
  }

  double _worldSize(double zoom) {
    return 256 * math.pow(2, zoom).toDouble();
  }

  double _longitudeToPixelX(double longitude, double zoom) {
    return (longitude + 180.0) / 360.0 * _worldSize(zoom);
  }

  double _latitudeToPixelY(double latitude, double zoom) {
    final clamped = latitude.clamp(-85.05112878, 85.05112878).toDouble();
    final radian = clamped * math.pi / 180.0;
    return (1 - math.log(math.tan(radian) + 1 / math.cos(radian)) / math.pi) /
        2 *
        _worldSize(zoom);
  }

  LatLng _pixelToLatLng(double pixelX, double pixelY, double zoom) {
    final size = _worldSize(zoom);
    final longitude = pixelX / size * 360.0 - 180.0;
    final n = math.pi - 2.0 * math.pi * pixelY / size;
    final latitude =
        180.0 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    return LatLng(latitude, longitude);
  }

  LatLng _offsetTarget(LatLng center, Offset pixelOffset, double zoom) {
    final pixelX = _longitudeToPixelX(center.longitude, zoom) + pixelOffset.dx;
    final pixelY = _latitudeToPixelY(center.latitude, zoom) + pixelOffset.dy;
    return _pixelToLatLng(pixelX, pixelY, zoom);
  }

  LatLng _targetFromTap(Offset localPosition, Size size) {
    final pixelOffset = Offset(
      localPosition.dx - size.width / 2,
      localPosition.dy - size.height / 2,
    );
    return _offsetTarget(_mapTarget, pixelOffset, _mapZoom);
  }

  void _beginMapDrag() {
    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeToken++;
    _dragStartTarget = _mapTarget;
    _mapDragOffset = Offset.zero;
  }

  void _updateMapDrag(Offset delta) {
    if (_dragStartTarget == null) return;
    final nextOffset = _mapDragOffset + delta;
    final previewTarget = _offsetTarget(
      _dragStartTarget!,
      Offset(-nextOffset.dx, -nextOffset.dy),
      _mapZoom,
    );
    setState(() {
      _mapDragOffset = nextOffset;
      _mapTarget = previewTarget;
    });
    _notifyMapPanelChanged();
  }

  Future<void> _finishMapDrag() async {
    final target = _mapTarget;
    setState(() {
      _mapDragOffset = Offset.zero;
      _dragStartTarget = null;
    });
    _notifyMapPanelChanged();
    _scheduleReverseGeocode(target);
  }

  void _cancelMapDrag() {
    final target = _dragStartTarget;
    if (target == null) return;
    setState(() {
      _mapTarget = target;
      _mapDragOffset = Offset.zero;
      _dragStartTarget = null;
    });
    _notifyMapPanelChanged();
  }

  String _buildAmapTileUrl(int x, int y, int z) {
    final subdomain = ((x + y).abs() % 4) + 1;
    return _amapTileUrl
        .replaceFirst('{s}', subdomain.toString())
        .replaceFirst('{x}', x.toString())
        .replaceFirst('{y}', y.toString())
        .replaceFirst('{z}', z.toString());
  }

  Widget _buildAmapTileSurface() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final zoom = _mapZoom.round().clamp(3, 18);
        final zoomDouble = zoom.toDouble();
        final tileCount = 1 << zoom;
        final centerX = _longitudeToPixelX(_mapTarget.longitude, zoomDouble);
        final centerY = _latitudeToPixelY(_mapTarget.latitude, zoomDouble);
        final topLeftX = centerX - size.width / 2;
        final topLeftY = centerY - size.height / 2;
        final startTileX = (topLeftX / 256).floor() - 1;
        final endTileX = ((topLeftX + size.width) / 256).floor() + 1;
        final startTileY = (topLeftY / 256).floor() - 1;
        final endTileY = ((topLeftY + size.height) / 256).floor() + 1;

        final tiles = <Widget>[];
        for (var tileY = startTileY; tileY <= endTileY; tileY++) {
          if (tileY < 0 || tileY >= tileCount) continue;
          for (var tileX = startTileX; tileX <= endTileX; tileX++) {
            final wrappedX = ((tileX % tileCount) + tileCount) % tileCount;
            final left = tileX * 256 - topLeftX;
            final top = tileY * 256 - topLeftY;
            tiles.add(
              Positioned(
                left: left,
                top: top,
                width: 256,
                height: 256,
                child: Image.network(
                  _buildAmapTileUrl(wrappedX, tileY, zoom),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFEAF1FF),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.map_outlined,
                      size: 18,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
            );
          }
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) async {
            final target = _targetFromTap(details.localPosition, size);
            setState(() => _mapTarget = target);
            _notifyMapPanelChanged();
            await _handleMapMoveEnd(target);
          },
          onPanStart: (_) => _beginMapDrag(),
          onPanUpdate: (details) => _updateMapDrag(details.delta),
          onPanEnd: (_) => _finishMapDrag(),
          onPanCancel: _cancelMapDrag,
          child: Stack(children: tiles),
        );
      },
    );
  }

  Future<void> _openFullscreenMap() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute<Map<String, dynamic>>(
        builder: (context) {
          return ValueListenableBuilder<int>(
            valueListenable: _mapPanelVersion,
            builder: (context, _, __) {
              return Scaffold(
                backgroundColor: Colors.white,
                body: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 18,
                              ),
                            ),
                            const Expanded(
                              child: Text(
                                '地图选点',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _useCurrentLocation,
                              icon: const Icon(
                                Icons.my_location_outlined,
                                size: 18,
                              ),
                              label: const Text('定位'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: _buildMapPanel(isFullscreen: true),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
    if (!mounted || result == null) return;
    Navigator.of(context).pop(result);
  }

  Widget _buildStaticMapFallback() {
    return Container(
      color: const Color(0xFFEAF1FF),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, size: 42, color: AppColors.primary),
          SizedBox(height: 10),
          Text(
            '地图暂时加载失败',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  /* LatLng _pointFromDesktopTap(Offset localPosition, Size size) {
    final dx = localPosition.dx - size.width / 2;
    final dy = localPosition.dy - size.height / 2;
    final lngSpan = 360 / (1 << _mapZoom.round().clamp(3, 18));
    final latSpan = lngSpan * size.height / size.width;
    final longitude = _cameraTarget.longitude + dx / size.width * lngSpan;
    final latitude = _cameraTarget.latitude - dy / size.height * latSpan;
    return LatLng(latitude.clamp(-85.0, 85.0), longitude.clamp(-180.0, 180.0));
  } */

  LatLng _displayTargetFromWgs84(LatLng point) {
    return _amapMapService?.toGcj02LatLng(point) ?? point;
  }

  LatLng _requestTargetFromDisplay(LatLng point) {
    return _amapMapService?.toWgs84LatLng(point) ?? point;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCities;
    final grouped = <String, List<_CityEntry>>{};
    for (final item in filtered) {
      grouped.putIfAbsent(item.letter, () => []).add(item);
    }
    final letters = grouped.keys.toList()..sort();
    for (final letter in letters) {
      _sectionKeys.putIfAbsent(letter, () => GlobalKey());
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                  ),
                  Expanded(child: _buildSearchField()),
                  const SizedBox(width: 8),
                  _buildMapEntryButton(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: _buildLocationOverview(),
            ),
            Expanded(
              child: Stack(
                children: [
                  _buildLocationBody(filtered, grouped, letters),
                  Positioned(
                    right: 6,
                    top: 8,
                    bottom: 8,
                    child: SizedBox(
                      width: 22,
                      child: ListView(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          GestureDetector(
                            onTap: () => _scrollController.animateTo(
                              0,
                              duration: const Duration(milliseconds: 220),
                              curve: Curves.easeOut,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 3,
                              ),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: AppColors.tagBackground,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                '顶',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          ...'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
                              .split('')
                              .map(
                                (letter) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 1,
                                  ),
                                  child: GestureDetector(
                                    onTap: () => _jumpToLetter(letter, grouped),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: Center(
                                        child: Text(
                                          letter,
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: grouped.containsKey(letter)
                                                ? AppColors.textSecondary
                                                : AppColors.textHint,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(_buildSelectionResult()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              child: const Text('选择此地点'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMapEntryButton() {
    return InkWell(
      onTap: _openFullscreenMap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 18, color: AppColors.primary),
            SizedBox(width: 6),
            Text(
              '地图选点',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationOverview() {
    final summary = _locationSummary ?? '正在获取当前位置';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '当前位置',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textHint,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _useCurrentLocation,
              icon: const Icon(Icons.my_location_outlined, size: 18),
              label: const Text('重新定位'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.place_outlined,
              size: 22,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summary,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _cityPill(_selectedCity),
            _cityPill('全国', muted: true),
            _cityPill('苏州'),
            _cityPill('北京'),
            _cityPill('上海'),
            _cityPill('深圳'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              '历史访问',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textHint,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () =>
                  setState(() => _showAllHistory = !_showAllHistory),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _showAllHistory ? '收起' : '展开更多',
                style: const TextStyle(color: AppColors.textHint),
              ),
            ),
          ],
        ),
        if (_showAllHistory) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final city in const ['杭州', '南京', '无锡', '常州'])
                _cityPill(city),
            ],
          ),
        ],
      ],
    );
  }

  Widget _cityPill(String label, {bool muted = false}) {
    final selected = label == _selectedCity;
    return InkWell(
      onTap: () =>
          _selectCity(_CityEntry(label.isEmpty ? 'S' : label[0], label)),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : muted
              ? const Color(0xFFF4F4F4)
              : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.textPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {});
          final keyword = value.trim();
          if (keyword.isNotEmpty) {
            _searchWithApi(keyword);
          } else {
            setState(() => _apiSuggestions = const []);
          }
        },
        decoration: const InputDecoration(
          hintText: '城市/区县/商场等地点',
          prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textHint),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildCurrentLocationCard() {
    final summary = _locationSummary ?? '尚未定位';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.tagBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, size: 16, color: AppColors.textHint),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '当前位置：$summary',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: _useCurrentLocation,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '重新定位',
              style: TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationBody(
    List<_CityEntry> filtered,
    Map<String, List<_CityEntry>> grouped,
    List<String> letters,
  ) {
    final keyword = _searchController.text.trim();
    if (keyword.isNotEmpty) {
      return _searching
          ? const Center(child: CircularProgressIndicator())
          : _apiSuggestions.isNotEmpty
          ? _buildApiSearchResults(_apiSuggestions)
          : _buildSearchResults(filtered);
    }
    return _buildGroupedList(grouped, letters);
  }

  Widget _buildSearchResults(List<_CityEntry> items) {
    if (items.isEmpty) {
      return const Center(child: Text('没有找到匹配地点'));
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFEAEAEA)),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildSearchResultTile(
          title: item.name,
          subtitle: '城市',
          selected: item.name == _selectedAddress,
          onTap: () => _selectCity(item),
        );
      },
    );
  }

  Widget _buildApiSearchResults(List<MapSuggestion> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      itemCount: items.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, color: Color(0xFFEAEAEA)),
      itemBuilder: (context, index) {
        final item = items[index];
        final subtitle = [
          item.city,
          item.district,
        ].where((value) => value.isNotEmpty).join(' ');
        return _buildSearchResultTile(
          title: item.name,
          subtitle: subtitle.isEmpty ? '高德搜索结果' : subtitle,
          selected: item.name == _selectedAddress,
          onTap: () => _selectPlace(
            address: item.name,
            city: item.city.isNotEmpty ? item.city : _selectedCity,
            latitude: item.latitude,
            longitude: item.longitude,
          ),
        );
      },
    );
  }

  Widget _buildSearchResultTile({
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.place_outlined, color: AppColors.textHint),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : null,
      onTap: onTap,
    );
  }

  Widget _buildGroupedList(
    Map<String, List<_CityEntry>> grouped,
    List<String> letters,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(18, 0, 28, 20),
      itemCount: letters.length,
      itemBuilder: (context, index) {
        final letter = letters[index];
        final items = grouped[letter] ?? const [];
        return Container(
          key: _sectionKeys[letter],
          margin: const EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(
                  letter,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFDADADA))),
                ),
                child: Column(
                  children: items
                      .map(
                        (item) => _buildCityTile(
                          item,
                          showBottomBorder: item != items.last,
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCityTile(_CityEntry item, {required bool showBottomBorder}) {
    final selected =
        item.name == _selectedAddress || item.name == _selectedCity;
    return InkWell(
      onTap: () => _selectCity(item),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: showBottomBorder
                  ? const Color(0xFFDADADA)
                  : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  fontSize: 15,
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                size: 18,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNativeMapSurface() {
    return AMapWidget(
      privacyStatement: const amap_base.AMapPrivacyStatement(
        hasContains: true,
        hasShow: true,
        hasAgree: true,
      ),
      apiKey: AmapConfig.hasAndroidKey
          ? const amap_base.AMapApiKey(androidKey: AmapConfig.androidKey)
          : null,
      initialCameraPosition: CameraPosition(
        target: amap_base.LatLng(_mapTarget.latitude, _mapTarget.longitude),
        zoom: _mapZoom,
      ),
      myLocationStyleOptions: MyLocationStyleOptions(
        true,
        circleFillColor: const Color(0x223D6CF5),
        circleStrokeColor: const Color(0x883D6CF5),
        circleStrokeWidth: 1.2,
      ),
      compassEnabled: false,
      scaleEnabled: false,
      touchPoiEnabled: true,
      buildingsEnabled: true,
      onMapCreated: (controller) {
        _nativeMapController = controller;
        _nativeMapReady = true;
        // The location button can be pressed before the native map finishes
        // creating its platform view. Apply the latest target once it is
        // ready instead of losing that request.
        _moveNativeCamera(_mapTarget, zoom: _mapZoom);
      },
      onCameraMove: (position) {
        if (!_nativeMapReady) return;
        final target = LatLng(
          position.target.latitude,
          position.target.longitude,
        );
        if (!mounted) return;
        setState(() {
          _mapTarget = target;
          _mapZoom = position.zoom;
        });
        _notifyMapPanelChanged();
      },
      onCameraMoveEnd: (position) {
        final target = LatLng(
          position.target.latitude,
          position.target.longitude,
        );
        if (!mounted) return;
        setState(() {
          _mapTarget = target;
          _mapZoom = position.zoom;
        });
        _scheduleReverseGeocode(target);
      },
      onTap: (point) async {
        final target = LatLng(point.latitude, point.longitude);
        if (!mounted) return;
        setState(() => _mapTarget = target);
        _notifyMapPanelChanged();
        await _handleMapMoveEnd(target);
      },
    );
  }

  Widget _buildMapTopBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.near_me_outlined,
            size: 16,
            color: AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            _selectedCity.isEmpty ? '定位中' : _selectedCity,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPanel({bool isFullscreen = false}) {
    if (!_hasWebServiceKey) {
      return _buildMapMessageCard(
        title: '请先填写高德 Web Service Key',
        description: '地图预览、地点搜索和逆地理编码都依赖高德 Web Service Key。',
      );
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final bottomHintWidthFactor = screenWidth < 600
        ? 0.93
        : isFullscreen
        ? 0.84
        : 0.78;

    return Container(
      height: isFullscreen ? null : 360,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isFullscreen ? 24 : 20),
        border: Border.all(color: const Color(0xFFD7E4FF)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _preferNativeAmap
                ? _buildNativeMapSurface()
                : _buildAmapTileSurface(),
          ),
          Positioned(
            left: 14,
            right: 14,
            top: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMapTopBadge(),
                const SizedBox(height: 10),
                _buildMapInfoCard(),
              ],
            ),
          ),
          const IgnorePointer(
            child: Center(
              child: Icon(
                Icons.location_on,
                size: 46,
                color: AppColors.primary,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: FractionallySizedBox(
                widthFactor: bottomHintWidthFactor,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: isFullscreen
                        ? SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _locatingFromMap
                                  ? null
                                  : () => Navigator.of(
                                      context,
                                    ).pop(_buildSelectionResult()),
                              icon: const Icon(Icons.check_rounded),
                              label: Text(
                                _locatingFromMap ? '正在识别地址...' : '确认该地址',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.primary
                                    .withValues(alpha: 0.55),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                            ),
                          )
                        : Row(
                            children: [
                              if (_locatingFromMap)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.touch_app_outlined,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '拖动地图或点击位置即可选点',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapArea() {
    return _buildMapPanel();
  }

  /* Widget _buildWindowsMapArea() {
    if (!_hasWebServiceKey) {
      return _buildMapMessageCard(
        title: '请先填写高德 Web Service Key',
        description: '地图预览、地点搜索和逆地理编码都依赖高德 Web Service Key，请先补上 webServiceKey。',
      );
    }

    final hintText = _isMobilePlatform
        ? '移动端预览模式：点击地图或先搜索地点，系统会自动识别当前地点地址'
        : '桌面预览模式：点击地图或使用方向键微调中心点，系统会自动识别当前地点地址';

    final mapUrl = _mapService.staticMapUrl(
      latitude: _cameraTarget.latitude,
      longitude: _cameraTarget.longitude,
      zoom: _mapZoom.round().clamp(3, 18),
      width: 800,
      height: 420,
    );

    return Container(
      height: 280,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD7E4FF)),
        color: const Color(0xFFF2F4F8),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = Size(
                  constraints.maxWidth,
                  constraints.maxHeight,
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) async {
                    final target = _pointFromDesktopTap(
                      details.localPosition,
                      size,
                    );
                    await _handleMapMoveEnd(target);
                  },
                  child: mapUrl == null || mapUrl.isEmpty
                      ? _buildMapFallback()
                      : Image.network(
                          mapUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildMapFallback(),
                        ),
                );
              },
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.04),
                    Colors.black.withValues(alpha: 0.10),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            top: 14,
            child: _buildMapInfoCard(),
          ),
          const IgnorePointer(
            child: Center(
              child: Icon(
                Icons.location_on,
                size: 46,
                color: AppColors.primary,
              ),
            ),
          ),
          if (!_isMobilePlatform)
            Positioned(
              right: 14,
              bottom: 62,
              child: _buildDesktopMapPad(),
            ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_locatingFromMap)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.map_outlined,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hintText,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  } */

  String _normalizeCityName(String? raw) {
    final city = (raw ?? '').trim();
    if (city.isEmpty) return '';
    const suffixes = ['特别行政区', '自治州', '自治县', '自治区', '地区', '盟', '市'];
    for (final suffix in suffixes) {
      if (city.endsWith(suffix) && city.length > suffix.length) {
        return city.substring(0, city.length - suffix.length);
      }
    }
    return city;
  }

  Widget _buildMapInfoCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _locationSummary ?? '请先搜索、定位，或直接拖动地图选择地点',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _useCurrentLocation,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('定位', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  /* Widget _buildMapFallback() {
    return Container(
      color: const Color(0xFFEAF1FF),
      alignment: Alignment.center,
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.map_outlined,
            size: 42,
            color: AppColors.primary,
          ),
          SizedBox(height: 10),
          Text(
            '地图预览加载中',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  } */

  /* Widget _buildDesktopMapPad() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _mapPadButton(
            icon: Icons.keyboard_arrow_up,
            onTap: () => _nudgeDesktopSelection(0, 1),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _mapPadButton(
                icon: Icons.keyboard_arrow_left,
                onTap: () => _nudgeDesktopSelection(-1, 0),
              ),
              const SizedBox(width: 6),
              _mapPadButton(
                icon: Icons.add,
                onTap: () => _changeDesktopZoom(1),
              ),
              const SizedBox(width: 6),
              _mapPadButton(
                icon: Icons.keyboard_arrow_right,
                onTap: () => _nudgeDesktopSelection(1, 0),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 42),
              _mapPadButton(
                icon: Icons.keyboard_arrow_down,
                onTap: () => _nudgeDesktopSelection(0, -1),
              ),
              const SizedBox(width: 6),
              _mapPadButton(
                icon: Icons.remove,
                onTap: () => _changeDesktopZoom(-1),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mapPadButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.tagBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
    );
  }

  Future<void> _nudgeDesktopSelection(int xDirection, int yDirection) async {
    final factor = 0.02 / _mapZoom.clamp(4, 18);
    final next = LatLng(
      _cameraTarget.latitude - (yDirection * factor),
      _cameraTarget.longitude + (xDirection * factor),
    );
    await _handleMapMoveEnd(next);
  }

  Future<void> _changeDesktopZoom(int delta) async {
    setState(() {
      _mapZoom = (_mapZoom + delta).clamp(3, 18).toDouble();
    });
    await _handleMapMoveEnd(_cameraTarget);
  } */

  Widget _buildMapMessageCard({
    required String title,
    required String description,
  }) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF1FF), Color(0xFFF7FAFF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(color: const Color(0xFFD7E4FF)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_outlined, size: 40, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _jumpToLetter(String letter, Map<String, List<_CityEntry>> grouped) {
    if (!grouped.containsKey(letter)) {
      _showMessage('$letter 类地点暂未接入');
      return;
    }
    final key = _sectionKeys[letter];
    final currentContext = key?.currentContext;
    if (currentContext != null) {
      Scrollable.ensureVisible(
        currentContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        alignment: 0.08,
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _describeAmapError(
    AmapApiException error, {
    String fallback = '高德服务调用失败',
  }) {
    if (error.code == '10009') {
      return '高德 Key 与当前平台不匹配。Web 请检查 AMAP_WEB_SERVICE_KEY，Android 请检查 AMAP_ANDROID_KEY、包名和 SHA1。';
    }
    return '$fallback：${error.code} ${error.info}';
  }
}

class _CityEntry {
  final String letter;
  final String name;

  const _CityEntry(this.letter, this.name);
}
