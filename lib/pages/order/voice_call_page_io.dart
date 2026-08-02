import 'package:flutter/material.dart';
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

class _VoiceCallPageState extends State<VoiceCallPage> {
  TRTCCloud? _trtcCloud;
  TRTCCloudListener? _listener;

  bool _initializing = true;
  bool _enteredRoom = false;
  bool _remoteJoined = false;
  bool _muted = false;
  bool _speakerOn = false;
  bool _ending = false;
  String? _error;
  String? _remoteUserId;

  String get _callId => widget.callPayload['call_id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _joinRoom();
  }

  @override
  void dispose() {
    _leaveRoom();
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = '需要麦克风权限才能进行语音通话';
      });
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
      _listener = TRTCCloudListener(
        onError: (code, message) {
          if (!mounted) return;
          setState(() {
            _initializing = false;
            _error = '通话连接失败：$code $message';
          });
        },
        onEnterRoom: (result) {
          if (!mounted) return;
          setState(() {
            _initializing = false;
            _enteredRoom = result > 0;
            if (result < 0) {
              _error = '进入语音房间失败：$result';
            }
          });
        },
        onRemoteUserEnterRoom: (userId) {
          if (!mounted) return;
          setState(() {
            _remoteJoined = true;
            _remoteUserId = userId;
          });
        },
        onUserAudioAvailable: (userId, available) {
          if (!mounted) return;
          setState(() {
            _remoteJoined = available || _remoteJoined;
            _remoteUserId = userId;
          });
        },
        onRemoteUserLeaveRoom: (userId, reason) {
          if (!mounted) return;
          setState(() {
            _remoteJoined = false;
            _remoteUserId = null;
          });
        },
        onExitRoom: (_) {
          if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = error.toString();
      });
    }
  }

  void _leaveRoom() {
    final cloud = _trtcCloud;
    final listener = _listener;
    if (cloud == null) return;
    try {
      cloud.stopLocalAudio();
      cloud.exitRoom();
      if (listener != null) {
        cloud.unRegisterListener(listener);
      }
      TRTCCloud.destroySharedInstance();
    } catch (_) {}
    _trtcCloud = null;
    _listener = null;
  }

  Future<void> _finishCall({String reason = 'ended'}) async {
    if (_ending) return;
    setState(() => _ending = true);
    try {
      if (_callId.isNotEmpty) {
        await context.read<CallProvider>().endVoiceCall(
              _callId,
              reason: reason,
            );
      }
    } catch (_) {
      // Even if the server update fails, release the local audio room first.
    } finally {
      _leaveRoom();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _toggleMute() async {
    final next = !_muted;
    _trtcCloud?.muteLocalAudio(next);
    setState(() => _muted = next);
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speakerOn;
    _trtcCloud?.getDeviceManager().setAudioRoute(
          next ? TXAudioRoute.speakerPhone : TXAudioRoute.earpiece,
        );
    setState(() => _speakerOn = next);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.incoming ? '正在接听' : '语音联系';
    final status = _statusText;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _finishCall(reason: 'back');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F2),
        body: SafeArea(
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF5FFE2),
                  Color(0xFFE5FF9F),
                  Color(0xFFF7F7F2),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _ending ? null : () => _finishCall(reason: 'back'),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                const Spacer(),
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _avatarText(widget.peerName),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  widget.peerName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _error == null
                        ? AppColors.textSecondary
                        : AppColors.warning,
                  ),
                ),
                if (_remoteUserId != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '对方已加入',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _roundAction(
                        icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                        label: _muted ? '已静音' : '静音',
                        onTap: _enteredRoom && !_ending ? _toggleMute : null,
                      ),
                      _hangupButton(),
                      _roundAction(
                        icon: _speakerOn
                            ? Icons.volume_up_rounded
                            : Icons.hearing_rounded,
                        label: _speakerOn ? '扬声器' : '听筒',
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
    if (_error != null) return _error!;
    if (_ending) return '正在结束通话...';
    if (_initializing) return '正在连接语音服务...';
    if (!_enteredRoom) return '等待进入房间...';
    if (_remoteJoined) return '通话中';
    return widget.incoming ? '已接听，等待对方加入...' : '正在呼叫对方...';
  }

  Widget _roundAction({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final enabled = onTap != null;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: enabled ? AppColors.textPrimary : AppColors.textHint,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: enabled ? AppColors.textSecondary : AppColors.textHint,
          ),
        ),
      ],
    );
  }

  Widget _hangupButton() {
    return Column(
      children: [
        InkWell(
          onTap: _ending ? null : () => _finishCall(),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFFF5A5A),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.call_end_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '挂断',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
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

  String _avatarText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '伴';
    return trimmed.characters.first;
  }
}
