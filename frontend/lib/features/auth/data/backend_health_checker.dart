import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';

enum BackendConnectionStatus {
  checking,
  ok,
  apiUnreachable,
  dbUnreachable,
}

class BackendHealthResult {
  const BackendHealthResult({
    required this.status,
    this.detail,
  });

  final BackendConnectionStatus status;
  final String? detail;
}

class BackendHealthChecker {
  BackendHealthChecker({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<BackendHealthResult> check() async {
    try {
      final apiResponse = await _client
          .get(Uri.parse('${AppConfig.apiBaseUrl}/health'))
          .timeout(const Duration(seconds: 3));
      if (apiResponse.statusCode != 200) {
        return BackendHealthResult(
          status: BackendConnectionStatus.apiUnreachable,
          detail: 'HTTP ${apiResponse.statusCode}',
        );
      }
    } catch (e) {
      return BackendHealthResult(
        status: BackendConnectionStatus.apiUnreachable,
        detail: e.toString(),
      );
    }

    try {
      final dbResponse = await _client
          .get(Uri.parse('${AppConfig.apiBaseUrl}/health/db'))
          .timeout(const Duration(seconds: 3));
      if (dbResponse.statusCode != 200) {
        return BackendHealthResult(
          status: BackendConnectionStatus.dbUnreachable,
          detail: 'HTTP ${dbResponse.statusCode}',
        );
      }
      final body = jsonDecode(dbResponse.body);
      if (body is Map && body['database'] != 'connected') {
        return const BackendHealthResult(
          status: BackendConnectionStatus.dbUnreachable,
          detail: 'Database not connected',
        );
      }
    } catch (e) {
      return BackendHealthResult(
        status: BackendConnectionStatus.dbUnreachable,
        detail: e.toString(),
      );
    }

    return const BackendHealthResult(status: BackendConnectionStatus.ok);
  }
}
