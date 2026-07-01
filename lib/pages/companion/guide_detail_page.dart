import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/guide.dart';
import '../../providers/guide_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/user_provider.dart';

class GuideDetailPage extends StatefulWidget {
  final Guide? guide;
  final String? guideId;

  const GuideDetailPage({super.key, this.guide, this.guideId});

  @override
  State<GuideDetailPage> createState() => _GuideDetailPageState();
}

class _GuideDetailPageState extends State<GuideDetailPage> {
  Guide? _guide;
  bool _isLoading = false;
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.guide != null) {
      _guide = widget.guide;
      _initData();
    } else if (widget.guideId != null) {
      _fetchGuide();
    }
  }

  void _initData() {
    _checkFollowStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_guide != null) {
        context.read<GuideProvider>().recordFootprint(_guide!.id);
      }
    });
  }

  Future<void> _fetchGuide() async {
    setState(() => _isLoading = true);
    try {
      final data = await context.read<GuideProvider>().getGuideById(widget.guideId!);
      if (!mounted) return;
      if (data == null) throw Exception('未找到该地陪信息');
      setState(() {
        _guide = data;
        _isLoading = false;
      });
      _initData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      context.pop();
    }
  }

  Future<void> _checkFollowStatus() async {
    if (_guide == null) return;
    final following = await context.read<UserProvider>().isFollowing(_guide!.id);
    if (mounted) {
      setState(() => _isFollowing = following);
    }
  }

  Future<void> _toggleFollow() async {
    if (_guide == null || _isFollowLoading) return;
    setState(() => _isFollowLoading = true);
    try {
      final userProvider = context.read<UserProvider>();
      if (_isFollowing) {
        await userProvider.unfollowUser(_guide!.id);
      } else {
        await userProvider.followUser(_guide!.id);
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

  Future<void> _contactGuide() async {
    if (_guide == null) return;
    try {
      final roomId = await context.read<MessageProvider>().getOrCreateRoom(_guide!.id);
      if (!mounted) return;
      context.push('/chat/$roomId?name=${Uri.encodeComponent(_guide!.name)}&avatar=${Uri.encodeComponent(_guide!.avatar)}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _guide == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final guide = _guide!;
    final isSelfGuide = context.read<UserProvider>().user.id == guide.id;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: true,
                expandedHeight: 420,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: _CircleIconButton(
                  icon: Icons.arrow_back_ios_new,
                  onTap: () => context.pop(),
                ),
                actions: [
                  _CircleIconButton(
                    icon: Icons.more_horiz,
                    onTap: _showShareModal,
                  ),
                  const SizedBox(width: 8),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHero(guide, isSelfGuide),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(56),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: const TabBar(
                      labelColor: AppColors.textPrimary,
                      unselectedLabelColor: AppColors.textHint,
                      indicatorColor: AppColors.primaryDark,
                      indicatorWeight: 3,
                      tabs: [
                        Tab(text: '服务'),
                        Tab(text: '动态'),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildServiceTab(guide),
              _buildNoteTab(guide),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomBar(guide),
    );
  }

  Widget _buildHero(Guide guide, bool isSelfGuide) {
    final bg = guide.images.isNotEmpty ? guide.images.first : guide.avatar;
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: bg,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) => Container(color: AppColors.tagBackground),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.08),
                Colors.black.withValues(alpha: 0.45),
              ],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _Avatar(url: guide.avatar),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                guide.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                guide.rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '编号：${guide.id.length > 8 ? guide.id.substring(0, 8) : guide.id}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isSelfGuide)
                    ElevatedButton.icon(
                      onPressed: _isFollowLoading ? null : _toggleFollow,
                      icon: Icon(_isFollowing ? Icons.check : Icons.add),
                      label: Text(_isFollowing ? '已关注' : '关注'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.textPrimary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _StatBox(value: '${guide.likes}', label: '粉丝'),
                  _StatBox(value: '${guide.fans}', label: '收藏'),
                  _StatBox(value: '${guide.views}', label: '接单'),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Pill(text: 'IP：${guide.city.isEmpty ? '苏州' : guide.city}'),
                  _Pill(text: guide.gender.isEmpty ? '女·26' : guide.gender),
                  const _Pill(text: '已实名'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServiceTab(Guide guide) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            childAspectRatio: 1.1,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: const [
              _InfoTile(value: '123', label: '入驻'),
              _InfoTile(value: '99.8%', label: '好评率'),
              _InfoTile(value: '80%', label: '回购率'),
              _InfoTile(value: '汉', label: '民族'),
              _InfoTile(value: '水瓶座', label: '星座'),
              _InfoTile(value: '本科', label: '学历'),
              _InfoTile(value: '183', label: '身高'),
              _InfoTile(value: '80kg', label: '体重'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '个人介绍',
          child: Text(
            guide.description.isNotEmpty ? guide.description : '这里是个人介绍，展示服务风格与经历。'
            ,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '服务类型说明',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: guide.tags.isEmpty
                ? const [
                    _Tag(text: '休闲游玩'),
                    _Tag(text: '商务陪同'),
                  ]
                : guide.tags.map((t) => _Tag(text: t)).toList(),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '额外费用说明',
          child: Text(
            '餐饮、门票、交通等费用按实际情况协商，服务前确认清楚更安心。',
            style: const TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(height: 14),
        _SectionCard(
          title: '用户评价（10）',
          trailing: const Text('查看更多 >', style: TextStyle(color: AppColors.textHint)),
          child: const Column(
            children: [
              _ReviewItem(),
              SizedBox(height: 18),
              _ReviewItem(withImages: true),
              SizedBox(height: 18),
              _ReviewItem(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoteTab(Guide guide) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        if (guide.images.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(
              child: Text('暂时还没有动态内容', style: TextStyle(color: AppColors.textHint)),
            ),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: guide.images
                .map(
                  (img) => ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: img,
                      width: (MediaQuery.of(context).size.width - 60) / 3,
                      height: (MediaQuery.of(context).size.width - 60) / 3,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        width: (MediaQuery.of(context).size.width - 60) / 3,
                        height: (MediaQuery.of(context).size.width - 60) / 3,
                        color: AppColors.tagBackground,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildBottomBar(Guide guide) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEDEDED))),
      ),
      child: Row(
        children: [
          _BottomAction(
            icon: Icons.chat_bubble_outline,
            label: '咨询',
            onTap: _contactGuide,
          ),
          const SizedBox(width: 20),
          Consumer<GuideProvider>(
            builder: (context, provider, child) {
              final isFavorited = provider.favoriteIds.contains(guide.id);
              return _BottomAction(
                icon: isFavorited ? Icons.star : Icons.star_border,
                label: isFavorited ? '收藏' : '收藏',
                active: isFavorited,
                onTap: () => provider.toggleFavorite(guide.id),
              );
            },
          ),
          const SizedBox(width: 18),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                context.push('/order/create?guideId=${guide.id}&name=${Uri.encodeComponent(guide.name)}&avatar=${Uri.encodeComponent(guide.avatar)}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('找TA下单', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  void _showShareModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: const Text('分享功能暂留，后续可继续接入。', style: TextStyle(fontSize: 14)),
        );
      },
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;

  const _Avatar({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        errorWidget: (context, url, error) => Container(
          width: 72,
          height: 72,
          color: AppColors.tagBackground,
          child: const Icon(Icons.person, color: AppColors.textHint),
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;

  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.26),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String value;
  final String label;

  const _InfoTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final bool withImages;

  const _ReviewItem({this.withImages = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const CircleAvatar(radius: 16, backgroundColor: AppColors.tagBackground, child: Icon(Icons.person, size: 18)),
            const SizedBox(width: 10),
            const Text('用户1028er', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '这是评论内容，这是评论内容。这里展示真实用户体验与反馈。',
          style: TextStyle(fontSize: 14, height: 1.6, color: AppColors.textPrimary),
        ),
        if (withImages) ...[
          const SizedBox(height: 10),
          Row(
            children: List.generate(
              3,
              (index) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.tagBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: active ? AppColors.primaryDark : AppColors.textHint),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: active ? AppColors.primaryDark : AppColors.textHint,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
