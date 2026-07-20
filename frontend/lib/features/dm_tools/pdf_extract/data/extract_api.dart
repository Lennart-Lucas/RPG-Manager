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
    final response = await _client.post(
      _jobsUri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
        'X-Anthropic-Api-Key': anthropicApiKey,
      },
      body: jsonEncode({
        'kind': 'spells',
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
    final result = ExtractJobResult.fromJson(body);
    // #region agent log
    final summaries = <Map<String, Object?>>[];
    var softOnly = 0;
    var hardFail = 0;
    var nullName = 0;
    var missingCore = 0;
    for (final d in result.drafts) {
      final name = d.payload['name'];
      final hasName = name is String && name.trim().isNotEmpty;
      if (!hasName) nullName++;
      final coreMissing = !hasName ||
          d.payload['level'] == null ||
          d.payload['school'] == null ||
          ((d.payload['description'] as String?)?.trim().isEmpty ?? true);
      if (coreMissing) missingCore++;
      final hard = d.isHardReviewIssue;
      final softOnlyFlag = !hard &&
          d.needsReview.any(
            (r) =>
                r == 'unknown_fields' ||
                r == 'notes_present' ||
                r == 'duplicate_in_batch' ||
                r == 'duplicate_in_library',
          );
      if (hard) {
        hardFail++;
      } else if (softOnlyFlag) {
        softOnly++;
      }
      summaries.add({
        'name': d.displayName,
        'needs': d.needsReview,
        'risk': d.riskScore,
        'hard': hard,
        'hasName': hasName,
        'coreMissing': coreMissing,
        'notesLen': d.notes?.length ?? 0,
        'unknownKeys': d.unknownFields?.keys.toList() ?? const [],
        'page': d.source.page,
      });
    }
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
            'hypothesisId': 'D1',
            'location': 'extract_api.dart:createJob:draftBreakdown',
            'message': 'per-draft review breakdown',
            'data': {
              'draftCount': result.drafts.length,
              'softOnly': softOnly,
              'hardFail': hardFail,
              'nullName': nullName,
              'missingCore': missingCore,
              'warningIconCount': result.drafts
                  .where((d) => !d.rejected && d.isHardReviewIssue)
                  .length,
              'drafts': summaries,
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
