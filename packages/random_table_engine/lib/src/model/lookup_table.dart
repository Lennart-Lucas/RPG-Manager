import '../core/dice_formula.dart';
import '../core/roller.dart';

/// Maps a string key to a [DiceFormula] and rolls it.
class LookupTable {
  LookupTable({
    required this.id,
    required this.keyedBy,
    required this.values,
  });

  final String id;
  final String keyedBy;
  final Map<String, DiceFormula> values;

  static Map<String, dynamic> _asMap(Object? raw, String label) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw FormatException(label);
  }

  factory LookupTable.fromJson(String id, Map<String, dynamic> json) {
    final keyedBy = json['keyedBy'];
    if (keyedBy is! String || keyedBy.isEmpty) {
      throw FormatException('LookupTable "$id" requires keyedBy string');
    }
    // Accept both `values` (engine schema) and `entries` (legacy alias).
    final valuesRaw = json['values'] ?? json['entries'];
    if (valuesRaw is! Map) {
      throw FormatException('LookupTable "$id" requires values map');
    }
    final values = <String, DiceFormula>{};
    for (final e in valuesRaw.entries) {
      var formulaRaw = e.value;
      if (formulaRaw is Map && formulaRaw['dice'] is Map) {
        formulaRaw = formulaRaw['dice'];
      }
      final formulaMap = _asMap(
        formulaRaw,
        'LookupTable "$id" value "${e.key}" must be a dice formula object',
      );
      values['${e.key}'] = DiceFormula.fromJson(formulaMap);
    }
    return LookupTable(id: id, keyedBy: keyedBy, values: values);
  }

  int resolve(String key, Roller roller) {
    final formula = values[key];
    if (formula == null) {
      throw StateError('LookupTable "$id" has no formula for key "$key"');
    }
    return formula.roll(roller);
  }
}
