import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/guide.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/payment_service.dart';
import '../../widgets/time_range_picker.dart';

class OrderCreatePage extends StatefulWidget {
  final Guide guide;

  const OrderCreatePage({super.key, required this.guide});

  @override
  State<OrderCreatePage> createState() => _OrderCreatePageState();
}

class _OrderCreatePageState extends State<OrderCreatePage> {
  final TextEditingController _noteController = TextEditingController();

  late final List<_ServiceOption> _serviceOptions;
  late String _selectedAddress;
  double? _serviceLat;
  double? _serviceLng;
  String _serviceCity = '';

  DateTime _serviceDateTime = DateTime.now().add(
    const Duration(days: 1, hours: 2),
  );
  bool _hasSelectedTime = false;
  int _maleCount = 0;
  int _femaleCount = 0;
  String _paymentMethod = 'alipay';
  bool _agreed = true;
  bool _isSubmitting = false;
  double _serviceHours = 0;

  int get _peopleCount => _maleCount + _femaleCount;

  String get _genderSummary {
    final parts = <String>[];
    if (_maleCount > 0) parts.add('${_maleCount}男');
    if (_femaleCount > 0) parts.add('${_femaleCount}女');
    return parts.isEmpty ? '请选择人数' : parts.join('');
  }

  List<_ServiceOption> get _selectedServices =>
      _serviceOptions.where((item) => item.count > 0).toList();

  double get _serviceSubtotal {
    final selected = _selectedService;
    return selected == null ? 0 : selected.price * _serviceHours;
  }

  _ServiceOption? get _selectedService =>
      _serviceOptions.where((item) => item.count > 0).isEmpty
      ? null
      : _serviceOptions.where((item) => item.count > 0).first;

  double get _estimatedTravelFee {
    final distance = _guideDistanceMeters;
    if (distance == null || distance <= 0) return 0;
    final km = distance / 1000;
    final time = _serviceDateTime.hour + _serviceDateTime.minute / 60;
    var base = 9.4;
    var rate = _isWeekend ? 1.44 : 1.38;
    var minuteRate = _isWeekend ? 0.28 : 0.31;
    if (_isWeekend) {
      if ((time >= 0 && time < 6) || time >= 23) {
        base = 10.2;
        rate = 2.44;
        minuteRate = 0.33;
      } else if (time >= 7 && time < 9) {
        base = 9.7;
        rate = 1.49;
        minuteRate = 0.42;
      } else if (time >= 16 && time < 19) {
        base = 10.2;
        rate = 1.48;
        minuteRate = 0.43;
      } else if (time >= 20 && time < 22) {
        base = 9.8;
        rate = 1.44;
        minuteRate = 0.35;
      }
    } else if (time < 5 || time >= 23) {
      base = 10.2;
      rate = 2.38;
      minuteRate = 0.35;
    } else if (time >= 7 && time < 9) {
      base = 10.3;
      rate = 1.58;
      minuteRate = 0.47;
    } else if (time >= 17 && time < 19) {
      base = 9.9;
      rate = 1.56;
      minuteRate = 0.43;
    }
    final minutes = (distance / 1000 / 30 * 60).round().clamp(8, 999);
    final longFee =
        (km - 12).clamp(0, 12) * 0.39 +
        (km - 24).clamp(0, 11) * 0.60 +
        (km - 35).clamp(0, 999) * 0.68;
    return double.parse(
      (base +
              (km - 3).clamp(0, 999) * rate +
              (minutes - 8).clamp(0, 999) * minuteRate +
              longFee)
          .toStringAsFixed(2),
    );
  }

  bool get _isWeekend =>
      _serviceDateTime.weekday == DateTime.saturday ||
      _serviceDateTime.weekday == DateTime.sunday;

