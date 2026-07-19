/// Outcome of rolling a [RandomTable], optionally with nested sub-table detail.
class RollResult {
  const RollResult({
    required this.value,
    this.detail,
    this.modifiers = const {},
    this.tags = const {},
    this.roll,
    this.modifier = 0,
    this.total,
    this.clamped,
  });

  final String value;
  final RollResult? detail;
  final Map<String, int> modifiers;
  final Map<String, dynamic> tags;

  /// Dice total before the applied process modifier (includes dice bonus).
  final int? roll;

  /// Modifier applied from the process accumulator (or 0).
  final int modifier;

  /// [roll] + [modifier] before table clamping.
  final int? total;

  /// Value used to select the table entry (after clamping).
  final int? clamped;

  /// Flattened modifiers including nested [detail].
  Map<String, int> get allModifiers {
    final out = Map<String, int>.from(modifiers);
    if (detail != null) {
      for (final e in detail!.allModifiers.entries) {
        out.update(e.key, (v) => v + e.value, ifAbsent: () => e.value);
      }
    }
    return out;
  }

  /// JSON-friendly roll breakdown for preview / debugging.
  Map<String, dynamic> toMetaMap() => {
        if (roll != null) 'roll': roll,
        'modifier': modifier,
        if (total != null) 'total': total,
        if (clamped != null && clamped != total) 'clamped': clamped,
        if (modifiers.isNotEmpty) 'producedModifiers': modifiers,
        if (detail != null) 'detail': detail!.toMetaMap()
          ..['value'] = detail!.value,
      };
}
