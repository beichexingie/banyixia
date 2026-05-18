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
  final TextEditingController _noteController = TextEditingController();

  late final List<_ServicePackage> _packages = [
    _ServicePackage(key: 'fun', title: '文娱活动', tag: '轻松陪玩', price: 400.0),
    _ServicePackage(key: 'business', title: '商务活动', tag: '定制服务', price: 600.0),
  ];

  String _selectedAddress = '苏州阳澄湖旅游度假村';
  DateTime _serviceDateTime = DateTime.now().add(const Duration(days: 1, hours: 2));
  int _peopleCount = 1;
  String _gender = '男';
  String _paymentMethod = 'alipay';
  bool _agreed = true;
  bool _isSubmitting = false;

  double get _totalAmount =>
      _packages.fold<double>(0, (sum, item) => sum + item.price * item.quantity);

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
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
      lastDate: DateTime.now().add(const Duration(days: 30)),
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        int tempPeople = _peopleCount;
        String tempGender = _gender;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('服务人数及性别', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('人数'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: List.generate(6, (index) {
                      final value = index + 1;
                      final selected = tempPeople == value;
                      return ChoiceChip(
                        label: Text('$value人'),
                        selected: selected,
                        onSelected: (_) => setModalState(() => tempPeople = value),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('性别'),
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
                        setState(() {
                          _peopleCount = tempPeople;
                          _gender = tempGender;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3D6CF5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  void _changePackageQuantity(_ServicePackage package, int delta) {
    setState(() {
      package.quantity = (package.quantity + delta).clamp(1, 9).toInt();
    });
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
        const SnackBar(content: Text('导游信息异常，请重新进入页面')),
      );
      return;
    }
    if (widget.guide.id == userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('不能给自己下单，请选择其他地陪')),
      );
      return;
    }

    if (_totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先选择服务')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final serviceNames = _packages
          .where((item) => item.quantity > 0)
          .map((item) => '${item.title} x${item.quantity}')
          .join('，');

      final newOrder = Order(
        id: '',
        userId: userId,
        guideId: widget.guide.id,
        guideName: widget.guide.name,
        guideAvatar: widget.guide.avatar,
        status: OrderStatus.pendingPayment,
        amount: _totalAmount,
        serviceName: '$serviceNames / $_selectedAddress',
        paymentMethod: _paymentMethod,
        paymentStatus: 'pending',
        serviceDate: _serviceDateTime,
        createdAt: DateTime.now(),
      );

      await context.read<OrderProvider>().createOrder(newOrder);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需求已提交，稍后可在订单里继续处理')),
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
        title: const Text('发需求', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 18),
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
                  _buildServiceSection(),
                  const SizedBox(height: 12),
                  _buildRequirementCard(),
                  const SizedBox(height: 12),
                  _buildInfoCard(),
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
            backgroundImage: widget.guide.avatar.isNotEmpty ? NetworkImage(widget.guide.avatar) : null,
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
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (widget.guide.verified)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3D6CF5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '已认证',
                          style: TextStyle(fontSize: 10, color: Color(0xFF3D6CF5), fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.guide.city} · ${widget.guide.tags.isNotEmpty ? widget.guide.tags.first : '本地陪游'}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.more_horiz, color: AppColors.textHint),
        ],
      ),
    );
  }

  Widget _buildServiceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('共2项可选', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ..._packages.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildPackageCard(item),
              )),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.tagBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '订单须知',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(_ServicePackage item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3D6CF5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(item.tag, style: const TextStyle(fontSize: 11, color: Color(0xFF3D6CF5))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('¥${item.price.toStringAsFixed(0)}/天', style: const TextStyle(fontSize: 13, color: Color(0xFFE84B2B), fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          _buildCountPicker(item),
        ],
      ),
    );
  }

  Widget _buildCountPicker(_ServicePackage item) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _countButton(Icons.remove, () => _changePackageQuantity(item, -1)),
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text('${item.quantity}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          _countButton(Icons.add, () => _changePackageQuantity(item, 1)),
        ],
      ),
    );
  }

  Widget _countButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Icon(icon, size: 18),
      ),
    );
  }

  Widget _buildRequirementCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('请输入需求标题（20字以内）', style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 6,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: '例如：商务活动、文娱活动、陪同出行等具体需求',
              hintStyle: TextStyle(color: AppColors.textHint),
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
            '服务人数及性别',
            '$_peopleCount人 · $_gender',
            onTap: _pickPeopleAndGender,
            icon: Icons.people_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value, {VoidCallback? onTap, IconData icon = Icons.place_outlined}) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textHint),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
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
              '本服务由平台保险全程保障您的财产与人身安全',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
          const Text('支付方式', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildPaymentItem('wechat', '微信支付', Icons.chat_bubble_outline, const Color(0xFF09B83E)),
          const SizedBox(height: 10),
          _buildPaymentItem('alipay', '支付宝支付', Icons.payments_outlined, const Color(0xFF3D6CF5)),
        ],
      ),
    );
  }

  Widget _buildPaymentItem(String value, String label, IconData icon, Color color) {
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
                '我已阅读并同意《支付协议》和《免责协议》',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
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
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('预览功能已保留，当前直接提交更快')),
                ),
                icon: const Icon(Icons.visibility_outlined, color: AppColors.textSecondary),
              ),
              const Text('预览', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('草稿已自动保存到本地状态')),
                ),
                icon: const Icon(Icons.save_outlined, color: AppColors.textSecondary),
              ),
              const Text('存草稿', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D6CF5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        '立即预约 ¥${_totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

class _ServicePackage {
  final String key;
  final String title;
  final String tag;
  final double price;
  int quantity;

  _ServicePackage({
    required this.key,
    required this.title,
    required this.tag,
    required this.price,
    this.quantity = 1,
  });
}