  int? get _guideDistanceMeters {
    final lat1 = widget.guide.currentLat;
    final lng1 = widget.guide.currentLng;
    if (lat1 == null ||
        lng1 == null ||
        _serviceLat == null ||
        _serviceLng == null)
      return null;
    const earthRadius = 6371000.0;
    final dLat = (_serviceLat! - lat1) * 3.141592653589793 / 180;
    final dLng = (_serviceLng! - lng1) * 3.141592653589793 / 180;
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1 * 3.141592653589793 / 180) *
            cos(_serviceLat! * 3.141592653589793 / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    // Match the server's conservative road-distance estimate used for fare
    // calculation. The server remains authoritative when the order is saved.
    return (earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a)) * 1.15).round();
  }

  @override
  void initState() {
    super.initState();
    _selectedAddress = '';
    _serviceCity = widget.guide.city;
    _serviceOptions = _buildInitialServices();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  List<_ServiceOption> _buildInitialServices() {
    return widget.guide.serviceItems
        .map((item) {
          final price = double.tryParse('${item['price_per_hour'] ?? 0}') ?? 0;
          return _ServiceOption(
            id: item['id']?.toString() ?? '',
            title: (item['service_type'] ?? item['name'] ?? '').toString(),
            subtitle: (item['description'] ?? '').toString(),
            price: price,
            count: 0,
          );
        })
        .where(
          (item) =>
              item.id.isNotEmpty && item.title.isNotEmpty && item.price > 0,
        )
        .toList();
  }

  Future<void> _pickLocation() async {
    final result = await context.push<Map<String, dynamic>>(
      '/order/location',
      extra: {'address': _selectedAddress, 'city': widget.guide.city},
    );
    if (result != null && mounted) {
      setState(() {
        _selectedAddress =
            result['summary']?.toString() ??
            result['address']?.toString() ??
            _selectedAddress;
        _serviceCity = result['city']?.toString().trim().isNotEmpty == true
            ? result['city'].toString().trim()
            : _serviceCity;
        _serviceLat = (result['latitude'] as num?)?.toDouble();
        _serviceLng = (result['longitude'] as num?)?.toDouble();
      });
    }
  }

  bool _guideSlotAvailable(DateTime slot) {
    final dateOnly = DateTime(slot.year, slot.month, slot.day);
    final slotMinutes = slot.hour * 60 + slot.minute;
    for (final rule in widget.guide.availability) {
      if (rule['is_available'] == false) continue;
      final startDate = DateTime.tryParse(
        rule['date_start']?.toString() ??
            rule['service_date']?.toString() ??
            '',
      );
      final endDate = DateTime.tryParse(
        rule['date_end']?.toString() ?? rule['service_date']?.toString() ?? '',
      );
      final type = rule['recurrence_type']?.toString() ?? 'exact';
      final inDateRange =
          startDate == null ||
          (dateOnly.isAfter(
                DateTime(
                  startDate.year,
                  startDate.month,
                  startDate.day,
                ).subtract(const Duration(days: 1)),
              ) &&
              (endDate == null ||
                  dateOnly.isBefore(
                    DateTime(
                      endDate.year,
                      endDate.month,
                      endDate.day,
                    ).add(const Duration(days: 1)),
                  )));
      if (!inDateRange) continue;
      if (type == 'weekly') {
        final weekdays =
            (rule['weekdays'] as List?)
                ?.map((item) => int.tryParse(item.toString()))
                .whereType<int>()
                .toSet() ??
            const <int>{};
        if (!weekdays.contains(dateOnly.weekday)) continue;
      } else if (type == 'exact' &&
          startDate != null &&
          DateTime(startDate.year, startDate.month, startDate.day) !=
              dateOnly) {
        continue;
      }
      int? parseMinutes(dynamic value) {
        final parts = value?.toString().split(':') ?? const <String>[];
        if (parts.length < 2) return null;
        final hour = int.tryParse(parts[0]);
        final minute = int.tryParse(parts[1]);
        return hour == null || minute == null ? null : hour * 60 + minute;
      }

      final startMinutes = parseMinutes(rule['start_time']);
      final endMinutes = parseMinutes(rule['end_time']);
      if (startMinutes != null &&
          endMinutes != null &&
          slotMinutes >= startMinutes &&
          slotMinutes < endMinutes) {
        return true;
      }
    }
    return false;
  }

  Future<void> _pickTime() async {
    final result = await showAppTimeRangePicker(
      context,
      initialStart: _serviceDateTime,
      initialEnd: _serviceDateTime.add(
        Duration(hours: _serviceHours.round().clamp(1, 24)),
      ),
      dateCount: 7,
      minHours: 1,
      title: '选择服务时间',
      subtitle: '只能选择地陪已设置的接单时段，点击开始和结束时间',
      isSlotAvailable: _guideSlotAvailable,
    );
    if (result != null && mounted) {
      setState(() {
        _serviceDateTime = result.start;
        _serviceHours = result.hours.toDouble();
        _hasSelectedTime = true;
      });
    }
  }

  void _pickPeopleAndGender() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        var tempMaleCount = _maleCount;
        var tempFemaleCount = _femaleCount;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                18,
                20,
                20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '服务人数及性别',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '客户人数及性别',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPersonCounter(
                    label: '男性',
                    count: tempMaleCount,
                    onChanged: (value) => setModalState(() {
                      tempMaleCount = value;
                    }),
                  ),
                  const SizedBox(height: 12),
                  _buildPersonCounter(
                    label: '女性',
                    count: tempFemaleCount,
                    onChanged: (value) => setModalState(() {
                      tempFemaleCount = value;
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '当前：${tempMaleCount > 0 ? '${tempMaleCount}男' : ''}${tempFemaleCount > 0 ? '${tempFemaleCount}女' : ''}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        if (tempMaleCount + tempFemaleCount < 1) return;
                        setState(() {
                          _maleCount = tempMaleCount;
                          _femaleCount = tempFemaleCount;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: const Text(
                        '确认',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPersonCounter({
    required String label,
    required int count,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          onPressed: count == 0 ? null : () => onChanged(count - 1),
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          onPressed: count >= 20 ? null : () => onChanged(count + 1),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Future<void> _showOrderNotice() async {
    final remarkController = TextEditingController(text: _noteController.text);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '订单须知',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildNoticeItem('下单前请先确认服务地点、时间和人数。'),
              _buildNoticeItem('如行程临时变化，请尽量提前与对方沟通。'),
              _buildNoticeItem('平台将提供服务履约与安全保障支持。'),
              const SizedBox(height: 16),
              const Text(
                '补充说明（可选）',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: remarkController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: '例如：希望提前 10 分钟到达，或有额外的陪同需求',
                  filled: true,
                  fillColor: const Color(0xFFF6F6F0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(ctx, remarkController.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text(
                    '完成',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        _noteController.text = result;
      });
    }
  }

  Future<void> _showPaymentPendingDialog(String message) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('订单已保留'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitOrder() async {
    FocusScope.of(context).unfocus();

    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择至少一项服务')));
      return;
    }
    if (_selectedAddress.trim().isEmpty ||
        _serviceLat == null ||
        _serviceLng == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择服务地点')));
      return;
    }
    if (!_hasSelectedTime || _serviceHours <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择服务时间')));
      return;
    }
    if (_peopleCount <= 0 || (_maleCount == 0 && _femaleCount == 0)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写服务人数和性别')));
      return;
    }
    if (_paymentMethod != 'alipay') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('微信支付暂未支持，请选择支付宝支付')));
      return;
    }
    if (!_agreed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先勾选协议')));
      return;
    }

    final userId = context.read<UserProvider>().user.id;
    if (userId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }
    if (context.read<UserProvider>().isBanned) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前账号受限，暂时不能下单')));
      return;
    }
    if (widget.guide.id.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('陪伴信息异常，请重新进入页面')));
      return;
    }
    if (widget.guide.id == userId) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('不能给自己下单，请选择其他陪伴')));
      return;
    }

    final amount = _serviceSubtotal + _estimatedTravelFee;
    if (amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('订单金额异常，请重新选择服务')));
      return;
    }

    setState(() => _isSubmitting = true);

    Order? createdOrder;
    try {
      final title = _selectedServices.map((item) => item.title).join('、');
      final detail = _noteController.text.trim();
      final serviceSummary = [
        _selectedServices.map((item) => item.title).join('、'),
        _selectedAddress,
        _genderSummary,
      ].join(' / ');

      final newOrder = Order(
        id: '',
        userId: userId,
        guideId: widget.guide.id,
        guideName: widget.guide.name,
        guideAvatar: widget.guide.avatar,
        status: OrderStatus.pendingPayment,
        amount: amount,
        serviceName: detail.isEmpty
            ? serviceSummary
            : '$serviceSummary / $detail',
        serviceAddress: _selectedAddress,
        serviceCity: _serviceCity,
        serviceLat: _serviceLat,
        serviceLng: _serviceLng,
        serviceItemId: _selectedService!.id,
        serviceHours: _serviceHours,
        paymentMethod: _paymentMethod,
        paymentStatus: 'pending',
        merchantOrderNo:
            'BX${DateTime.now().millisecondsSinceEpoch}${userId.replaceAll('-', '').substring(0, userId.length > 8 ? 8 : userId.length)}',
        serviceDate: _serviceDateTime,
        createdAt: DateTime.now(),
      );

      createdOrder = await context.read<OrderProvider>().createOrder(
        newOrder.copyWith(
          serviceName: title.isEmpty
              ? newOrder.serviceName
              : '$title / ${newOrder.serviceName}',
        ),
      );

      if (!mounted) {
        return;
      }
      final paymentResult = await context.read<OrderProvider>().payOrder(
        createdOrder.id,
      );
      if (!mounted) return;

      if (paymentResult.outcome == PaymentOutcome.success &&
          paymentResult.success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('支付成功')));
        context.pop();
        return;
      }

      final message = paymentResult.outcome == PaymentOutcome.cancelled
          ? '已取消支付，订单已保留，可到订单中心继续支付。'
          : '订单已创建，但支付未完成，可到订单中心继续支付。';
      await _showPaymentPendingDialog(message);
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (mounted) {
        if (createdOrder != null) {
          await _showPaymentPendingDialog('订单已创建，但支付暂未完成。你可以到订单中心继续支付。');
          if (mounted) context.pop();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建失败: $e'), backgroundColor: Colors.red),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _updateServiceCount(int index, int delta) {
    setState(() {
      for (var i = 0; i < _serviceOptions.length; i++) {
        _serviceOptions[i].count = i == index ? 1 : 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '选择服务',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF777777),
                        ),
                        children: [
                          const TextSpan(text: '共'),
                          TextSpan(
                            text: '${_serviceOptions.length}',
                            style: const TextStyle(
                              color: Color(0xFFF2A13E),
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const TextSpan(text: '项可选'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildServiceCard(),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildPricingCard(),
                  ),
                  const SizedBox(height: 14),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildOrderNoticeButton(),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionGap(),
                  _buildInfoCard(),
                  _buildSectionGap(),
                  _buildPaymentCard(),
                  _buildSectionGap(),
                  _buildAgreementRow(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard() {
    if (_serviceOptions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          '该用户未上架项目，请返回选择其他地陪。',
          style: TextStyle(color: Color(0xFF777777)),
        ),
      );
    }
    return Column(
      children: List.generate(_serviceOptions.length, (index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == _serviceOptions.length - 1 ? 0 : 30,
          ),
          child: _buildServiceItem(_serviceOptions[index], index),
        );
      }),
    );
  }

  Widget _buildServiceItem(_ServiceOption item, int index) {
    final selected = item.count > 0;
    final hasDuration = selected && _hasSelectedTime && _serviceHours > 0;
    final displayedPrice = hasDuration
        ? item.price * _serviceHours
        : item.price;
    final priceUnit = hasDuration
        ? '/共${_serviceHours.toStringAsFixed(0)}小时'
        : '/小时';
    return GestureDetector(
      onTap: () => _updateServiceCount(index, 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF4F9DE) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFEDEDED),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFCFFF36), Color(0xFFF1FFC3)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.spa_outlined,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: Color(0xFF808080),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 132,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '¥${displayedPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFFF5A2D),
                          ),
                        ),
                        TextSpan(
                          text: priceUnit,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF5A2D),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    selected ? '已选择' : '点击选择',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppColors.primaryDark
                          : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard() {
    final serviceFee = _serviceSubtotal;
    final travelFee = _estimatedTravelFee;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '服务时长',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _hasSelectedTime
                    ? '${_serviceHours.toStringAsFixed(0)} 小时'
                    : '请选择',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const Divider(height: 18),
          _buildPriceRow('服务费', serviceFee),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text('路费', style: TextStyle(color: Color(0xFF666666))),
              ),
              InkWell(
                onTap: _showTravelFeeRule,
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(3),
                  child: Icon(
                    Icons.help_outline,
                    size: 17,
                    color: Color(0xFF9B9B9B),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '¥${travelFee.toStringAsFixed(2)}',
                style: const TextStyle(color: Color(0xFF666666)),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildPriceRow('应付总额', serviceFee + travelFee, strong: true),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool strong = false}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              fontSize: strong ? 17 : 14,
            ),
          ),
        ),
        Text(
          '¥${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: strong ? 21 : 15,
            color: strong ? const Color(0xFFFF5A2D) : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showTravelFeeRule() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('路费如何计算'),
        content: const Text(
          '路费参考滴滴快车普通型计价规则，根据服务地点与地陪服务地点之间的路线距离、预计行驶时长、日期和时段计算。起步价包含 3 公里和 8 分钟，超出部分按分时段里程费、时长费及远途费计算。最终金额以提交订单时服务端核算结果为准。',
          style: TextStyle(height: 1.55),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderNoticeButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: _showOrderNotice,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F6F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: Color(0xFF9A9A9A),
              ),
              const SizedBox(width: 6),
              const Text(
                '订单须知',
                style: TextStyle(fontSize: 14, color: Color(0xFF7C7C7C)),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFFB6B6B6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionGap() {
    return Container(height: 12, color: const Color(0xFFF5F5F5));
  }

  Widget _buildInfoCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildInfoRow(
            title: '服务地点',
            value: _selectedAddress,
            icon: Icons.place_outlined,
            onTap: _pickLocation,
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          _buildInfoRow(
            title: '服务时间',
            value: _hasSelectedTime
                ? '${_formatDateTime(_serviceDateTime)} - ${_formatDateTime(_serviceDateTime.add(Duration(hours: _serviceHours.round())))}'
                : '请选择',
            icon: Icons.schedule_outlined,
            onTap: _pickTime,
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          _buildInfoRow(
            title: '服务人数及性别',
            value: _peopleCount > 0
                ? '${_genderSummary}（共$_peopleCount人）'
                : '请选择',
            icon: Icons.people_outline_rounded,
            onTap: _pickPeopleAndGender,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          children: [
            Icon(icon, size: 26, color: const Color(0xFF7E7E7E)),
            const SizedBox(width: 14),
            Text(
              '$title：',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: value == '请选择'
                      ? const Color(0xFFC6C6C6)
                      : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: Color(0xFFBEBEBE),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildPaymentItem(
            value: 'wechat',
            label: '微信支付',
            brandColor: const Color(0xFF22C45E),
            badgeText: '微',
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          _buildPaymentItem(
            value: 'alipay',
            label: '支付宝支付',
            brandColor: const Color(0xFF299CFF),
            badgeText: '支',
          ),
          const SizedBox(height: 8),
          _buildSafetyStrip(),
          const SizedBox(height: 18),
        ],
      ),
    );
  }

  Widget _buildPaymentItem({
    required String value,
    required String label,
    required Color brandColor,
    required String badgeText,
  }) {
    final selected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: brandColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                badgeText,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? AppColors.textPrimary
                      : const Color(0xFFD6D6D6),
                  width: 1.6,
                ),
                color: selected ? AppColors.textPrimary : Colors.white,
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: AppColors.primary,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyStrip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, size: 18, color: Color(0xFFFFA15A)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '本服务由平台全程保障您的人身财产安全',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFA15A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementRow() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _agreed,
            onChanged: (value) => setState(() => _agreed = value ?? false),
            activeColor: Colors.white,
            checkColor: AppColors.textPrimary,
            side: const BorderSide(color: Color(0xFFD0D0D0), width: 1.4),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 14),
              child: Text(
                '我已知晓并同意《支付协议》和《免责协议》',
                style: TextStyle(fontSize: 13, color: Color(0xFF9A9A9A)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitOrder,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textPrimary,
                  ),
                )
              : const Text(
                  '立即付款',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
        ),
      ),
    );
  }

  Widget _buildNoticeItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7),
            decoration: const BoxDecoration(
              color: AppColors.primaryDeep,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.month}月${dateTime.day}日 $hour:$minute';
  }
}

class _ServiceOption {
  _ServiceOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.price,
    this.count = 0,
  });

  final String id;
  final String title;
  final String subtitle;
  final double price;
  int count;
}
