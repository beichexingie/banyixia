import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_theme.dart';
import '../../providers/call_provider.dart';

enum IncomingCallAction { accept, reject, cancelled }

Future<IncomingCallAction?> showIncomingVoiceCallDialog(
  BuildContext context, {
  required Map<String, dynamic> call,
  required CallProvider callProvider,
  required String fallbackPeerName,
}) {
  return showGeneralDialog<IncomingCallAction>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, animation, secondaryAnimation) => _IncomingCallView(
      call: call,
      callProvider: callProvider,
      fallbackPeerName: fallbackPeerName,
    ),
    transitionBuilder: (_, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class _IncomingCallView extends StatefulWidget {
  final Map<String, dynamic> call;
  final CallProvider callProvider;
  final String fallbackPeerName;

  const _IncomingCallView({
    required this.call,
    required this.callProvider,
    required this.fallbackPeerName,
  });

  @override
  State<_IncomingCallView> createState() => _IncomingCallViewState();
}

class _IncomingCallViewState extends State<_IncomingCallView>
    with SingleTickerProviderStateMixin {
  Timer? _ringTimer;
  Timer? _statusTimer;
  late final AnimationController _pulseController;
  bool _checking = false;

  String get _callId =>
      widget.call['call_id']?.toString() ?? widget.call['id']?.toString() ?? '';

  String get _peerName {
    final value = widget.call['peer_name']?.toString().trim() ?? '';
    return value.isEmpty ? widget.fallbackPeerName : value;
  }

  String get _peerAvatar => widget.call['peer_avatar']?.toString().trim() ?? '';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _playRingCue();
    _ringTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _playRingCue(),
    );
    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkCallStatus(),
    );
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _statusTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _playRingCue() {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.mediumImpact();
  }

  Future<void> _checkCallStatus() async {
    if (_checking || _callId.isEmpty || !mounted) return;
    _checking = true;
    try {
      final call = await widget.callProvider.fetchVoiceCall(_callId);
      if (!mounted) return;
      if (call['status']?.toString() != 'ringing') {
        Navigator.of(context).pop(IncomingCallAction.cancelled);
      }
    } catch (_) {
      // A short network interruption should not dismiss a real incoming call.
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF263022), Color(0xFF11140F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 54, 28, 42),
              child: Column(
                children: [
                  const Text(
                    '语音通话邀请',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const Spacer(flex: 2),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (_, child) => Container(
                      width: 124 + (_pulseController.value * 8),
                      height: 124 + (_pulseController.value * 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(
                            alpha: 0.18 + _pulseController.value * 0.2,
                          ),
                          width: 8,
                        ),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: child,
                    ),
                    child: _avatar(),
                  ),
                  const SizedBox(height: 26),
                  Text(
                    _peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '邀请你进行语音通话',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const Spacer(flex: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _action(
                        color: const Color(0xFFE94F4F),
                        icon: Icons.call_end_rounded,
                        label: '拒绝',
                        onTap: () => Navigator.of(
                          context,
                        ).pop(IncomingCallAction.reject),
                      ),
                      _action(
                        color: const Color(0xFF57C84D),
                        icon: Icons.call_rounded,
                        label: '接听',
                        onTap: () => Navigator.of(
                          context,
                        ).pop(IncomingCallAction.accept),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar() {
    if (_peerAvatar.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          _peerAvatar,
          fit: BoxFit.cover,
          errorBuilder: (_, error, stackTrace) => _avatarFallback(),
        ),
      );
    }
    return _avatarFallback();
  }

  Widget _avatarFallback() {
    final text = _peerName.trim();
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F4E9),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        text.isEmpty ? '伴' : text.characters.first,
        style: const TextStyle(
          color: Color(0xFF263022),
          fontSize: 38,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _action({
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 11),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      ],
    );
  }
}
