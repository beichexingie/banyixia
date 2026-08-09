import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_1/config/guide_service_catalog.dart';
import 'package:flutter_application_1/config/app_theme.dart';
import '../../providers/user_provider.dart';
import '../widgets/guide_app_shell.dart';

class GuideServiceTypePage extends StatefulWidget {
  const GuideServiceTypePage({super.key});

  @override
  State<GuideServiceTypePage> createState() => _GuideServiceTypePageState();
}

class _GuideServiceTypePageState extends State<GuideServiceTypePage> {
  late Set<String> _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<UserProvider>().user;
    _selected = user.guideTags.toSet();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final userProvider = context.read<UserProvider>();
      await userProvider.updateUser(
        userProvider.user.copyWith(guideTags: _selected.toList()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('服务类型已保存')));
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GuideAppScaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('服务类型'), backgroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.35,
              ),
              itemCount: guideServiceCatalog.length,
              itemBuilder: (context, index) {
                final label = guideServiceCatalog[index];
                final selected = _selected.contains(label);
                return InkWell(
                  onTap: () => setState(() {
                    if (selected) {
                      _selected.remove(label);
                    } else {
                      _selected.add(label);
                    }
                  }),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primarySoft : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryDark
                            : const Color(0xFFE4E5E8),
                      ),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  elevation: 0,
                ),
                child: Text(_saving ? '保存中...' : '保存'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
