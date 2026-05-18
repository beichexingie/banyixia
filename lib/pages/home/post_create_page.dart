import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_theme.dart';
import '../../providers/post_provider.dart';
import '../../providers/user_provider.dart';

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
  String get _pageTitle => _isRecruitMode ? '发布招募' : '发布新帖';
  String get _defaultTag => _isRecruitMode ? '招募' : '分享';
  String get _titleHint => _isRecruitMode
      ? '写个招募标题，例如：端午苏州 CityWalk 招募'
      : '填写标题会有更多赞哦~';
  String get _contentHint => _isRecruitMode
      ? '写清时间、地点、人数、要求和联系方式，让感兴趣的人能快速报名。'
      : '添加正文，分享你的旅行日记...';

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
      debugPrint('Error picking images: $e');
    }
  }

  Future<List<String>> _uploadImages() async {
    final uploadedUrls = <String>[];
    final supabase = Supabase.instance.client;

    for (final file in _selectedImages) {
      try {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final filePath = 'uploads/$fileName';
        final bytes = await file.readAsBytes();

        await supabase.storage.from('post_images').uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );

        uploadedUrls.add(
          supabase.storage.from('post_images').getPublicUrl(filePath),
        );
      } catch (e) {
        debugPrint('Error uploading image: $e');
      }
    }

    return uploadedUrls;
  }

  Future<void> _submitPost() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('请输入标题'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final user = context.read<UserProvider>().user;
    setState(() => _isUploading = true);

    try {
      final imageUrls = <String>[];

      if (user.id != '00000000-0000-0000-0000-000000000000') {
        if (_selectedImages.isNotEmpty) {
          imageUrls.addAll(await _uploadImages());
        }
      } else {
        imageUrls.add(
          'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/400/300',
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('发布成功！'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('发布失败: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _editTag() async {
    String tempTag = _tag;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            '输入标签',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            autofocus: true,
            onChanged: (val) => tempTag = val,
            decoration: InputDecoration(
              hintText: _isRecruitMode ? '例如：搭子招募' : '例如：旅行计划',
              filled: true,
              fillColor: AppColors.tagBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                '取消',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _tag = tempTag.trim());
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('确定'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectedImage(XFile file) {
    final imageWidget = kIsWeb
        ? Image.network(file.path, fit: BoxFit.cover)
        : Image.file(File(file.path), fit: BoxFit.cover);

    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          clipBehavior: Clip.antiAlias,
          child: imageWidget,
        ),
        Positioned(
          right: 4,
          top: 4,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedImages.remove(file);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
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
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      '发布',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isRecruitMode)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.tagBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  '招募帖先复用当前帖子系统发布，后续可以继续细分成独立频道、审核流和数据库分类。',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ..._selectedImages.map(_buildSelectedImage),
                if (_selectedImages.length < 9)
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.tagBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            color: AppColors.primary,
                            size: 28,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '添加图片',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _titleController,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: _titleHint,
                hintStyle: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHint,
                ),
                border: InputBorder.none,
              ),
              maxLength: 30,
            ),
            const Divider(),
            TextField(
              controller: _contentController,
              maxLines: null,
              minLines: 8,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: _contentHint,
                hintStyle: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textHint,
                ),
                border: InputBorder.none,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _editTag,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tagBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      _tag.isNotEmpty ? _tag : (_isRecruitMode ? '招募' : '参与话题'),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
