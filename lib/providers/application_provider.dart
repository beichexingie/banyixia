import 'package:flutter/material.dart';

import '../models/guide_application.dart';
import '../services/ecs_api_client.dart';
import '../services/risk_control_service.dart';
import '../services/session_service.dart';

class ApplicationProvider extends ChangeNotifier {
  final EcsApiClient _api = EcsApiClient();
  final SessionService _sessionService;

  List<GuideApplication> _pendingApplications = [];
  bool _isLoading = false;

  ApplicationProvider({SessionService? sessionService})
      : _sessionService = sessionService ?? EcsSessionService();

  List<GuideApplication> get pendingApplications => _pendingApplications;
  bool get isLoading => _isLoading;

  String? _token() => _sessionService.currentSession?.accessToken;

  Future<GuideApplication?> getMyApplication() async {
    try {
      final response = await _api.get('/guide-applications/me', authToken: _token());
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return GuideApplication.fromJson(data);
      }
    } catch (e) {
      debugPrint('Get my application error: $e');
    }
    return null;
  }

  Future<void> submitApplication(Map<String, dynamic> data) async {
    final bioResult = RiskControlService.checkText(data['bio'] ?? '');
    if (!bioResult['isSafe']) {
      throw Exception('简介包含违规词【${bioResult['word']}】，请修正后再试');
    }

    await _api.post(
      '/guide-applications',
      authToken: _token(),
      body: data,
    );
  }

  Future<void> loadPendingApplications() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.get('/admin/guide-applications', authToken: _token());
      final data = response['data'];
      if (data is List) {
        _pendingApplications = data
            .whereType<Map<String, dynamic>>()
            .map(GuideApplication.fromJson)
            .toList();
      }
    } catch (e) {
      debugPrint('Load applications error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> auditApplication(String id, bool approved, {String? reason}) async {
    await _api.post(
      '/admin/guide-applications/$id/audit',
      authToken: _token(),
      body: {
        'status': approved ? 'approved' : 'rejected',
        'reject_reason': reason,
      },
    );
    _pendingApplications.removeWhere((a) => a.id == id);
    notifyListeners();
  }
}
