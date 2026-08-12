import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/order.dart';
import '../../providers/order_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/ecs_api_client.dart';

class OrderReviewPage extends StatefulWidget {
  final String orderId;

  const OrderReviewPage({super.key, required this.orderId});

  @override
  State<OrderReviewPage> createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<OrderReviewPage> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = <XFile>[];
  int _rating = 5;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrders();
    });
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 82,
    );
    if (!mounted || picked.isEmpty) return;
    setState(() => _images.addAll(picked.take(9 - _images.length)));
  }

  Future<List<String>> _uploadImages() async {
    final api = EcsApiClient();
    final token = context.read<UserProvider>().accessToken;
    final urls = <String>[];
    for (final file in _images) {
      final response = await api.uploadFile(
        '/uploads/review-image',
        filename: file.name,
        bytes: await file.readAsBytes(),
        mimeType: file.mimeType ?? 'image/jpeg',
        authToken: token,
      );
      final data = response['data'];
      if (data is Map<String, dynamic> && data['url'] != null) {
        urls.add(data['url'].toString());
      }
    }
    return urls;
  }

  Future<void> _submit(Order order) async {
    final content = _contentController.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写评价内容')));
      return;
    }
    setState(() => _submitting = true);
    try {
      final imageUrls = await _uploadImages();
      if (!mounted) return;
      await context.read<OrderProvider>().reviewOrder(
        order.id,
        rating: _rating,
        content: content,
        images: imageUrls,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('评价已提交，订单已完成')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('评价提交失败：$error')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '评价本次服务',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Consumer<OrderProvider>(
        builder: (context, provider, _) {
          Order? order;
          for (final item in provider.orders) {
            if (item.id == widget.orderId) {
              order = item;
              break;
            }
          }
          if (order == null) {
            return const Center(child: Text('订单正在加载，请稍候'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _card(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: order.guideAvatar.isNotEmpty
                          ? NetworkImage(order.guideAvatar)
                          : null,
                      child: order.guideAvatar.isEmpty
                          ? const Icon(Icons.person_outline)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        order.guideName.isEmpty ? '本次服务地陪' : order.guideName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '服务评分',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (index) => IconButton(
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _rating = index + 1),
                          iconSize: 38,
                          color: const Color(0xFFE28B24),
                          icon: Icon(
                            index < _rating ? Icons.star : Icons.star_border,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _contentController,
                      minLines: 7,
                      maxLines: 12,
                      maxLength: 300,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: '说说这次服务的感受',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _submitting || _images.length >= 9
                          ? null
                          : _pickImages,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text('添加图片（${_images.length}/9）'),
                    ),
                    if (_images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 76,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final image = _images[index];
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: FutureBuilder<Uint8List>(
                                    future: image.readAsBytes(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return const SizedBox(
                                          width: 76,
                                          height: 76,
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      }
                                      return Image.memory(
                                        snapshot.data!,
                                        width: 76,
                                        height: 76,
                                        fit: BoxFit.cover,
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => _images.removeAt(index)),
                                    child: const Icon(Icons.cancel, size: 20),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      '评价默认匿名展示给地陪及其他用户。',
                      style: TextStyle(fontSize: 13, color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _submitting ? null : () => _submit(order!),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          '提交评价',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: child,
    );
  }
}
