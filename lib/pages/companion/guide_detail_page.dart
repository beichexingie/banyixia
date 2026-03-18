import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../models/guide.dart';
import '../../config/app_theme.dart';
import '../../providers/guide_provider.dart';
import '../../providers/user_provider.dart';
import 'package:provider/provider.dart';

class GuideDetailPage extends StatefulWidget {
  final Guide guide;

  const GuideDetailPage({super.key, required this.guide});

  @override
  State<GuideDetailPage> createState() => _GuideDetailPageState();
}

class _GuideDetailPageState extends State<GuideDetailPage> {
  bool _isFollowing = false;
  bool _isFollowLoading = false;


  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GuideProvider>().recordFootprint(widget.guide.id);
    });
  }

  Future<void> _checkFollowStatus() async {
    final following = await context.read<UserProvider>().isFollowing(widget.guide.id);
    if (mounted) {
      setState(() => _isFollowing = following);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isFollowLoading) return;
    setState(() => _isFollowLoading = true);
    try {
      final userProvider = context.read<UserProvider>();
      if (_isFollowing) {
        await userProvider.unfollowUser(widget.guide.id);
      } else {
        await userProvider.followUser(widget.guide.id);
      }
      await _checkFollowStatus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }


  void _showShareModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('分享这位向导', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _shareIcon(Icons.wechat, '微信好友', Colors.green),
                  _shareIcon(Icons.camera, '朋友圈', Colors.greenAccent),
                  _shareIcon(Icons.link, '复制主页链接', Colors.blue),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _shareIcon(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 380, // 调整为合适的高度
                pinned: true,
                floating: false,
                backgroundColor: Colors.white,
                elevation: 0,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                      child: const Icon(Icons.more_horiz, color: Colors.white, size: 18),
                    ),
                    onPressed: _showShareModal,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _buildTopProfileArea(),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(50),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      boxShadow: [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))
                      ],
                    ),
                    child: const TabBar(
                      labelColor: AppColors.textPrimary,
                      unselectedLabelColor: AppColors.textHint,
                      indicatorColor: AppColors.textPrimary,
                      indicatorWeight: 3,
                      indicatorSize: TabBarIndicatorSize.label,
                      tabs: [
                        Tab(text: '服务'),
                        Tab(text: '笔记'),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildServiceTab(),
              _buildNoteTab(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildTopProfileArea() {
    return Column(
      children: [
        // 顶部背景
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 200,
              color: Colors.grey[300], // 背景图占位
              alignment: Alignment.center,
              child: const Text('个人背景图', style: TextStyle(color: Colors.grey, fontSize: 18)),
            ),
            // 头像
            Positioned(
              left: 20,
              bottom: -40,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 2))],
                ),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: widget.guide.avatar, fit: BoxFit.cover,
                    placeholder: (context, url) => const ColoredBox(color: Colors.grey),
                    errorWidget: (context, url, error) => const ColoredBox(color: AppColors.tagBackground, child: Icon(Icons.person, size: 40)),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 50), // 留出头像偏移的空间
        // 个人信息
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(widget.guide.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (widget.guide.verified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFF9A3E).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: const Text('已认证', style: TextStyle(color: Color(0xFFFF9A3E), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: _toggleFollow,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _isFollowing ? AppColors.textSecondary : AppColors.primary,
                      side: BorderSide(color: _isFollowing ? AppColors.divider : AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      minimumSize: const Size(0, 32),
                    ),
                    child: _isFollowLoading 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                      : Text(_isFollowing ? '已关注' : '关注', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('ID: ${widget.guide.id.length > 8 ? widget.guide.id.substring(0,8) : widget.guide.id}', style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
              const SizedBox(height: 12),
              // Tags
              if (widget.guide.tags.isNotEmpty)
                Wrap(
                  spacing: 8, runSpacing: 6,
                  children: widget.guide.tags.map((t) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                    child: Text(t, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  )).toList(),
                ),
              const SizedBox(height: 16),
              // 地区与接单统计
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text('常驻: ${widget.guide.city}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  const Text('接单 23 · 好评率 100%', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // 八维属性图 (Mock)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(12)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _AttrStat('人品', '极好'), _AttrStat('靠谱', '极高'), _AttrStat('阅历', '丰富'), _AttrStat('品味', '较佳'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(12)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _AttrStat('颜值', '出众'), _AttrStat('身材', '匀称'), _AttrStat('才艺', '多样'), _AttrStat('体能', '充沛'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        const Text('个性介绍:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9), 
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
          ),
          child: Text(widget.guide.description, style: const TextStyle(color: AppColors.textPrimary, height: 1.6, fontSize: 14)),
        ),
        const SizedBox(height: 24),

        const Text('服务类型说明:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9), 
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
          ),
          child: const Text('提供本地导游、代驾打卡、包车解说等多项旅行服务。', style: TextStyle(color: AppColors.textPrimary, height: 1.6, fontSize: 14)),
        ),
        const SizedBox(height: 24),

        const Text('额外费用说明:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9), 
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
          ),
          child: const Text('餐饮门票需由雇主承担（协商）。', style: TextStyle(color: AppColors.textPrimary, height: 1.6, fontSize: 14)),
        ),
        const SizedBox(height: 24),

        const Text('服务范围:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF9F9F9), 
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.3)),
          ),
          child: Text(widget.guide.city, style: const TextStyle(color: AppColors.textPrimary, height: 1.6, fontSize: 14)),
        ),
        const SizedBox(height: 30),

        // 用户评价
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('用户评价(29)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('来自29位真实用户参与评分', style: TextStyle(fontSize: 12, color: AppColors.textHint)),
              ],
            ),
            Text('5.0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 32, color: Color(0xFFFF9A3E))),
          ],
        ),
        const SizedBox(height: 80), 
      ],
    );
  }

  Widget _buildNoteTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (widget.guide.images.isNotEmpty) ...[
          const Text('服务案例与照片', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: widget.guide.images.map((img) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: img, width: (MediaQuery.of(context).size.width - 60) / 3, height: (MediaQuery.of(context).size.width - 60) / 3, fit: BoxFit.cover, 
                placeholder: (context, url) => Container(width: (MediaQuery.of(context).size.width - 60) / 3, height: (MediaQuery.of(context).size.width - 60) / 3, color: AppColors.tagBackground),
                errorWidget: (context, url, err) => Container(width: (MediaQuery.of(context).size.width - 60) / 3, height: (MediaQuery.of(context).size.width - 60) / 3, color: AppColors.tagBackground),
              ),
            )).toList()
          ),
        ] else
          const Center(child: Padding(
            padding: EdgeInsets.only(top: 40.0),
            child: Text('该向导很懒，还没有发布任何笔记照片哦～', style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          )),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Consumer<GuideProvider>(
      builder: (context, provider, child) {
        final isFavorited = provider.favoriteIds.contains(widget.guide.id);
        
        return Container(
          padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: AppColors.divider.withValues(alpha: 0.5))),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => provider.toggleFavorite(widget.guide.id),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFavorited ? Icons.star : Icons.star_border, 
                      size: 26, 
                      color: isFavorited ? const Color(0xFFFF9A3E) : AppColors.textHint
                    ),
                    const SizedBox(height: 2),
                    const Text('收藏', style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                  ],
                ),
              ),
              const SizedBox(width: 30),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    context.push('/order_create', extra: widget.guide);
                  },
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF9A3E),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFFF9A3E).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('找TA下单', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AttrStat extends StatelessWidget {
  final String title;
  final String value;
  const _AttrStat(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
      ],
    );
  }
}
