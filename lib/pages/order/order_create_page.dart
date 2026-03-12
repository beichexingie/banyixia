import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/guide.dart';
import '../../config/app_theme.dart';

class OrderCreatePage extends StatefulWidget {
  final Guide guide;

  const OrderCreatePage({super.key, required this.guide});

  @override
  State<OrderCreatePage> createState() => _OrderCreatePageState();
}

class _OrderCreatePageState extends State<OrderCreatePage> {
  final List<String> _itineraryOptions = [
    '北京市区游览', '故宫沉浸游', '长城徒步游', '颐和园皇家游', '八达岭/慕田峪长城', '定制行程'
  ];
  final Set<String> _selectedItineraries = {'北京市区游览'};

  String _selectedAddress = '北京首都国际机场 T3航站楼';
  String _selectedTime = '11.02周二 09:30 - 13:30 (4时)';
  int _selectedPeopleCount = 2;

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  String _paymentMethod = 'wechat'; // wechat or alipay or pending

  void _selectAddress() {
    // 模拟地址选择
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('选择常用地址', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListTile(
                title: const Text('北京首都国际机场 T3航站楼'),
                onTap: () {
                  setState(() => _selectedAddress = '北京首都国际机场 T3航站楼');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('大兴国际机场'),
                onTap: () {
                  setState(() => _selectedAddress = '大兴国际机场');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('北京南站'),
                onTap: () {
                  setState(() => _selectedAddress = '北京南站');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectTime() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = "${picked.month}.${picked.day}  09:30 - 13:30";
      });
    }
  }

  void _selectPeople() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SizedBox(
          height: 250,
          child: ListView.builder(
            itemCount: 10,
            itemBuilder: (context, index) {
              final count = index + 1;
              return ListTile(
                title: Text('$count人'),
                onTap: () {
                  setState(() => _selectedPeopleCount = count);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _submitOrder() {
    // 隐藏键盘
    FocusScope.of(context).unfocus();
    // 模拟提交成功
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('订单提交成功，即将前往支付')),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) context.pop(); // 返回上一页
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light grey background
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('确认订单', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAddressSection(),
            const SizedBox(height: 12),
            _buildTimeAndPeopleSection(),
            const SizedBox(height: 12),
            _buildItinerarySection(),
            const SizedBox(height: 12),
            _buildNotesSection(),
            const SizedBox(height: 12),
            _buildCostSection(),
            const SizedBox(height: 12),
            _buildPaymentSection(),
            const SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSectionContainer({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _buildAddressSection() {
    return GestureDetector(
      onTap: _selectAddress,
      child: _buildSectionContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFFF9A3E), borderRadius: BorderRadius.circular(4)),
                  child: const Text('出发', style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('北京市朝阳区', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textHint),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4, bottom: 8),
              child: Text(_selectedAddress, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ),
            const Padding(
              padding: EdgeInsets.only(left: 32),
              child: Text('郑女士  138****8888', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeAndPeopleSection() {
    return _buildSectionContainer(
      child: Column(
        children: [
          GestureDetector(
            onTap: _selectTime,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('选择预约时间段', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                // 修复溢出：将右侧内容包裹在 Flexible 中
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          _selectedTime, 
                          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppColors.textHint),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppColors.divider)),
          GestureDetector(
            onTap: _selectPeople,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('选择同行人数', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                Row(
                  children: [
                    Text('$_selectedPeopleCount人', style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    const Icon(Icons.chevron_right, color: AppColors.textHint),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItinerarySection() {
    return _buildSectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择行程(可多选)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: _itineraryOptions.map((option) {
              final isSelected = _selectedItineraries.contains(option);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedItineraries.remove(option);
                    } else {
                      _selectedItineraries.add(option);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFF9A3E).withValues(alpha: 0.1) : Colors.grey[100],
                    border: Border.all(color: isSelected ? const Color(0xFFFF9A3E) : Colors.transparent),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected ? const Color(0xFFFF9A3E) : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesSection() {
    return _buildSectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('行程备注', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
            child: TextField(
              controller: _noteController,
              maxLines: 3,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                hintText: '请在此输入您的具体需求或行程安排，例如我想去王府井...',
                hintStyle: TextStyle(fontSize: 14, color: AppColors.textHint),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(12),
              ),
            ),
          ),
          if (_selectedItineraries.contains('定制行程')) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('定制出价', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(width: 16),
                const Text('¥', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      hintText: '输入预期价格',
                      border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.divider)),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostSection() {
    return _buildSectionContainer(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('车费(不含门票费、餐饮费)', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              Text('¥ 200', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppColors.divider)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('优惠券', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              Row(
                children: [
                  Text('暂无可用', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
                  Icon(Icons.chevron_right, color: AppColors.textHint),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return _buildSectionContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('支付方式', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _paymentMethod = 'wechat'),
            child: Row(
              children: [
                const Icon(Icons.wechat, color: Color(0xFF09B83E), size: 24),
                const SizedBox(width: 12),
                const Expanded(child: Text('微信支付', style: TextStyle(fontSize: 14, color: AppColors.textPrimary))),
                Icon(
                  _paymentMethod == 'wechat' ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _paymentMethod == 'wechat' ? const Color(0xFF09B83E) : AppColors.textHint,
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _paymentMethod = 'alipay'),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.blue, size: 24), // Mock alipay icon
                const SizedBox(width: 12),
                const Expanded(child: Text('支付宝', style: TextStyle(fontSize: 14, color: AppColors.textPrimary))),
                Icon(
                  _paymentMethod == 'alipay' ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: _paymentMethod == 'alipay' ? Colors.blue : AppColors.textHint,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('合计: ', style: TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              Text('¥200', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFFF9A3E))),
            ],
          ),
          ElevatedButton(
            onPressed: _submitOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF9A3E),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
            child: const Text('提交订单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
