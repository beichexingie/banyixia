import 'package:flutter/foundation.dart';

import '../services/ecs_api_client.dart';
import '../services/session_service.dart';

class CallProvider extends ChangeNotifier {
  final EcsApiClient _api = EcsApiClient();
  final SessionService _sessionService;

  CallProvider({SessionService? sessionService})
      : _sessionService = sessionService ?? EcsSessionService();

  String? _token() => _sessionService.currentSession?.accessToken;

  Future<Map<String, dynamic>> createVoiceCall(String orderId) async {
    final response = await _api.post(
      '/orders/$orderId/calls',
      authToken: _token(),
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw Exception('Voice call response is invalid');
  }

  Future<List<Map<String, dynamic>>> fetchIncomingVoiceCalls() async {
    final response = await _api.get('/calls/incoming', authToken: _token());
    final data = response['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Future<Map<String, dynamic>> joinVoiceCall(String callId) async {
    final response = await _api.post(
      '/calls/$callId/join',
      authToken: _token(),
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw Exception('Voice call join response is invalid');
  }

  Future<Map<String, dynamic>> endVoiceCall(
    String callId, {
    String reason = 'ended',
  }) async {
    final response = await _api.post(
      '/calls/$callId/end',
      authToken: _token(),
      body: {'reason': reason},
    );
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    throw Exception('Voice call end response is invalid');
  }
}
