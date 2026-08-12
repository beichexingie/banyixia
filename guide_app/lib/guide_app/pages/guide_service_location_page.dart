import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import 'package:flutter_application_1/config/amap_config.dart';
import 'package:flutter_application_1/services/map_service.dart';
import '../models/guide_app_models.dart';
import '../providers/guide_console_provider.dart';
import '../providers/guide_backend_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideServiceLocationPage extends StatefulWidget {
  const GuideServiceLocationPage({super.key});

  @override
  State<GuideServiceLocationPage> createState() =>
      _GuideServiceLocationPageState();
}

class _GuideServiceLocationPageState extends State<GuideServiceLocationPage> {
  bool _expanded = false;
  bool _locating = false;

  Future<void> _refreshLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await const AmapMapService(
        apiKey: AmapConfig.webServiceKey,
      ).currentPosition();
      if (position == null ||
          position.latitude == null ||
          position.longitude == null) {
        throw Exception('暂时无法获取定位，请检查定位权限和地图配置');
      }
      final console = context.read<GuideConsoleProvider>();
      final address = GuideAddress(
        city: position.city,
        title: position.formattedAddress,
        detail: '当前定位服务地点',
        contactName: '本人',
        maskedPhone: '当前账号',
      );
      console.updateCurrentLocation(address);
      await context.read<GuideBackendProvider>().saveGuideLocation(
        latitude: position.latitude!,
        longitude: position.longitude!,
        locationText: position.formattedAddress,
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('服务地点已保存')));
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('定位失败：$error')));
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _addAddress() async {
    final titleController = TextEditingController();
    final detailController = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('新增服务地址'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: '地点名称'),
            ),
            TextField(
              controller: detailController,
              decoration: const InputDecoration(labelText: '详细地址'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'title': titleController.text.trim(),
              'detail': detailController.text.trim(),
            }),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    titleController.dispose();
    detailController.dispose();
    if (!mounted || result == null || result['title']!.isEmpty) return;
    context.read<GuideConsoleProvider>().addServiceAddress(
      GuideAddress(
        city: context.read<GuideConsoleProvider>().selectedCity,
        title: result['title']!,
        detail: result['detail']!.isEmpty ? '待补充详细地址' : result['detail']!,
        contactName: '本人',
        maskedPhone: '当前账号',
      ),
    );
    setState(() => _expanded = true);
  }

  Future<void> _manageAddresses() async {
    final console = context.read<GuideConsoleProvider>();
    if (console.serviceAddresses.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          children: console.serviceAddresses.map((address) {
            return ListTile(
              title: Text('${address.city}${address.title}'),
              subtitle: Text(address.detail),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  console.removeServiceAddress(address);
                  Navigator.pop(context);
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final console = context.watch<GuideConsoleProvider>();
    final visibleAddresses = _expanded
        ? console.serviceAddresses
        : console.serviceAddresses.take(2).toList();

    return GuideAppScaffold(
      safeAreaTop: false,
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1524661135-423995f22d0b?auto=format&fit=crop&w=1200&q=80',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: const Color(0xFFE8EBF0)),
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.62)),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          ),
                          const Expanded(
                            child: Text(
                              '服务地点',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 48),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        height: 58,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.primaryDark,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  console.selectedCity,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              width: 1,
                              height: 26,
                              color: const Color(0xFFE3E5E8),
                            ),
                            const Icon(
                              Icons.search_rounded,
                              size: 28,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                '搜索内容',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: AppColors.textHint,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SingleChildScrollView(
                      child: GuideSectionCard(
                        margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                        padding: const EdgeInsets.fromLTRB(18, 20, 18, 26),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '请确认地点',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${console.currentLocation.city}${console.currentLocation.title}',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        '（自动定位所在城市的具体位置，【重新定位】后改为详细地点）',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFFFF8C3B),
                                          height: 1.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _refreshLocation,
                                  icon: const Icon(
                                    Icons.gps_fixed,
                                    color: AppColors.textPrimary,
                                  ),
                                  label: Text(
                                    _locating ? '定位中' : '重新定位',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Divider(height: 1),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    '我的服务地址',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ),
                                _SmallActionButton(
                                  label: '新增',
                                  icon: Icons.add,
                                  onTap: () {
                                    _addAddress();
                                  },
                                ),
                                const SizedBox(width: 10),
                                _SmallActionButton(
                                  label: '管理',
                                  icon: Icons.edit_outlined,
                                  onTap: _manageAddresses,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...visibleAddresses.map(
                              (address) => _AddressTile(address: address),
                            ),
                            if (console.serviceAddresses.length > 2) ...[
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: () =>
                                    setState(() => _expanded = !_expanded),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _expanded ? '收起地址' : '展开更多',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        _expanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        color: AppColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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

class _SmallActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SmallActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE2E5E9)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressTile extends StatelessWidget {
  final GuideAddress address;

  const _AddressTile({required this.address});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${address.city}${address.title}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            '${address.contactName} ${address.maskedPhone}',
            style: const TextStyle(fontSize: 16, color: AppColors.textHint),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
