import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
  final List<String> _images = [];
  String _tag = '';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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
    
    // 模拟图片
    if (_images.isEmpty) {
      _images.add('https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/400/300');
    }

    final user = context.read<UserProvider>().user;

    try {
      await context.read<PostProvider>().addPost(
        title: _titleController.text,
        content: _contentController.text,
        images: _images,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: const Text('发布新帖'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0, top: 10.0, bottom: 10.0),
            child: ElevatedButton(
              onPressed: _submitPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                elevation: 0,
              ),
              child: const Text('发布', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片选择区
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ..._images.map((img) => Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(image: NetworkImage(img), fit: BoxFit.cover),
                  ),
                )),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _images.add('https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/400/300');
                    });
                  },
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
    );
  }
}
