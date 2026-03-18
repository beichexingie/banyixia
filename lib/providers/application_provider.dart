import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/guide_application.dart';
import '../services/risk_control_service.dart';

/// 地陪申请状态管理
class ApplicationProvider extends ChangeNotifier {
  List<GuideApplication> _pendingApplications = [];
  bool _isLoading = false;

  List<GuideApplication> get pendingApplications => _pendingApplications;
  bool get isLoading => _isLoading;

  /// 获取当前用户的申请状态
  Future<GuideApplication?> getMyApplication() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await Supabase.instance.client
          .from('guide_applications')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      
      if (response != null) {
        return GuideApplication.fromJson(response);
      }
    } catch (e) {
      debugPrint('Get my application error: $e');
    }
    return null;
  }

  /// 提交申请
  Future<void> submitApplication(Map<String, dynamic> data) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) throw Exception('请先登录');

    // 查重：检查是否已有申请
    final existingApp = await getMyApplication();
    if (existingApp != null && existingApp.status != 'rejected') {
      final statusMap = {'pending': '审核中', 'approved': '已入驻'};
      throw Exception('您已有申请处于${statusMap[existingApp.status] ?? "处理"}状态，请勿重复提交');
    }

    // 1. 内容合规风控 (风险控制)
    final bioResult = RiskControlService.checkText(data['bio'] ?? '');
    if (!bioResult['isSafe']) {
      throw Exception('简介包含违规词【${bioResult['word']}】，请修正后再试');
    }

    try {
      await Supabase.instance.client.from('guide_applications').upsert({
        'user_id': user.id,
        ...data,
      });
    } catch (e) {
      debugPrint('Submit application error: $e');
      throw Exception('提交失败: $e');
    }
  }

  /// 加载待审核列表 (仅管理员权限)
  Future<void> loadPendingApplications() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await Supabase.instance.client
          .from('guide_applications')
          .select()
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      _pendingApplications = (response as List)
          .map((data) => GuideApplication.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Load applications error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// 审核操作
  Future<void> auditApplication(String id, bool approved, {String? reason}) async {
    try {
      final status = approved ? 'approved' : 'rejected';
      
      // 1. 查询申请详情 (防止列表不同步)
      final appResponse = await Supabase.instance.client
          .from('guide_applications')
          .select()
          .eq('id', id)
          .single();
      final app = GuideApplication.fromJson(appResponse);

      // 2. 更新申请表状态
      await Supabase.instance.client
          .from('guide_applications')
          .update({'status': status, 'reject_reason': reason})
          .eq('id', id);

      // 提示：guides 表的数据同步现在由数据库触发器 (on_guide_application_approved) 自动处理
      // 这样可以确保即使管理员没有 guides 表的写入权限，同步也会成功。

      // 刷新本地列表
      _pendingApplications.removeWhere((a) => a.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint('Audit application error: $e');
      throw Exception('操作失败: $e');
    }
  }
}
