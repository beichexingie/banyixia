import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../providers/post_provider.dart';
import '../../providers/user_provider.dart';

class PostCreatePage extends StatefulWidget {
  const PostCreatePage({super.key});

  @override
  State<PostCreatePage> createState() => _PostCreatePageState();
}

class _PostCreatePageState extends State<PostCreatePage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final List<XFile> _selectedImages = [];
  String _tag = '';
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
    }
  }

  Future<List<String>> _uploadImages() async {
    List<String> uploadedUrls = [];
    final supabase = Supabase.instance.client;
    
    for (var file in _selectedImages) {
      try {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        final filePath = 'uploads/$fileName';
        
        // Upload binary data directly to be web-compatible
        final bytes = await file.readAsBytes();
        await supabase.storage.from('post_images').uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
        );
        
        // Get public URL
        final publicUrl = supabase.storage.from('post_images').getPublicUrl(filePath);
        uploadedUrls.add(publicUrl);
      } catch (e) {
        debugPrint('Error uploading image: $e');
        // Continue uploading others if one fails, or you could throw to abort
      }
    }
    return uploadedUrls;
  }

  void _submitPost() async {
    if (_titleController.text.isEmpty) {
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

    setState(() {
      _isUploading = true;
    });

    try {
      List<String> imageUrls = [];
      
      // Real users upload images
      if (user.id != '00000000-0000-0000-0000-000000000000') {
        if (_selectedImages.isNotEmpty) {
          imageUrls = await _uploadImages();
        }
      } else {
        // Mock user just uses placeholders to bypass storage upload
        if (_selectedImages.isEmpty) {
          imageUrls.add('https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/400/300');
        } else {
           // For mock user picking real image, just use placeholder as it won't be saved to DB anyway
           imageUrls.add('https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/400/300');
        }
      }

      if (!mounted) return;

      await context.read<PostProvider>().addPost(
        title: _titleController.text,
        content: _contentController.text,
        images: imageUrls,
        authorId: user.id,
        authorName: user.nickname,
        authorAvatar: user.avatar,
        tag: _tag.isNotEmpty ? _tag : '分享',
      );
      
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('发布成功！'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发布失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
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
        title: const Text('发布新帖'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0, top: 10.0, bottom: 10.0),
            child: ElevatedButton(
              onPressed: _isUploading ? null : _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ),
              child: _isUploading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('发布', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 图片选择区
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ..._selectedImages.map((file) => Stack(
                      children: [
                          Container(
                            width: 100, height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(file.path, fit: BoxFit.cover),
                          ),
                        Positioned(
                          right: 4, top: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedImages.remove(file);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16),
                            ),
                          ),
                        )
                      ],
                    )),
                    if (_selectedImages.length < 9)
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 100, height: 100,
                          decoration: BoxDecoration(
                            color: AppColors.tagBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, color: AppColors.primary, size: 28),
                              SizedBox(height: 4),
                              Text('添加图片', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
            const SizedBox(height: 24),
            
            // 标题
            TextField(
              controller: _titleController,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: '填写标题会有更多赞哦~',
                hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textHint),
                border: InputBorder.none,
              ),
              maxLength: 30,
            ),
            
            const Divider(),
            
            // 正文
            TextField(
              controller: _contentController,
              maxLines: null,
              minLines: 8,
              style: const TextStyle(fontSize: 16, color: AppColors.textPrimary, height: 1.6),
              decoration: const InputDecoration(
                hintText: '添加正文，分享你的旅行日记...',
                hintStyle: TextStyle(fontSize: 16, color: AppColors.textHint),
                border: InputBorder.none,
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 标签
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) {
                    String tempTag = _tag;
                    return AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('输入标签', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      content: TextField(
                        autofocus: true,
                        onChanged: (val) => tempTag = val,
                        decoration: InputDecoration(
                          hintText: '例如：旅行计划',
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
                          child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _tag = tempTag);
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('确定'),
                        )
                      ],
                    );
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      _tag.isNotEmpty ? _tag : '参与话题',
                      style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500),
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
    );
  }
}

