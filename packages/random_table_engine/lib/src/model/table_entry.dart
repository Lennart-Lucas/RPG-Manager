/// One band on a [RandomTable].
class TableEntry {
  const TableEntry({
    required this.min,
    required this.max,
    required this.value,
    this.subTable,
    this.modifiers = const {},
    this.tags = const {},
  });

  final int min;
  final int max;
  final String value;
  final String? subTable;
  final Map<String, int> modifiers;
  final Map<String, dynamic> tags;

  bool matches(int roll) => roll >= min && roll <= max;

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  factory TableEntry.fromJson(Map<String, dynamic> json) {
    final int? min;
    final int? max;
    final rangeRaw = json['range'];
    if (rangeRaw != null) {
      if (rangeRaw is! List || rangeRaw.length != 2) {
        throw FormatException(
          'TableEntry.range must be a [min, max] list of two ints',
        );
      }
      min = _asInt(rangeRaw[0]);
      max = _asInt(rangeRaw[1]);
    } else {
      min = _asInt(json['min']);
      max = _asInt(json['max']);
    }
    final value = json['value'];
    if (min == null || max == null) {
      throw FormatException(
        'TableEntry requires min/max ints or range [min, max]',
      );
    }
    if (min > max) {
      throw FormatException('TableEntry min ($min) > max ($max)');
    }
    if (value is! String) {
      throw FormatException('TableEntry.value must be a String');
    }
    final subTable = json['subTable'] as String?;
    final modifiersRaw = json['modifiers'];
    final tagsRaw = json['tags'];
    final modifiers = <String, int>{};
    if (modifiersRaw is Map) {
      for (final e in modifiersRaw.entries) {
        final v = _asInt(e.value);
        if (v == null) {
          throw FormatException('Modifier "${e.key}" must be an int');
        }
        modifiers['${e.key}'] = v;
      }
    }
    final tags = <String, dynamic>{};
    if (tagsRaw is Map) {
      for (final e in tagsRaw.entries) {
        tags['${e.key}'] = e.value;
      }
    }
    return TableEntry(
      min: min,
      max: max,
      value: value,
      subTable: subTable,
      modifiers: modifiers,
      tags: tags,
    );
  }
}
