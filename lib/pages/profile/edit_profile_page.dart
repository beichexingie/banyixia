import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/user.dart';
import '../../providers/user_provider.dart';
import '../../services/ecs_api_client.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nicknameController;
  late final TextEditingController _bioController;
  late final TextEditingController _cityController;
  late final TextEditingController _birthdayController;
  late final TextEditingController _occupationController;
  late final TextEditingController _wechatController;
  late final TextEditingController _guideIntroductionController;
  String _gender = '';
  XFile? _avatarFile;
  String _avatarUrl = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _nicknameController = TextEditingController(text: user.nickname);
    _bioController = TextEditingController(text: user.bio);
    _cityController = TextEditingController(text: user.city);
    _birthdayController = TextEditingController(text: user.birthday);
    _occupationController = TextEditingController(text: user.occupation);
    _wechatController = TextEditingController(text: user.wechat);
    _guideIntroductionController =
        TextEditingController(text: user.guideIntroduction);
    _gender = user.gender;
    _avatarUrl = user.avatar;
  }

  @override
  void dispose() {
    for (final controller in [
      _nicknameController,
      _bioController,
      _cityController,
      _birthdayController,
      _occupationController,
      _wechatController,
      _guideIntroductionController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final provider = context.read<UserProvider>();
    final old = provider.user;
    setState(() => _saving = true);
    try {
      if (_avatarFile != null) {
        final bytes = await _avatarFile!.readAsBytes();
        final response = await EcsApiClient().post(
          '/uploads/avatar',
          authToken: provider.accessToken,
          body: {
            'filename': _avatarFile!.name,
            'bytes_base64': base64Encode(bytes),
          },
        );
        final data = response['data'];
        final uploadedUrl = data is Map<String, dynamic>
            ? data['url']?.toString() ?? ''
            : '';
        if (uploadedUrl.isEmpty) throw Exception('头像上传失败');
        _avatarUrl = uploadedUrl;
      }
      await provider.updateUser(
        old.copyWith(
          nickname: _nicknameController.text.trim(),
          avatar: _avatarUrl,
          bio: _bioController.text.trim(),
          gender: _gender,
          city: _cityController.text.trim(),
          birthday: _birthdayController.text.trim(),
          wechat: _wechatController.text.trim(),
          occupation: _occupationController.text.trim(),
          guideIntroduction: _guideIntroductionController.text.trim(),
          guideTags: old.guideTags,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('资料已保存')),
      );
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (file == null || !mounted) return;
    setState(() => _avatarFile = file);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中' : '保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _AvatarPreview(
              user: user,
              file: _avatarFile,
              onTap: _saving ? null : _pickAvatar,
            ),
            const SizedBox(height: 18),
            _field(_nicknameController, '昵称', required: true, maxLength: 20),
            _field(_cityController, '所在城市', maxLength: 20),
            _field(_occupationController, '职业', maxLength: 30),
            _field(_birthdayController, '生日', hint: '例如：1998-08-18'),
            _genderPicker(),
            _field(_bioController, '个人简介', maxLines: 4, maxLength: 160),
            _field(_wechatController, '微信号', maxLength: 40),
            if (user.isGuideApproved)
              _field(
                _guideIntroductionController,
                '地陪介绍',
                maxLines: 5,
                maxLength: 300,
              ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    String? hint,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        validator: required
            ? (value) => value == null || value.trim().isEmpty ? '请输入$label' : null
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _genderPicker() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '性别',
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        child: Wrap(
          spacing: 10,
          children: ['女', '男', '不透露'].map((value) {
            final selected = _gender == value || (_gender.isEmpty && value == '不透露');
            return ChoiceChip(
              label: Text(value),
              selected: selected,
              onSelected: (_) => setState(() => _gender = value == '不透露' ? '' : value),
              selectedColor: AppColors.primary,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  final User user;
  final XFile? file;
  final VoidCallback? onTap;

  const _AvatarPreview({required this.user, this.file, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(48),
            child: FutureBuilder<Widget>(
              future: _image(),
              builder: (context, snapshot) => CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.primarySoft,
                child: snapshot.data ??
                    const Icon(Icons.person, size: 40, color: AppColors.textHint),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('点击更换头像', style: AppTextStyles.caption),
        ],
      ),
    );
  }

  Future<Widget> _image() async {
    if (file != null) {
      return Image.memory(await file!.readAsBytes(), width: 84, height: 84, fit: BoxFit.cover);
    }
    if (user.avatar.isNotEmpty) {
      return Image.network(user.avatar, width: 84, height: 84, fit: BoxFit.cover);
    }
    return const Icon(Icons.person, size: 40, color: AppColors.textHint);
  }
}
