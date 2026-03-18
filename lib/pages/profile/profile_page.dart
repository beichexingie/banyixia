import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../models/order.dart';
import '../../models/user.dart' as app_model;
import '../../providers/user_provider.dart';
import '../../providers/order_provider.dart';
import 'package:go_router/go_router.dart';
import '../main_scaffold.dart';
import 'favorite_posts_page.dart';
import 'footprint_posts_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildFunctionGrid(context),
            _buildOrderSection(context),
            _buildEmptyOrderTip(context),
            _buildBottomActions(context),
            _buildEmptyContent(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ==================== 设置面板 ====================
  // Bottom sheet logic moved to SettingsPage

  // ==================== 编辑资料 ====================
  void _showEditProfile(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const _EditProfileDialog(),
    );
  }



  // ==================== 评头衔与福利 ====================
  void _showTitleModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('玩家头衔 (Demo)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.military_tech, color: Color(0xFFCD7F32), size: 36),
                title: const Text('青铜搭子'),
                subtitle: const Text('完成 1 次出行可得'),
              ),
              ListTile(
                leading: const Icon(Icons.military_tech, color: Color(0xFFC0C0C0), size: 36),
                title: const Text('白银搭子'),
                subtitle: const Text('完成 5 次出行可得'),
              ),
              ListTile(
                leading: const Icon(Icons.military_tech, color: Color(0xFFFFD700), size: 36),
                title: const Text('黄金搭子'),
                subtitle: const Text('完成 20 次出行可得'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('了解详情'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showBenefitsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('进阶福利 (Demo)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.stars, color: AppColors.primary, size: 36),
                title: const Text('免费帖子置顶 1 次'),
                subtitle: const Text('等级达到 LV.3 可解锁'),
              ),
              ListTile(
                leading: const Icon(Icons.color_lens, color: Colors.purple, size: 36),
                title: const Text('专属彩色昵称'),
                subtitle: const Text('等级达到 LV.5 可解锁'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('去升级'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== 关于对话框 ====================
  // _showAboutDialog removed, moved to SettingsPage

  // ==================== 收藏/足迹/投诉 ====================
  void _showListPage(BuildContext context, String title, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(title),
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 64, color: AppColors.textHint.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('暂无$title内容', style: AppTextStyles.subtitle),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    MainScaffold.switchTo(0);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  child: const Text('去首页逛逛'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ==================== 构建界面 ====================
  Widget _buildHeader(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.user;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF9A3E), Color(0xFFFFC078)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                   Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: () => context.push('/admin/audit'),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.admin_panel_settings_outlined, size: 20, color: Colors.white),
                              SizedBox(width: 4),
                              Text('管理', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => context.push('/settings'),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.settings_outlined, size: 20, color: Colors.white),
                              SizedBox(width: 4),
                              Text('设置', style: TextStyle(color: Colors.white, fontSize: 13)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => _showEditProfile(context),
                    child: Row(
                      children: [
                        Container(
                          width: 68, height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          child: CircleAvatar(
                            radius: 31, 
                            backgroundColor: const Color(0xFFE0E0E0),
                            backgroundImage: user.avatar.isNotEmpty ? NetworkImage(user.avatar) : null,
                            child: user.avatar.isEmpty ? const Icon(Icons.person, size: 36, color: Colors.white) : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      user.nickname, 
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (user.vipLabel.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                                      ),
                                      child: Text(user.vipLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'ID: ${user.id}', 
                                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (user.title.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '解锁【${user.title}】身份', 
                                  style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.75)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white70, size: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFunctionGrid(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final user = userProvider.user;
        final items = [
          {'icon': Icons.emoji_events_outlined, 'title': '玩家头衔', 'subtitle': '评个搭子称号', 'action': () => _showTitleModal(context)},
          {'icon': Icons.card_giftcard_outlined, 'title': '进阶福利', 'subtitle': '得个搭子称号', 'action': () => _showBenefitsModal(context)},
          {'icon': Icons.local_offer_outlined, 'title': '优惠券', 'subtitle': '${user.couponCount}张可用', 'action': () => context.push('/profile/coupons')},
          {'icon': Icons.account_balance_wallet_outlined, 'title': '账户余额', 'subtitle': '¥${user.balance.toStringAsFixed(1)}', 'action': () => context.push('/profile/balance')},
        ];

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
          transform: Matrix4.translationValues(0, -16, 0),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14),
            boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: items.map((item) {
              return Expanded(
                child: GestureDetector(
                  onTap: item['action'] as VoidCallback,
                  child: Column(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)),
                        child: Icon(item['icon'] as IconData, color: Colors.white, size: 22),
                      ),
                      const SizedBox(height: 8),
                      Text(item['title'] as String, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(item['subtitle'] as String, style: const TextStyle(fontSize: 10, color: AppColors.textHint), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildOrderSection(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
          child: Column(
            children: [
              Row(
                children: [
                  const Text('我的订单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/profile/orders'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('更多', style: AppTextStyles.caption),
                        const Icon(Icons.chevron_right, size: 16, color: AppColors.textHint),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildOrderItem(context, Icons.payment, '待付款', orderProvider.getCountByStatus(OrderStatus.pendingPayment), '待付款订单'),
                  _buildOrderItem(context, Icons.access_time, '进行中', orderProvider.getCountByStatus(OrderStatus.inProgress), '进行中订单'),
                  _buildOrderItem(context, Icons.rate_review_outlined, '待评价', orderProvider.getCountByStatus(OrderStatus.pendingReview), '待评价订单'),
                  _buildOrderItem(context, Icons.cancel_outlined, '已取消', orderProvider.getCountByStatus(OrderStatus.cancelled), '已取消订单'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderItem(BuildContext context, IconData icon, String label, int count, String msg) {
    return GestureDetector(
      onTap: () => _showSnack(context, '暂无$msg'),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(color: AppColors.tagBackground, borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: AppColors.primary, size: 24),
              ),
              if (count > 0)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text('$count', textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmptyOrderTip(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, orderProvider, child) {
        if (orderProvider.orders.isNotEmpty) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => MainScaffold.switchTo(0),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F0), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long, size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('你暂无服务中订单哦~', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      SizedBox(height: 2),
                      Text('快去首页下单吧', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16)),
                  child: const Text('去下单 >', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoritePostsPage()),
              );
            },
            child: _buildActionItem(Icons.favorite_outline, '收藏'),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FootprintPostsPage()),
              );
            },
            child: _buildActionItem(Icons.directions_walk, '足迹'),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _showListPage(context, '投诉', Icons.report_outlined),
            child: _buildActionItem(Icons.report_outlined, '投诉'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 24, color: AppColors.textSecondary),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildEmptyContent() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(Icons.description_outlined, size: 48, color: AppColors.textHint.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          const Text('暂无数据', style: TextStyle(fontSize: 14, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog();

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late TextEditingController _nicknameController;
  late UserProvider _userProvider;
  Uint8List? _avatarBytes;
  String? _avatarMimeType;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _userProvider = context.read<UserProvider>();
    _nicknameController = TextEditingController(text: _userProvider.user.nickname);
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _avatarBytes = bytes;
          _avatarMimeType = image.mimeType ?? 'image/jpeg';
        });
      }
    } catch (e) {
      debugPrint('Error picking avatar: $e');
    }
  }

  Future<void> _saveProfile() async {
    final newName = _nicknameController.text.trim();
    if (newName.isEmpty) return;

    final user = _userProvider.user;
    String finalAvatarUrl = user.avatar;

    setState(() {
      _isUploading = true;
    });

    try {
      // Mock user bypasses real upload
      if (user.id != '00000000-0000-0000-0000-000000000000' && _avatarBytes != null) {
        final supabase = Supabase.instance.client;
        final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final filePath = 'uploads/$fileName';

        await supabase.storage.from('avatars').uploadBinary(
          filePath,
          _avatarBytes!,
          fileOptions: FileOptions(cacheControl: '3600', upsert: true, contentType: _avatarMimeType ?? 'image/jpeg'),
        );

        finalAvatarUrl = supabase.storage.from('avatars').getPublicUrl(filePath);
      } else if (_avatarBytes != null) {
        // Mock user local preview URL (won't persist across restarts but updates UI)
         finalAvatarUrl = 'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/100/100';
      }

      await _userProvider.updateUser(
        app_model.User(
          id: user.id,
          nickname: newName,
          avatar: finalAvatarUrl,
          vipLevel: user.vipLevel,
          title: user.title,
          balance: user.balance,
          couponCount: user.couponCount,
          followCount: user.followCount,
          fansCount: user.fansCount,
        ),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('资料已更新'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        // Extract inner exception message if available
        String errorMsg = '保存失败';
        if (e is Exception) {
          errorMsg = e.toString().replaceAll('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
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
    final user = _userProvider.user;
    
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('编辑资料'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 头像
          GestureDetector(
            onTap: _isUploading ? null : _pickAndUploadAvatar,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFFE0E0E0),
                  backgroundImage: _avatarBytes != null 
                      ? MemoryImage(_avatarBytes!) as ImageProvider
                      : NetworkImage(user.avatar),
                  child: _avatarBytes == null && user.avatar.isEmpty
                      ? const Icon(Icons.person, size: 40, color: Colors.white)
                      : null,
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
                if (_isUploading)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nicknameController,
            enabled: !_isUploading,
            decoration: InputDecoration(
              labelText: '昵称',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('取消', style: TextStyle(color: AppColors.textHint)),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _saveProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isUploading 
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('保存'),
        ),
      ],
    );
  }
}
