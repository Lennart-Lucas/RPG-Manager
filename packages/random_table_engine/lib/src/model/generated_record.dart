/// Runtime intermediate produced by [ProcessRunner] before typed conversion.
class GeneratedRecord {
  GeneratedRecord({
    required this.id,
    required this.type,
    this.parentId,
    this.parentField,
    Map<String, dynamic>? fields,
  }) : fields = fields ?? <String, dynamic>{};

  /// Reserved field: map of field name → roll breakdown meta.
  static const rollsField = '_rolls';

  /// Reserved field: accumulated modifiers after the full process run.
  static const modifiersField = '_modifiers';

  final String id;
  final String type;
  final String? parentId;
  final String? parentField;
  final Map<String, dynamic> fields;

  Map<String, dynamic>? get rollsMeta {
    final raw = fields[rollsField];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Map<String, int>? get modifiersMeta {
    final raw = fields[modifiersField];
    if (raw is! Map) return null;
    final out = <String, int>{};
    for (final e in raw.entries) {
      final v = e.value;
      if (v is int) {
        out['${e.key}'] = v;
      } else if (v is num) {
        out['${e.key}'] = v.toInt();
      }
    }
    return out;
  }

  @override
  String toString() =>
      'GeneratedRecord(id: $id, type: $type, parentId: $parentId, '
      'parentField: $parentField, fields: $fields)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeneratedRecord &&
          id == other.id &&
          type == other.type &&
          parentId == other.parentId &&
          parentField == other.parentField &&
          _mapEquals(fields, other.fields);

  @override
  int get hashCode => Object.hash(id, type, parentId, parentField, fields);

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
