import 'lookup_table.dart';
import 'random_table.dart';

/// Loaded set of random and lookup tables with validation.
class TableRegistry {
  TableRegistry._({
    required Map<String, RandomTable> randomTables,
    required Map<String, LookupTable> lookupTables,
  })  : _randomTables = Map.unmodifiable(randomTables),
        _lookupTables = Map.unmodifiable(lookupTables);

  final Map<String, RandomTable> _randomTables;
  final Map<String, LookupTable> _lookupTables;

  factory TableRegistry.fromJson(Map<String, dynamic> json) {
    final tablesRaw = json['tables'];
    if (tablesRaw is! Map) {
      throw FormatException('Registry JSON requires a "tables" object');
    }

    final randomTables = <String, RandomTable>{};
    final lookupTables = <String, LookupTable>{};
    final errors = <String>[];

    for (final entry in tablesRaw.entries) {
      final id = '${entry.key}';
      final body = entry.value;
      if (body is! Map) {
        errors.add('Table "$id" must be an object');
        continue;
      }
      final bodyMap = body is Map<String, dynamic>
          ? body
          : Map<String, dynamic>.from(body);
      final type = bodyMap['type'] as String? ?? 'random';
      try {
        if (type == 'lookup') {
          if (lookupTables.containsKey(id) || randomTables.containsKey(id)) {
            errors.add('Duplicate table id "$id"');
            continue;
          }
          lookupTables[id] = LookupTable.fromJson(id, bodyMap);
        } else if (type == 'random') {
          if (lookupTables.containsKey(id) || randomTables.containsKey(id)) {
            errors.add('Duplicate table id "$id"');
            continue;
          }
          randomTables[id] = RandomTable.fromJson(id, bodyMap);
        } else {
          errors.add('Table "$id" has unknown type "$type"');
        }
      } catch (e) {
        errors.add('Table "$id": $e');
      }
    }

    for (final table in randomTables.values) {
      for (final entry in table.entries) {
        final sub = entry.subTable;
        if (sub == null || sub.isEmpty) continue;
        if (!randomTables.containsKey(sub)) {
          errors.add(
            'Table "${table.id}" entry "${entry.value}" '
            '(${entry.min}-${entry.max}) references missing subTable "$sub"',
          );
        }
      }
    }

    if (errors.isNotEmpty) {
      throw FormatException(
        'TableRegistry validation failed:\n- ${errors.join('\n- ')}',
      );
    }

    return TableRegistry._(
      randomTables: randomTables,
      lookupTables: lookupTables,
    );
  }

  RandomTable get(String id) {
    final table = _randomTables[id];
    if (table == null) {
      throw StateError('Unknown random table "$id"');
    }
    return table;
  }

  LookupTable getLookup(String id) {
    final table = _lookupTables[id];
    if (table == null) {
      throw StateError('Unknown lookup table "$id"');
    }
    return table;
  }

  bool hasRandom(String id) => _randomTables.containsKey(id);
  bool hasLookup(String id) => _lookupTables.containsKey(id);
}
