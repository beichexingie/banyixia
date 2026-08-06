import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:tencent_rtc_sdk/trtc_cloud.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_def.dart';
import 'package:tencent_rtc_sdk/trtc_cloud_listener.dart';
import 'package:tencent_rtc_sdk/tx_device_manager.dart';

import '../../config/app_theme.dart';
import '../../providers/call_provider.dart';

class VoiceCallPage extends StatefulWidget {
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
  State<VoiceCallPage> createState() => _VoiceCallPageState();
}

class _VoiceCallPageState extends State<VoiceCallPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  TRTCCloud? _trtcCloud;
  TRTCCloudListener? _listener;
  Timer? _statusTimer;
  Timer? _durationTimer;
  late final AnimationController _pulseController;

  bool _initializing = true;
  bool _enteredRoom = false;
  bool _remoteJoined = false;
  bool _muted = false;
  bool _speakerOn = false;
  bool _ending = false;
  bool _closed = false;
  bool _checkingStatus = false;
  String? _error;
  String? _terminalMessage;
  DateTime? _answeredAt;
  Duration _duration = Duration.zero;

  String get _callId => widget.callPayload['call_id']?.toString() ?? '';

  String get _peerName {
    final payloadName =
        widget.callPayload['peer_name']?.toString().trim() ?? '';
    return payloadName.isEmpty ? widget.peerName : payloadName;
  }

  String get _peerAvatar =>
      widget.callPayload['peer_avatar']?.toString().trim() ?? '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _readInitialAnsweredAt();
    _joinRoom();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _checkServerStatus(),
    );
    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateDuration(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkServerStatus();
    }
    if (state == AppLifecycleState.detached && !_closed && !_ending) {
      unawaited(_endOnServer('app_terminated'));
    }
  }

  @override
  void dispose() {
    _closed = true;
    WidgetsBinding.instance.removeObserver(this);
    _statusTimer?.cancel();
    _durationTimer?.cancel();
    _pulseController.dispose();
    _leaveRoom();
    super.dispose();
  }

  void _readInitialAnsweredAt() {
    final raw = widget.callPayload['answered_at']?.toString() ?? '';
    _answeredAt = DateTime.tryParse(raw)?.toLocal();
  }

  Future<void> _joinRoom() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = micStatus.isPermanentlyDenied
            ? '麦克风权限已被关闭，请到系统设置中允许后重试'
            : '需要麦克风权限才能进行语音通话';
      });
      unawaited(_endOnServer('microphone_permission_denied'));
      return;
    }

    try {
      final trtc = _mapOf(widget.callPayload['trtc']);
      final sdkAppId = _asInt(trtc['sdk_app_id']);
      final roomId = _asInt(widget.callPayload['room_id']);
      final userId = trtc['user_id']?.toString() ?? '';
      final userSig = trtc['user_sig']?.toString() ?? '';
      if (sdkAppId <= 0 || roomId <= 0 || userId.isEmpty || userSig.isEmpty) {
        throw Exception('TRTC 通话参数不完整');
      }

      final cloud = await TRTCCloud.sharedInstance();
      if (!mounted || _closed) return;
      _listener = TRTCCloudListener(
        onError: (code, message) {
          if (!mounted || _closed) return;
          setState(() {
            _initializing = false;
            _error = '通话连接失败：$code $message';
          });
        },
        onEnterRoom: (result) {
          if (!mounted || _closed) return;
          setState(() {
            _initializing = false;
            _enteredRoom = result > 0;
            if (result < 0) {
              _error = '进入语音房间失败：$result';
            }
          });
        },
        onRemoteUserEnterRoom: (_) => _markRemoteJoined(),
        onUserAudioAvailable: (_, available) {
          if (available) _markRemoteJoined();
        },
        onRemoteUserLeaveRoom: (_, reason) {
          if (!mounted || _closed || _ending) return;
          unawaited(_handlePeerLeft());
        },
        onExitRoom: (_) {
          if (!mounted || _closed) return;
          setState(() {
            _enteredRoom = false;
            _remoteJoined = false;
          });
        },
      );

      _trtcCloud = cloud;
      cloud.registerListener(_listener!);
      cloud.setDefaultStreamRecvMode(true, false);
      cloud.getDeviceManager().setAudioRoute(TXAudioRoute.earpiece);
      cloud.enterRoom(
        TRTCParams(
          sdkAppId: sdkAppId,
          userId: userId,
          userSig: userSig,
          roomId: roomId,
        ),
        TRTCAppScene.audioCall,
      );
      cloud.startLocalAudio(TRTCAudioQuality.speech);
    } catch (error) {
      if (!mounted || _closed) return;
      setState(() {
        _initializing = false;
        _error = '无法启动语音通话：$error';
      });
      unawaited(_endOnServer('trtc_start_failed'));
    }
  }

  void _markRemoteJoined() {
    if (!mounted || _closed) return;
    setState(() {
      _remoteJoined = true;
      _answeredAt ??= DateTime.now();
      _error = null;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _checkServerStatus() async {
    if (_checkingStatus || _callId.isEmpty || _closed || _ending) return;
    _checkingStatus = true;
    try {
      final call = await context.read<CallProvider>().fetchVoiceCall(_callId);
      if (!mounted || _closed) return;
      final status = call['status']?.toString() ?? '';
      if (status == 'answered' && _answeredAt == null) {
        final raw = call['answered_at']?.toString() ?? '';
        setState(() {
          _answeredAt = DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
        });
      } else if (status == 'ended') {
        await _handleRemoteEnd(call['end_reason']?.toString() ?? 'ended');
      }
    } catch (_) {
      // TRTC audio may remain healthy during a temporary API interruption.
    } finally {
      _checkingStatus = false;
    }
  }

  Future<void> _handlePeerLeft() async {
    try {
      final call = await context.read<CallProvider>().fetchVoiceCall(_callId);
      final reason = call['end_reason']?.toString() ?? 'peer_left';
      if (call['status']?.toString() != 'ended') {
        await _endOnServer('peer_left');
      }
      await _handleRemoteEnd(reason == 'ended' ? 'peer_left' : reason);
    } catch (_) {
      await _endOnServer('peer_left');
      await _handleRemoteEnd('peer_left');
    }
  }

  Future<void> _handleRemoteEnd(String reason) async {
    if (_ending || _closed || !mounted) return;
    _ending = true;
    _statusTimer?.cancel();
    _terminalMessage = _endReasonText(reason);
    setState(() {});
    _leaveRoom();
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (mounted && !_closed) {
      Navigator.of(context).pop();
    }
  }

  void _updateDuration() {
    final answeredAt = _answeredAt;
    if (!mounted || answeredAt == null || _ending) return;
    final next = DateTime.now().difference(answeredAt);
    setState(() => _duration = next.isNegative ? Duration.zero : next);
  }

  void _leaveRoom() {
    final cloud = _trtcCloud;
    final listener = _listener;
    if (cloud == null) return;
    try {
      cloud.stopLocalAudio();
      if (listener != null) {
        cloud.unRegisterListener(listener);
      }
      cloud.exitRoom();
      TRTCCloud.destroySharedInstance();
    } catch (_) {}
    _trtcCloud = null;
    _listener = null;
  }

  Future<void> _endOnServer(String reason) async {
    if (_callId.isEmpty) return;
    try {
      await context.read<CallProvider>().endVoiceCall(_callId, reason: reason);
    } catch (_) {}
  }

  Future<void> _finishCall({String reason = 'hangup'}) async {
    if (_ending || _closed) return;
    setState(() {
      _ending = true;
      _terminalMessage = '通话已结束';
    });
    await _endOnServer(reason);
    _leaveRoom();
    if (mounted && !_closed) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmHangup() async {
    if (_ending) return;
    final shouldHangup = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('结束语音通话？'),
        content: const Text('返回将同时挂断当前通话。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续通话'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('结束'),
          ),
        ],
      ),
    );
    if (shouldHangup == true) {
      await _finishCall(reason: 'back');
    }
  }

  void _toggleMute() {
    final next = !_muted;
    _trtcCloud?.muteLocalAudio(next);
    setState(() => _muted = next);
  }

  void _toggleSpeaker() {
    final next = !_speakerOn;
    _trtcCloud?.getDeviceManager().setAudioRoute(
      next ? TXAudioRoute.speakerPhone : TXAudioRoute.earpiece,
    );
    setState(() => _speakerOn = next);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_confirmHangup());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF171B15),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF303A2B), Color(0xFF11140F)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _ending ? null : _confirmHangup,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, child) => Container(
                    width:
                        118 + (!_remoteJoined ? _pulseController.value * 8 : 0),
                    height:
                        118 + (!_remoteJoined ? _pulseController.value * 8 : 0),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        width: 7,
                        color: AppColors.primary.withValues(
                          alpha: _remoteJoined
                              ? 0.18
                              : 0.12 + _pulseController.value * 0.16,
                        ),
                      ),
                    ),
                    child: child,
                  ),
                  child: _avatar(),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Text(
                    _peerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _error == null
                          ? Colors.white70
                          : const Color(0xFFFFA7A7),
                      fontSize: 15,
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: openAppSettings,
                    child: const Text('打开系统设置'),
                  ),
                ],
                const Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 38),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _roundAction(
                        icon: _muted
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                        label: _muted ? '取消静音' : '静音',
                        active: _muted,
                        onTap: _enteredRoom && !_ending ? _toggleMute : null,
                      ),
                      _hangupButton(),
                      _roundAction(
                        icon: _speakerOn
                            ? Icons.volume_up_rounded
                            : Icons.hearing_rounded,
                        label: _speakerOn ? '扬声器' : '听筒',
                        active: _speakerOn,
                        onTap: _enteredRoom && !_ending ? _toggleSpeaker : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String get _statusText {
    if (_terminalMessage != null) return _terminalMessage!;
    if (_error != null) return _error!;
    if (_ending) return '正在结束通话...';
    if (_initializing) return '正在连接语音服务...';
    if (!_enteredRoom) return '正在进入通话...';
    if (_remoteJoined) return _formatDuration(_duration);
    if (_answeredAt != null) return '对方已接听，正在建立连接...';
    return widget.incoming ? '正在接通...' : '正在等待对方接听...';
  }

  String _endReasonText(String reason) {
    return switch (reason) {
      'timeout' => '对方暂时无人接听',
      'customer_rejected' || 'guide_rejected' || 'rejected' => '对方已拒绝',
      'peer_left' || 'hangup' || 'back' => '对方已挂断',
      'busy' => '对方正在通话中',
      _ => '通话已结束',
    };
  }

  String _formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
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
        color: Color(0xFFF0F4E8),
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

  Widget _roundAction({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: active
                  ? Colors.white
                  : Colors.white.withValues(alpha: enabled ? 0.16 : 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: active ? const Color(0xFF171B15) : Colors.white,
              size: 27,
            ),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _hangupButton() {
    return Column(
      children: [
        InkWell(
          onTap: _ending ? null : _finishCall,
          customBorder: const CircleBorder(),
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE94F4F),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 9),
        const Text('挂断', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Map<String, dynamic> _mapOf(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const {};
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
