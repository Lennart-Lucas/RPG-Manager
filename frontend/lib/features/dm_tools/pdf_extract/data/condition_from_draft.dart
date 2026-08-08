import '../../../mechanics/data/styled_mechanics_record.dart';
import 'extract_models.dart';

/// Build a [StyledMechanicsRecord] from an extract draft for review / commit.
StyledMechanicsRecord conditionFromExtractDraft({
  required ExtractDraft draft,
}) {
  final fromEdited = _tryConditionFromEditedPayload(draft.payload);
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

  return StyledMechanicsRecord(
    name: name,
    description: description,
    iconKey: iconKey,
    colorArgb: colorArgb,
  );
}

/// Payload written by Edit ([StyledMechanicsRecord.toJson]).
StyledMechanicsRecord? _tryConditionFromEditedPayload(
  Map<String, dynamic> payload,
) {
  // Edited payloads always include iconKey from StyledMechanicsRecord.toJson().
  if (payload['iconKey'] is! String) return null;
  if (payload['name'] is! String) return null;

  try {
    return StyledMechanicsRecord.fromJson(payload);
  } catch (_) {
    return null;
  }
}
