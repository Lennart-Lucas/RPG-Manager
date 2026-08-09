import 'dart:convert';

import '../../../../core/config/app_config.dart';
import '../../../../core/offline/authenticated_http.dart';
import '../../../../core/offline/offline_sync_controller.dart';
import '../../../auth/data/auth_api.dart';
import 'user_activity_model.dart';

class UsersApi {
  UsersApi({AuthenticatedHttp? httpClient})
      : _http = httpClient ?? OfflineSyncController.instance.httpClient;

  final AuthenticatedHttp _http;

  Uri _uri(String path) =>
      Uri.parse('${AppConfig.apiBaseUrl}${AppConfig.apiPrefix}$path');

  Map<String, String> _headers(String accessToken) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

  Future<List<UserActivity>> listUsers(String accessToken) async {
    final response = await _http.get(
      uri: _uri('/users'),
      headers: _headers(accessToken),
    );
    if (response.statusCode != 200) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw AuthApiException('Unexpected users response');
    }
    return [
      for (final entry in decoded)
        if (entry is Map<String, dynamic>) UserActivity.fromJson(entry),
    ];
  }

  Future<void> reportPageVisit({
    required String accessToken,
    required String path,
    required String title,
  }) async {
    final response = await _http.mutate(
      method: 'POST',
      uri: _uri('/users/me/activity'),
      headers: _headers(accessToken),
      body: jsonEncode({
        'path': path,
        'title': title,
      }),
      successStatus: 200,
      buildOptimisticBody: (_) => {
            'id': 0,
            'email': '',
            'is_dm': true,
            'recent_pages': const [],
          },
    );
    if (response.statusCode != 200) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
  }

  String _errorMessage(dynamic response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        final detail = decoded['detail'];
        if (detail is String) return detail;
      }
    } catch (_) {}
    return 'Request failed (${response.statusCode})';
  }
}
