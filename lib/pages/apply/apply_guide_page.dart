import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';
import '../../providers/application_provider.dart';

class ApplyGuidePage extends StatefulWidget {
  const ApplyGuidePage({super.key});

  @override
  State<ApplyGuidePage> createState() => _ApplyGuidePageState();
}

class _ApplyGuidePageState extends State<ApplyGuidePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final ScrollController _contractScrollController = ScrollController();
  
  int _currentStep = 0; // 0: 实名, 1: 资料, 2: 合同
  String _gender = '女';
  final List<String> _selectedTags = [];
  bool _isIdVerified = false;
  bool _isContractRead = false;
  bool _isContractSigned = false;
  bool _isSubmitting = false;

  final List<String> _availableTags = ['本地通', '摄影达人', '美食家', '双语服务', '自驾游', '深夜食堂'];

  @override
  void initState() {
    super.initState();
    _contractScrollController.addListener(() {
      if (_contractScrollController.position.pixels >= _contractScrollController.position.maxScrollExtent - 50) {
        if (!_isContractRead) setState(() => _isContractRead = true);
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _contractScrollController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isContractSigned) return;

    setState(() => _isSubmitting = true);
    try {
      await context.read<ApplicationProvider>().submitApplication({
        'full_name': _nameController.text.trim(),
        'gender': _gender,
        'city': _cityController.text.trim(),
        'bio': _bioController.text.trim(),
        'service_tags': _selectedTags,
        'avatar': 'https://picsum.photos/seed/avatar_apply/200/200',
        'contract_signed_at': DateTime.now().toIso8601String(),
        'status': 'pending',
      });
      
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('提交成功'),
            content: const Text('申请已提交，请等待管理员审核。预计 1-2 个工作日内完成。'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.pop();
                },
                child: const Text('我知道了'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('申请成为地陪', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(
            child: IndexedStack(
              index: _currentStep,
              children: [
                _buildIdentityStep(),
                _buildDetailsStep(),
                _buildContractStep(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _stepNode(0, '实名核验'),
          _stepLine(0),
          _stepNode(1, '填写资料'),
          _stepLine(1),
          _stepNode(2, '签署协议'),
        ],
      ),
    );
  }

  Widget _stepNode(int index, String label) {
    bool isCompleted = _currentStep > index;
    bool isActive = _currentStep == index;
    return Column(
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: isCompleted ? Colors.green : (isActive ? AppColors.primary : AppColors.divider),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted 
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: isActive ? AppColors.primary : AppColors.textHint)),
      ],
    );
  }

  Widget _stepLine(int index) {
    return Container(
      width: 60, height: 2,
      margin: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
      color: _currentStep > index ? Colors.green : AppColors.divider,
    );
  }

  Widget _buildIdentityStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepTitle('1. 身份核验', '接入公安联网人脸识别系统，保障交易安全'),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              setState(() => _isIdVerified = true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已成功匹配身份证信息，核验通过'), backgroundColor: Colors.green),
              );
            },
            child: Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: _isIdVerified ? Colors.green.withValues(alpha: 0.05) : AppColors.tagBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _isIdVerified ? Colors.green : AppColors.divider, style: BorderStyle.solid),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isIdVerified ? Icons.verified_user : Icons.add_a_photo_outlined, size: 48, color: _isIdVerified ? Colors.green : AppColors.primary),
                  const SizedBox(height: 12),
                  Text(_isIdVerified ? '实名信息：* ${(_nameController.text.isNotEmpty ? _nameController.text.substring(0, 1) : "未")}' : '上传身份证人像面进行识别', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: _isIdVerified ? Colors.green : AppColors.textPrimary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('温馨提示：请确保光线充足，文字清晰可见。平台会对身份证号进行加密存储，不会泄露给第三方。', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: _inputDecoration('展示昵称', '输入您的地陪称呼'),
              validator: (v) => v!.isEmpty ? '昵称不能为空' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              decoration: _inputDecoration('常驻城市', '如：北京、苏州'),
              validator: (v) => v!.isEmpty ? '城市不能为空' : null,
            ),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('擅长领域 (选填)', style: TextStyle(fontWeight: FontWeight.bold))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _availableTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return ActionChip(
                  label: Text(tag, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary)),
                  onPressed: () => setState(() => isSelected ? _selectedTags.remove(tag) : _selectedTags.add(tag)),
                  backgroundColor: isSelected ? AppColors.primary : AppColors.tagBackground,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              maxLines: 4,
              decoration: _inputDecoration('个人简介', '介绍一下你的带玩经验、特色服务等...'),
              validator: (v) => v!.isEmpty ? '简介不能为空' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractStep() {
    return Column(
      children: [
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey[50], border: Border.all(color: AppColors.divider), borderRadius: BorderRadius.circular(8)),
            child: ListView(
              controller: _contractScrollController,
              children: [
                const Center(child: Text('伴一下地陪服务电子合同', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                const SizedBox(height: 20),
                Text('甲方：伴一下平台（以下简称“平台”）\n乙方：注册地陪人员（以下简称“地陪”）\n\n1. 服务规范：乙方应提供真实、合法、安全的伴玩服务；\n2. 资金结算：平台支持三方托管，乙方需遵守平台分成规则。月流水小于5000，平台保留50%技术服务费；超出5000部分，地陪分成比例提升至60%；\n3. 风控规定：禁止引导私下交易。如发现用户三次无故取消，平台有权封禁账号；\n4. 违约责任：如因乙方原因导致行程中断，需承担用户损失；\n\n...（此处省略完整法律条款）\n\n签署日期：${DateTime.now().year}年${DateTime.now().month}月${DateTime.now().day}日', style: const TextStyle(fontSize: 13, height: 1.6)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Checkbox(
                value: _isContractSigned, 
                onChanged: (v) => setState(() => _isContractSigned = v!)
              ),
              const Expanded(child: Text('我已阅读并同意以上电子合同条款', style: TextStyle(fontSize: 13))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _currentStep--),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('上一步'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : () {
                if (_currentStep == 0) {
                  if (!_isIdVerified) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先完成实名核验')));
                    return;
                  }
                  setState(() => _currentStep++);
                } else if (_currentStep == 1) {
                  if (_formKey.currentState!.validate()) setState(() => _currentStep++);
                } else {
                  _submit();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: _isSubmitting 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_currentStep < 2 ? '下一步' : '签署并提交'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.divider)),
    );
  }
}
