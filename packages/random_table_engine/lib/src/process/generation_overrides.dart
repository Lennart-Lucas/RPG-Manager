/// User/app pins applied when running a [GenerationProcess].
class GenerationOverrides {
  const GenerationOverrides({
    this.fields = const {},
    this.collections = const {},
  });

  /// Empty overrides (all steps roll normally).
  static const empty = GenerationOverrides();

  /// Pinned scalar field values for `roll`, `lookup`, and `gate` steps.
  ///
  /// Keys are destination field names (`RollStep.field`, `LookupStep.field`,
  /// or for gates `field ?? table`).
  final Map<String, dynamic> fields;

  /// Pinned `rollMany` collections, keyed by `parentField ?? field ?? table`.
  final Map<String, RollManyOverride> collections;

  bool get isEmpty => fields.isEmpty && collections.isEmpty;

  bool get isNotEmpty => !isEmpty;

  /// Builds overrides from a flat field map (legacy `ProcessRunner.run` API).
  factory GenerationOverrides.fromFieldMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return empty;
    return GenerationOverrides(fields: Map<String, dynamic>.from(map));
  }

  GenerationOverrides copyWith({
    Map<String, dynamic>? fields,
    Map<String, RollManyOverride>? collections,
  }) {
    return GenerationOverrides(
      fields: fields ?? this.fields,
      collections: collections ?? this.collections,
    );
  }
}

/// Pins for a single `rollMany` step.
class RollManyOverride {
  const RollManyOverride({
    this.count,
    this.minCount,
    this.pinnedValues = const [],
  });

  /// Forces how many results to produce. When null, uses the process
  /// `countField` (or at least [pinnedValues.length] / [minCount]).
  final int? count;

  /// Lower bound when [count] is null: final size is
  /// `max(countField, minCount, pinnedValues.length)`.
  final int? minCount;

  /// Known values used as the first results; remaining slots are rolled.
  final List<String> pinnedValues;

  bool get isEmpty =>
      count == null && minCount == null && pinnedValues.isEmpty;

  RollManyOverride copyWith({
    int? count,
    int? minCount,
    List<String>? pinnedValues,
    bool clearCount = false,
    bool clearMinCount = false,
  }) {
    return RollManyOverride(
      count: clearCount ? null : (count ?? this.count),
      minCount: clearMinCount ? null : (minCount ?? this.minCount),
      pinnedValues: pinnedValues ?? this.pinnedValues,
    );
  }
}

/// Stable collection key for a [RollManyStep]-like descriptor.
String rollManyOverrideKey({
  String? parentField,
  String? field,
  required String table,
}) {
  final parent = parentField?.trim();
  if (parent != null && parent.isNotEmpty) return parent;
  final f = field?.trim();
  if (f != null && f.isNotEmpty) return f;
  return table;
}
