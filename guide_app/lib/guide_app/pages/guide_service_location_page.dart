import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_1/pages/order/location_picker_page.dart';
import '../models/guide_app_models.dart';
import '../providers/guide_backend_provider.dart';
import '../providers/guide_console_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideServiceLocationPage extends StatefulWidget {
  const GuideServiceLocationPage({super.key});

  @override
  State<GuideServiceLocationPage> createState() =>
      _GuideServiceLocationPageState();
}

class _GuideServiceLocationPageState extends State<GuideServiceLocationPage> {
  bool _busy = false;
  bool _loaded = false;

  GuideBackendProvider get _backend => context.read<GuideBackendProvider>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await _backend.load();
        if (mounted) _syncConsole();
      } catch (_) {
        // The page can still show the last provider state when offline.
      }
    });
  }

  Future<void> _pickLocation({GuideAddress? existing}) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          title: existing == null ? '新增服务地址' : '编辑服务地址',
          initialAddress: existing?.detail,
          initialCity: existing?.city,
        ),
      ),
    );
    if (!mounted || result == null) return;
    final latitude = _number(result['latitude']);
    final longitude = _number(result['longitude']);
    final address = (result['summary'] ?? result['address'] ?? '')
        .toString()
        .trim();
    if (latitude == null || longitude == null || address.isEmpty) {
      _showMessage('请在地图上选择一个有效服务地址');
      return;
    }
    final label = await _askLabel(existing?.title ?? '');
    if (!mounted || label == null) return;
    setState(() => _busy = true);
    try {
      if (existing == null) {
        await _backend.createServiceAddress(
          label: label,
          city: (result['city'] ?? '').toString(),
          address: address,
          latitude: latitude,
          longitude: longitude,
        );
      } else {
        await _backend.updateServiceAddress(
          id: existing.id,
          label: label,
          city: (result['city'] ?? existing.city).toString(),
          address: address,
          latitude: latitude,
          longitude: longitude,
        );
      }
      _syncConsole();
      _showMessage(existing == null ? '服务地址已添加并设为当前地址' : '服务地址已更新');
    } catch (error) {
      _showMessage('保存服务地址失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askLabel(String initial) async {
    final controller = TextEditingController(text: initial);
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置地址名称'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 20,
          decoration: const InputDecoration(hintText: '例如：金鸡湖附近、家、工作室'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.pop(context, value.isEmpty ? '服务地址' : value);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    controller.dispose();
    return label;
  }

  Future<void> _select(GuideAddress address) async {
    if (address.id.isEmpty || address.isSelected) return;
    setState(() => _busy = true);
    try {
      await _backend.selectServiceAddress(address.id);
      _syncConsole();
      _showMessage('已切换当前服务地址');
    } catch (error) {
      _showMessage('切换服务地址失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(GuideAddress address) async {
    if (address.id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除服务地址？'),
        content: Text(
          '将删除“${address.title}”，${address.isSelected ? '删除后会自动切换到其他地址。' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _backend.deleteServiceAddress(address.id);
      _syncConsole();
      _showMessage('服务地址已删除');
    } catch (error) {
      _showMessage('删除服务地址失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _syncConsole() {
    context.read<GuideConsoleProvider>().replaceServiceAddresses(
      _backend.serviceAddresses,
    );
  }

  double? _number(dynamic value) =>
      value == null ? null : double.tryParse(value.toString());

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final backend = context.watch<GuideBackendProvider>();
    final addresses = backend.serviceAddresses;
    final selected = backend.selectedServiceAddress;
    return GuideAppScaffold(
      safeAreaTop: false,
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 18, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      '服务地址管理',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _busy ? null : () => _pickLocation(),
                    icon: const Icon(Icons.add_location_alt_outlined),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                children: [
                  if (selected != null) _CurrentAddressCard(address: selected),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '我的服务地址',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _busy ? null : () => _pickLocation(),
                        icon: const Icon(Icons.add),
                        label: const Text('新增地址'),
                      ),
                    ],
                  ),
                  if (addresses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 56),
                      child: Center(child: Text('还没有服务地址，请在地图上添加一个地址')),
                    )
                  else
                    ...addresses.map(
                      (address) => _AddressCard(
                        address: address,
                        busy: _busy,
                        onSelect: () => _select(address),
                        onEdit: () => _pickLocation(existing: address),
                        onDelete: () => _delete(address),
                      ),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    '当前选中的服务地址会用于客户查看地陪距离排序，以及订单路费计算。',
                    style: TextStyle(color: Color(0xFF777E88), height: 1.5),
                  ),
                ],
              ),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
          ],
        ),
      ),
    );
  }
}

class _CurrentAddressCard extends StatelessWidget {
  final GuideAddress address;

  const _CurrentAddressCard({required this.address});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF8D8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFB9DF72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.my_location, color: Color(0xFF6C9D15)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前服务地址',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6C9D15)),
                ),
                const SizedBox(height: 5),
                Text(
                  address.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${address.city}${address.detail}',
                  style: const TextStyle(color: Color(0xFF59615A)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final GuideAddress address;
  final bool busy;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.busy,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              address.isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: address.isSelected
                  ? const Color(0xFF86B82D)
                  : const Color(0xFFADB4BE),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: busy || address.isSelected ? null : onSelect,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            address.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (address.isSelected)
                          const Text(
                            '当前使用',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6C9D15),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${address.city}${address.detail}',
                      style: const TextStyle(
                        color: Color(0xFF747B85),
                        height: 1.35,
                      ),
                    ),
                    if (address.latitude != null &&
                        address.longitude != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${address.latitude!.toStringAsFixed(6)}, ${address.longitude!.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFA0A6AE),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              enabled: !busy,
              onSelected: (value) {
                if (value == 'select') onSelect();
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                if (!address.isSelected)
                  const PopupMenuItem(value: 'select', child: Text('设为当前地址')),
                const PopupMenuItem(value: 'edit', child: Text('编辑地址')),
                const PopupMenuItem(value: 'delete', child: Text('删除地址')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
