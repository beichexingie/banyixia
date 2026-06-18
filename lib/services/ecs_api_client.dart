import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class EcsApiException implements Exception {
  final int statusCode;
  final String message;

  const EcsApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class EcsApiClient {
  final http.Client _client;

  EcsApiClient({http.Client? client}) : _client = client ?? http.Client();

  String get baseUrl => AppConfig.apiBaseUrl.trim().replaceAll(RegExp(r'/$'), '');

  Map<String, String> _buildHeaders({
    String? authToken,
    String? userId,
    bool jsonBody = true,
  }) {
    final headers = <String, String>{};
    if (jsonBody) {
      headers['Content-Type'] = 'application/json';
    }
    if (authToken != null && authToken.trim().isNotEmpty) {
      headers['Authorization'] = 'Bearer ${authToken.trim()}';
      headers['x-user-id'] = authToken.trim();
    }
    if (userId != null && userId.trim().isNotEmpty) {
      headers['x-user-id'] = userId.trim();
    }
    return headers;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    String? authToken,
    String? userId,
    Map<String, dynamic>? query,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: query?.map((key, value) => MapEntry(key, value.toString())),
    );
    final response = await _client.get(
      uri,
      headers: _buildHeaders(authToken: authToken, userId: userId, jsonBody: false),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    String? authToken,
    String? userId,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.post(
      uri,
      headers: _buildHeaders(authToken: authToken, userId: userId),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    String? authToken,
    String? userId,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.put(
      uri,
      headers: _buildHeaders(authToken: authToken, userId: userId),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    String? authToken,
    String? userId,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final response = await _client.send(
      http.Request('DELETE', uri)
        ..headers.addAll(_buildHeaders(authToken: authToken, userId: userId))
        ..body = jsonEncode(body ?? const <String, dynamic>{}),
    );
    final streamed = await http.Response.fromStream(response);
    return _decode(streamed);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw EcsApiException(response.statusCode, '后端返回了无效数据');
    }
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded['success'] == false) {
      throw EcsApiException(
        response.statusCode,
        decoded['message']?.toString() ?? '请求失败',
      );
    }
    return decoded;
  }
}
