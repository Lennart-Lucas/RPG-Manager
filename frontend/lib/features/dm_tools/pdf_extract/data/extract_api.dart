import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../auth/data/auth_api.dart';
import 'extract_models.dart';

class ExtractApi {
  ExtractApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri get _jobsUri => Uri.parse(
        '${AppConfig.apiBaseUrl}${AppConfig.apiPrefix}/extract/jobs',
      );

  Uri get _processClassUri => Uri.parse(
        '${AppConfig.apiBaseUrl}${AppConfig.apiPrefix}/extract/process-class',
      );

  Future<ExtractJobResult> createJob({
    required String accessToken,
    required String anthropicApiKey,
    required String text,
    String kind = 'spells',
    String? documentTitle,
    int? sourceFileId,
    String? sectionHint,
  }) async {
    final response = await _client.post(
      _jobsUri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Anthropic-Api-Key': anthropicApiKey,
      },
      body: jsonEncode({
        'kind': kind,
        'document_title': ?documentTitle,
        'source_file_id': ?sourceFileId,
        'text': text,
        'section_hint': ?sectionHint,
      }),
    );
    if (response.statusCode != 200) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw AuthApiException('Unexpected extract response');
    }
    return ExtractJobResult.fromJson(body);
  }

  /// Process class/subclass form JSON with Claude. Returns updated payload map.
  Future<Map<String, dynamic>> processClass({
    required String accessToken,
    required String anthropicApiKey,
    required String kind,
    required String prompt,
    required Map<String, dynamic> current,
    Map<String, dynamic>? definition,
  }) async {
    final response = await _client.post(
      _processClassUri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Anthropic-Api-Key': anthropicApiKey,
      },
      body: jsonEncode({
        'kind': kind,
        'prompt': prompt,
        'current': current,
        'definition': ?definition,
      }),
    );
    if (response.statusCode != 200) {
      throw AuthApiException(
        _errorMessage(response),
        statusCode: response.statusCode,
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      throw AuthApiException('Unexpected process-class response');
    }
    final payload = body['payload'];
    if (payload is! Map<String, dynamic>) {
      throw AuthApiException('Unexpected process-class payload');
    }
    return payload;
  }

  String _errorMessage(http.Response response) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['detail'] != null) {
        final detail = body['detail'];
        if (detail is String) return detail;
        return detail.toString();
      }
    } catch (_) {}
    return 'Extract request failed (${response.statusCode})';
  }
}
