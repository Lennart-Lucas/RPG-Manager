/// Running sum of named integer modifiers from table rolls.
class ModifierAccumulator {
  final Map<String, int> _totals = {};

  void add(Map<String, int> modifiers) {
    for (final entry in modifiers.entries) {
      _totals.update(
        entry.key,
        (value) => value + entry.value,
        ifAbsent: () => entry.value,
      );
    }
  }

  int total(String key) => _totals[key] ?? 0;

  Map<String, int> get snapshot => Map.unmodifiable(_totals);
}
