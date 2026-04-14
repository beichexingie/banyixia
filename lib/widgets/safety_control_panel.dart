import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

class SafetyControlPanel extends StatefulWidget {
  final String orderId;
  const SafetyControlPanel({super.key, required this.orderId});

  @override
  State<SafetyControlPanel> createState() => _SafetyControlPanelState();
}

class _SafetyControlPanelState extends State<SafetyControlPanel> {
  bool _isRecording = false;
  bool _isGpsOn = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('行程安全监控中', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue)),
              const Spacer(),
              if (_isGpsOn)
                const Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text('GPS 已开启', style: TextStyle(fontSize: 11, color: Colors.green)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildActionButton(
                icon: _isRecording ? Icons.stop_circle : Icons.mic_none,
                label: _isRecording ? '停止录音' : '开启录音',
                color: _isRecording ? Colors.red : AppColors.textPrimary,
                onTap: () {
                  setState(() => _isRecording = !_isRecording);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_isRecording ? '行程录音已开始，将上传全云端加密存档' : '录音已停止并保存'))
                  );
                },
              ),
              const VerticalDivider(width: 1),
              _buildActionButton(
                icon: Icons.map_outlined,
                label: '实时轨迹',
                color: AppColors.textPrimary,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('正在实时同步位置给平台与紧急联系人')));
                },
              ),
              const VerticalDivider(width: 1),
              _buildActionButton(
                icon: Icons.emergency_share,
                label: '紧急求助',
                color: Colors.red,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('发起紧急求助？'),
                      content: const Text('系统将立即上报地理位置、开启强制录音并联系平台安全中心。'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('确认发起', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}
