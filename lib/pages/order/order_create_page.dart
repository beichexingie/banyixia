import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_theme.dart';
import '../../models/guide.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';

class OrderCreatePage extends StatefulWidget {
  final Guide guide;

  const OrderCreatePage({super.key, required this.guide});

  @override
  State<OrderCreatePage> createState() => _OrderCreatePageState();
}

class _OrderCreatePageState extends State<OrderCreatePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();

  late String _selectedAddress;
  DateTime _serviceDateTime = DateTime.now().add(
    const Duration(days: 1, hours: 2),
  );
  int _peopleCount = 1;
  String _gender = '不限';
  String _paymentMethod = 'alipay';
  bool _agreed = true;
  bool _isSubmitting = false;

  double get _manualBudget {
    final raw = _budgetController.text.trim();
    if (raw.isEmpty) return 0;
    return double.tryParse(raw) ?? 0;
  }

  double get _systemEstimate {
    double total = 299;
    if (_peopleCount > 1) {
      total += (_peopleCount - 1) * 80;
    }
    if (_serviceDateTime.weekday == DateTime.saturday ||
        _serviceDateTime.weekday == DateTime.sunday) {
      total += 60;
    }

    final keywords = '${_titleController.text} ${_noteController.text}';
    if (keywords.contains('包天') || keywords.contains('全天')) {
      total += 180;
    }
    if (keywords.contains('商务') ||
        keywords.contains('接机') ||
        keywords.contains('会展')) {
      total += 120;
    }
    return total;
  }

  double get _displayAmount => _manualBudget > 0 ? _manualBudget : _systemEstimate;

  @override
  void initState() {
    super.initState();
    _selectedAddress = widget.guide.city.isNotEmpty ? widget.guide.city : '待选择服务地点';
    _titleController.addListener(_refreshEstimate);
    _noteController.addListener(_refreshEstimate);
    _budgetController.addListener(_refreshEstimate);
  }

  @override
  void dispose() {
    _titleController
      ..removeListener(_refreshEstimate)
      ..dispose();
    _noteController
      ..removeListener(_refreshEstimate)
      ..dispose();
    _budgetController
      ..removeListener(_refreshEstimate)
      ..dispose();
    super.dispose();
  }

  void _refreshEstimate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _pickLocation() async {
    final result = await context.push<Map<String, dynamic>>(
      '/order/location',
      extra: {
        'address': _selectedAddress,
        'city': widget.guide.city,
      },
    );
    if (result != null && mounted) {
      setState(() {
        _selectedAddress =
            result['summary']?.toString() ??
            result['address']?.toString() ??
            _selectedAddress;
      });
    }
  }

  Future<void> _pickTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _serviceDateTime,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_serviceDateTime),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _serviceDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _pickPeopleAndGender() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final peopleController = TextEditingController(
          text: _peopleCount.toString(),
        );
        String tempGender = _gender;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                24 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '服务人数及偏好',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: peopleController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: '服务人数',
                      hintText: '请输入人数',
                      filled: true,
                      fillColor: const Color(0xFFF7F8FC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('地陪性别偏好'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ['不限', '男', '女'].map((gender) {
                      final selected = tempGender == gender;
                      return ChoiceChip(
                        label: Text(gender),
                        selected: selected,
                        onSelected: (_) => setModalState(() => tempGender = gender),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final parsedPeople =
                            int.tryParse(peopleController.text.trim()) ?? 1;
                        setState(() {
                          _peopleCount = parsedPeople < 1 ? 1 : parsedPeople;
                          _gender = tempGender;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D6CF5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('确定'),
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

  Future<void> _submitOrder() async {
    FocusScope.of(context).unfocus();

    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先勾选协议')),
      );
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }
    if (context.read<UserProvider>().isBanned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前账号受限，暂时不能下单')),
      );
      return;
    }
    if (widget.guide.id.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('地陪信息异常，请重新进入页面')),
      );
      return;
    }
    if (widget.guide.id == userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不能给自己下单，请选择其他地陪')),
      );
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写需求标题')),
      );
      return;
    }

    final amount = _displayAmount;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('金额异常，请检查预算或需求信息')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final detail = _noteController.text.trim();
      final serviceSummary = [
        title,
        _selectedAddress,
        '${_peopleCount}人',
        _gender,
      ].join(' / ');

      final newOrder = Order(
        id: '',
        userId: userId,
        guideId: widget.guide.id,
        guideName: widget.guide.name,
        guideAvatar: widget.guide.avatar,
        status: OrderStatus.pendingPayment,
        amount: amount,
        serviceName: detail.isEmpty ? serviceSummary : '$serviceSummary / $detail',
        paymentMethod: _paymentMethod,
        paymentStatus: 'pending',
        merchantOrderNo:
            'BX${DateTime.now().millisecondsSinceEpoch}${userId.replaceAll('-', '').substring(0, userId.length > 8 ? 8 : userId.length)}',
        serviceDate: _serviceDateTime,
        createdAt: DateTime.now(),
      );

      await context.read<OrderProvider>().createOrder(newOrder);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需求已提交，可前往订单继续支付与处理')),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF4F6FB),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '发需求',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 18,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  _buildGuideCard(),
                  const SizedBox(height: 12),
                  _buildDemandCard(),
                  const SizedBox(height: 12),
                  _buildInfoCard(),
                  const SizedBox(height: 12),
                  _buildEstimateCard(),
                  const SizedBox(height: 12),
                  _buildSafetyCard(),
                  const SizedBox(height: 12),
                  _buildPaymentCard(),
                  const SizedBox(height: 12),
                  _buildAgreementCard(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: widget.guide.avatar.isNotEmpty
                ? NetworkImage(widget.guide.avatar)
                : null,
            child: widget.guide.avatar.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.guide.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '认证地陪',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF3D6CF5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.guide.city} · ${widget.guide.tags.isNotEmpty ? widget.guide.tags.first : '本地陪同'}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.more_horiz, color: AppColors.textHint),
        ],
      ),
    );
  }

  Widget _buildDemandCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '需求内容',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleController,
            maxLength: 20,
            decoration: InputDecoration(
              labelText: '需求标题',
              hintText: '例如：陪同逛展、接机陪游、城市漫步',
              counterText: '',
              filled: true,
              fillColor: const Color(0xFFF7F8FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: '详细说明',
              hintText: '写清楚你的出行目的、陪同内容、集合方式、额外要求等',
              alignLabelWithHint: true,
              filled: true,
              fillColor: const Color(0xFFF7F8FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            '服务地点',
            _selectedAddress,
            onTap: _pickLocation,
            icon: Icons.place_outlined,
          ),
          const Divider(height: 22),
          _buildInfoRow(
            '服务时间',
            _formatDateTime(_serviceDateTime),
            onTap: _pickTime,
            icon: Icons.schedule_outlined,
          ),
          const Divider(height: 22),
          _buildInfoRow(
            '服务人数及偏好',
            '$_peopleCount人 · $_gender',
            onTap: _pickPeopleAndGender,
            icon: Icons.people_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildEstimateCard() {
    final usingManualBudget = _manualBudget > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '金额与报价',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _budgetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: '你的预算（可不填）',
              hintText: '不填写则采用系统预估报价',
              prefixText: '¥ ',
              filled: true,
              fillColor: const Color(0xFFF7F8FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      '系统预估报价',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '¥${_systemEstimate.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFFE84B2B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  usingManualBudget
                      ? '当前将按你填写的预算发起订单，后续可接入真实报价或议价接口。'
                      : '当前先使用系统预估报价占位，后续可替换为真实报价接口。',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String title,
    String value, {
    VoidCallback? onTap,
    IconData icon = Icons.place_outlined,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textHint),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFF3D6CF5)),
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
    );
  }

  Widget _buildSafetyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '平台将保留资金托管与风险保障逻辑，后续可继续扩展真实报价和售后流程。',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '支付方式',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildPaymentItem(
            'wechat',
            '微信支付',
            Icons.chat_bubble_outline,
            const Color(0xFF09B83E),
          ),
          const SizedBox(height: 10),
          _buildPaymentItem(
            'alipay',
            '支付宝支付',
            Icons.payments_outlined,
            const Color(0xFF3D6CF5),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(
    String value,
    String label,
    IconData icon,
    Color color,
  ) {
    final selected = _paymentMethod == value;
    return InkWell(
      onTap: () => setState(() => _paymentMethod = value),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: selected ? color : AppColors.textHint,
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v ?? false),
            activeColor: const Color(0xFF3D6CF5),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                '我已阅读并同意《支付协议》《服务协议》和《免责协议》',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '当前金额',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '¥${_displayAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE84B2B),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            width: 168,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submitOrder,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3D6CF5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '提交需求',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final twoDigitMonth = dateTime.month.toString().padLeft(2, '0');
    final twoDigitDay = dateTime.day.toString().padLeft(2, '0');
    final twoDigitHour = dateTime.hour.toString().padLeft(2, '0');
    final twoDigitMinute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
  }
}
