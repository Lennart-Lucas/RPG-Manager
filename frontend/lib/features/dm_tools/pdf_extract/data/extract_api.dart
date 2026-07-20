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

  Future<ExtractJobResult> createJob({
    required String accessToken,
    required String anthropicApiKey,
    required String text,
    String? documentTitle,
    int? sourceFileId,
    String? sectionHint,
  }) async {
    final encoded = jsonEncode({
      'kind': 'spells',
      'document_title': ?documentTitle,
      'source_file_id': ?sourceFileId,
      'text': text,
      'section_hint': ?sectionHint,
    });
    // #region agent log
    http
        .post(
          Uri.parse(
            'http://127.0.0.1:7407/ingest/3ebe5f69-cb83-47c4-be24-ce1801f79526',
          ),
          headers: {
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': '5823b4',
          },
          body: jsonEncode({
            'sessionId': '5823b4',
            'runId': 'post-fix',
            'hypothesisId': 'A',
            'location': 'extract_api.dart:createJob',
            'message': 'sending extract job request',
            'data': {
              'uri': _jobsUri.toString(),
              'bodyBytes': encoded.length,
              'textLen': text.length,
              'hasAuth': accessToken.isNotEmpty,
              'hasAnthropicKey': anthropicApiKey.trim().isNotEmpty,
            },
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }),
        )
        .catchError((_) => http.Response('', 500));
    // #endregion
    final response = await _client.post(
      _jobsUri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Anthropic-Api-Key': anthropicApiKey,
      },
      body: encoded,
    );
    // #region agent log
    http
        .post(
          Uri.parse(
            'http://127.0.0.1:7407/ingest/3ebe5f69-cb83-47c4-be24-ce1801f79526',
          ),
          headers: {
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': '5823b4',
          },
          body: jsonEncode({
            'sessionId': '5823b4',
            'runId': 'claude-debug',
            'hypothesisId': 'C1',
            'location': 'extract_api.dart:createJob:response',
            'message': 'extract job response',
            'data': {
              'status': response.statusCode,
              'detailPreview': response.body.length > 300
                  ? response.body.substring(0, 300)
                  : response.body,
            },
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }),
        )
        .catchError((_) => http.Response('', 500));
    // #endregion
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
    final result = ExtractJobResult.fromJson(body);
    // #region agent log
    final first = result.drafts.isEmpty ? null : result.drafts.first;
    http
        .post(
          Uri.parse(
            'http://127.0.0.1:7407/ingest/3ebe5f69-cb83-47c4-be24-ce1801f79526',
          ),
          headers: {
            'Content-Type': 'application/json',
            'X-Debug-Session-Id': '5823b4',
          },
          body: jsonEncode({
            'sessionId': '5823b4',
            'runId': 'claude-debug',
            'hypothesisId': 'C1',
            'location': 'extract_api.dart:createJob:drafts',
            'message': 'first draft summary',
            'data': {
              'draftCount': result.drafts.length,
              'firstName': first?.displayName,
              'firstPayloadKeys': first?.payload.keys.toList(),
              'firstNeedsReview': first?.needsReview,
              'firstNotes': first?.notes,
              'firstUnknown': first?.unknownFields?.keys.toList(),
              'firstTier': first?.tier,
              'nameOnlyCount': result.drafts
                  .where((d) => d.payload.keys.length <= 1)
                  .length,
              'claudeErrorCount': result.drafts
                  .where((d) => d.needsReview.contains('claude_error'))
                  .length,
              'schemaFailCount': result.drafts
                  .where(
                    (d) => d.needsReview.contains('schema_validation_failed'),
                  )
                  .length,
            },
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }),
        )
        .catchError((_) => http.Response('', 500));
    // #endregion
    return result;
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
