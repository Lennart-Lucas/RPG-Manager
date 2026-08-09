import '../../../mechanics/data/styled_mechanics_record.dart';
import 'extract_models.dart';

/// Build a [StyledMechanicsRecord] from an extract draft for review / commit.
StyledMechanicsRecord conditionFromExtractDraft({
  required ExtractDraft draft,
  int? sourceFileId,
}) {
  final fromEdited = _tryConditionFromEditedPayload(
    draft.payload,
    sourceFileId: sourceFileId,
  );
  if (fromEdited != null) return fromEdited;

  final payload = draft.payload;
  final rawName = payload['name'];
  final name = rawName is String && rawName.trim().isNotEmpty
      ? rawName.trim()
      : draft.displayName;

  var description = payload['description'] is String
      ? (payload['description'] as String)
      : '';
  if (description.trim().isEmpty &&
      draft.notes != null &&
      draft.notes!.trim().isNotEmpty) {
    description = draft.notes!.trim();
  }

  final iconKey = payload['iconKey'] is String &&
          (payload['iconKey'] as String).trim().isNotEmpty
      ? (payload['iconKey'] as String).trim()
      : 'monitor_heart';
  final colorArgb =
      payload['colorArgb'] is int ? payload['colorArgb'] as int : null;
  final sourcePage = draft.source.page ??
      (payload['sourcePage'] is num
          ? (payload['sourcePage'] as num).toInt()
          : null);

  return StyledMechanicsRecord(
    name: name,
    description: description,
    iconKey: iconKey,
    colorArgb: colorArgb,
    sourceFileId: sourceFileId,
    sourcePage: sourcePage,
  );
}

/// Payload written by Edit ([StyledMechanicsRecord.toJson]).
StyledMechanicsRecord? _tryConditionFromEditedPayload(
  Map<String, dynamic> payload, {
  int? sourceFileId,
}) {
  // Edited payloads always include iconKey from StyledMechanicsRecord.toJson().
  if (payload['iconKey'] is! String) return null;
  if (payload['name'] is! String) return null;

  try {
    final record = StyledMechanicsRecord.fromJson(payload);
    return record.copyWith(
      sourceFileId: sourceFileId ?? record.sourceFileId,
    );
  } catch (_) {
    return null;
  }
}
