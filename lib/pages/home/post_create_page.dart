import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/post_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/ecs_api_client.dart';

class PostCreatePage extends StatefulWidget {
  final String mode;

  const PostCreatePage({super.key, this.mode = 'share'});

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<XFile> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  String _tag = '';
  bool _isUploading = false;

  bool get _isRecruitMode => widget.mode == 'recruit';
  String get _pageTitle => _isRecruitMode ? '发布招募/自荐' : '发布动态';
  String get _defaultTag => _isRecruitMode ? '招募' : '分享';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final images = await _picker.pickMultiImage();
      if (images.isEmpty) return;
      setState(() {
        _selectedImages.addAll(images.take(9 - _selectedImages.length));
      });
    } catch (e) {
      debugPrint('pick image error: $e');
    }
  }

  Future<List<String>> _uploadImages() async {
    final uploadedUrls = <String>[];
    final api = EcsApiClient();
    final token = context.read<UserProvider>().accessToken;

    for (final file in _selectedImages) {
      try {
        final bytes = await file.readAsBytes();
        final response = await api.post(
          '/uploads/post-image',
          authToken: token,
          body: {
            'filename': file.name,
            'bytes_base64': base64Encode(bytes),
          },
        );
        final data = response['data'];
        if (data is Map<String, dynamic>) {
          uploadedUrls.add(data['url']?.toString() ?? '');
        }
      } catch (e) {
        debugPrint('upload image error: $e');
      }
    }
    return uploadedUrls;
  }

  Future<void> _submitPost() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入标题')),
      );
      return;
    }

    final user = context.read<UserProvider>().user;
    setState(() => _isUploading = true);

    try {
      final imageUrls = <String>[];
      if (user.id != '00000000-0000-0000-0000-000000000000' && _selectedImages.isNotEmpty) {
        imageUrls.addAll(await _uploadImages());
      }
      if (imageUrls.isEmpty) {
        imageUrls.add('https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/600/450');
      }

      if (!mounted) return;
      await context.read<PostProvider>().addPost(
            title: _titleController.text.trim(),
            content: _contentController.text.trim(),
            images: imageUrls,
            authorId: user.id,
            authorName: user.nickname,
            authorAvatar: user.avatar,
            tag: _tag.isNotEmpty ? _tag : _defaultTag,
          );

      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('发布失败: $e')));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Widget _buildSelectedImage(XFile file) {
    final imageWidget = kIsWeb ? Image.network(file.path, fit: BoxFit.cover) : Image.file(File(file.path), fit: BoxFit.cover);
    return Stack(
      children: [
        Container(
          width: 96,
          height: 96,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: imageWidget,
        ),
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: () => setState(() => _selectedImages.remove(file)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isUploading ? null : () => context.pop(),
        ),
        title: Text(_pageTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: ElevatedButton(
              onPressed: _isUploading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.darkSurface,
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Text('发布', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ..._selectedImages.map(_buildSelectedImage),
                      if (_selectedImages.length < 9)
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              color: AppColors.tagBackground,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, color: AppColors.primaryDark, size: 30),
                                SizedBox(height: 6),
                                Text('添加图片', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _titleController,
                    maxLength: 30,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: '请输入活动标题（20字以内）',
                      hintStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textHint),
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _contentController,
                    maxLines: null,
                    minLines: 8,
                    style: const TextStyle(fontSize: 16, height: 1.6, color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      hintText: '请输入活动内容...仅限平台沟通勿留私人联系方式',
                      hintStyle: TextStyle(fontSize: 16, color: AppColors.textHint),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ActionChip(
                        icon: Icons.location_on_outlined,
                        label: '添加位置',
                        dark: true,
                        onTap: () {},
                      ),
                      _ActionChip(
                        icon: Icons.tag,
                        label: _tag.isEmpty ? '话题' : _tag,
                        dark: false,
                        onTap: () async {
                          final value = await _showTagInput();
                          if (value != null) setState(() => _tag = value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              _BottomMiniAction(icon: Icons.visibility_outlined, label: '预览', onTap: () {}),
              const SizedBox(width: 18),
              _BottomMiniAction(icon: Icons.save_outlined, label: '存草稿', onTap: () {}),
              const Spacer(),
              ElevatedButton(
                onPressed: _isUploading ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: Text(_isUploading ? '发布中...' : '立刻发布', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _showTagInput() async {
    String value = _tag;
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('输入话题'),
          content: TextField(
            autofocus: true,
            onChanged: (v) => value = v,
            decoration: const InputDecoration(hintText: '例如：苏州旅行 / 地陪招募'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, value.trim()), child: const Text('确定')),
          ],
        );
      },
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dark;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: dark ? AppColors.darkSurface : AppColors.primary,
        foregroundColor: dark ? AppColors.primary : AppColors.textPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }
}

class _BottomMiniAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomMiniAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: AppColors.textPrimary),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
