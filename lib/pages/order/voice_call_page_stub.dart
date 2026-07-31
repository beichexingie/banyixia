import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../providers/call_provider.dart';

class VoiceCallPage extends StatelessWidget {
  final Map<String, dynamic> callPayload;
  final String peerName;
  final bool incoming;

  const VoiceCallPage({
    super.key,
    required this.callPayload,
    this.peerName = '订单对方',
    this.incoming = false,
  });

  @override
  Widget build(BuildContext context) {
    final callId = callPayload['call_id']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('语音联系')),
      backgroundColor: const Color(0xFFF7F7F2),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.phone_android_rounded,
                  size: 52,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(height: 16),
                const Text(
                  '请在真机上测试语音通话',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '腾讯云 TRTC 语音通话需要 Android 或 iOS 原生环境，Edge/Chrome 网页调试不支持。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      if (callId.isNotEmpty) {
                        await context.read<CallProvider>().endVoiceCall(
                              callId,
                              reason: 'unsupported_platform',
                            );
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('知道了'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
