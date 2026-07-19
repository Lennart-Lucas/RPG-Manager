// View-models for visualizing generator table configs on the detail page.
//
// Tolerant of engine schema and legacy aliases (`range`, lookup `entries`,
// nested `{dice:…}`) — does not require a successful engine validate.

enum GeneratorTableKind { random, lookup, process, unknown }

class GeneratorTableBand {
  const GeneratorTableBand({
    required this.min,
    required this.max,
    required this.value,
    this.subTable,
    this.modifiers = const {},
    this.tags = const {},
  });

  final int? min;
  final int? max;
  final String value;
  final String? subTable;
  final Map<String, int> modifiers;
  final Map<String, dynamic> tags;

  String get rangeLabel {
    if (min == null && max == null) return '?';
    if (min == max) return '${min ?? max}';
    return '${min ?? '?'}–${max ?? '?'}';
  }

  String get modifiersLabel {
    if (modifiers.isEmpty) return '';
    return modifiers.entries.map((e) => '${e.key}${_signed(e.value)}').join(', ');
  }

  static String _signed(int v) => v >= 0 ? '+$v' : '$v';
}

class GeneratorLookupRow {
  const GeneratorLookupRow({
    required this.key,
    required this.diceLabel,
  });

  final String key;
  final String diceLabel;
}

class GeneratorTableViz {
  const GeneratorTableViz({
    required this.id,
    required this.kind,
    this.diceLabel,
    this.keyedBy,
    this.bands = const [],
    this.lookupRows = const [],
  });

  final String id;
  final GeneratorTableKind kind;
  final String? diceLabel;
  final String? keyedBy;
  final List<GeneratorTableBand> bands;
  final List<GeneratorLookupRow> lookupRows;
}

class GeneratorTableEdge {
  const GeneratorTableEdge({
    required this.fromId,
    required this.toId,
    required this.label,
  });

  final String fromId;
  final String toId;
  final String label;
}

class GeneratorTablesGraph {
  const GeneratorTablesGraph({
    required this.tables,
    required this.edges,
    this.hasProcessHub = false,
  });

  final List<GeneratorTableViz> tables;
  final List<GeneratorTableEdge> edges;
  final bool hasProcessHub;

  static const processNodeId = '__process__';

  bool get isEmpty => tables.isEmpty;

  factory GeneratorTablesGraph.parse({
    required Map<String, dynamic> tablesDocument,
    Map<String, dynamic>? processDocument,
  }) {
    final rawTables = tablesDocument['tables'];
    final tables = <GeneratorTableViz>[];
    final edges = <GeneratorTableEdge>[];

    if (rawTables is Map) {
      final ids = rawTables.keys.map((k) => '$k').toList()..sort();
      for (final id in ids) {
        final body = rawTables[id];
        if (body is! Map) continue;
        final map = Map<String, dynamic>.from(body);
        final parsed = _parseTable(id, map);
        tables.add(parsed);
        for (final band in parsed.bands) {
          final sub = band.subTable?.trim();
          if (sub == null || sub.isEmpty) continue;
          edges.add(
            GeneratorTableEdge(fromId: id, toId: sub, label: 'sub'),
          );
        }
      }
    }

    var hasProcessHub = false;
    if (processDocument != null) {
      final refs = <({String table, String op})>[];
      _collectProcessTableRefs(processDocument['steps'], refs);
      if (refs.isNotEmpty) {
        hasProcessHub = true;
        final seen = <String>{};
        for (final ref in refs) {
          final key = '${ref.op}->${ref.table}';
          if (!seen.add(key)) continue;
          edges.add(
            GeneratorTableEdge(
              fromId: processNodeId,
              toId: ref.table,
              label: ref.op,
            ),
          );
        }
      }
    }

    return GeneratorTablesGraph(
      tables: tables,
      edges: edges,
      hasProcessHub: hasProcessHub,
    );
  }
}

GeneratorTableViz _parseTable(String id, Map<String, dynamic> body) {
  final type = body['type'] as String? ?? 'random';
  if (type == 'lookup') {
    return GeneratorTableViz(
      id: id,
      kind: GeneratorTableKind.lookup,
      keyedBy: body['keyedBy'] as String?,
      lookupRows: _parseLookupRows(body),
    );
  }
  if (type != 'random') {
    return GeneratorTableViz(id: id, kind: GeneratorTableKind.unknown);
  }
  return GeneratorTableViz(
    id: id,
    kind: GeneratorTableKind.random,
    diceLabel: _diceLabel(body['dice']),
    bands: _parseBands(body['entries']),
  );
}

List<GeneratorTableBand> _parseBands(Object? entriesRaw) {
  if (entriesRaw is! List) return const [];
  final bands = <GeneratorTableBand>[];
  for (final item in entriesRaw) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    int? min;
    int? max;
    final range = map['range'];
    if (range is List && range.length >= 2) {
      min = _asInt(range[0]);
      max = _asInt(range[1]);
    } else {
      min = _asInt(map['min']);
      max = _asInt(map['max']);
    }
    final value = map['value'];
    if (value is! String) continue;
    final modifiers = <String, int>{};
    final modifiersRaw = map['modifiers'];
    if (modifiersRaw is Map) {
      for (final e in modifiersRaw.entries) {
        final v = _asInt(e.value);
        if (v != null) modifiers['${e.key}'] = v;
      }
    }
    final tags = <String, dynamic>{};
    final tagsRaw = map['tags'];
    if (tagsRaw is Map) {
      for (final e in tagsRaw.entries) {
        tags['${e.key}'] = e.value;
      }
    }
    bands.add(
      GeneratorTableBand(
        min: min,
        max: max,
        value: value,
        subTable: map['subTable'] as String?,
        modifiers: modifiers,
        tags: tags,
      ),
    );
  }
  return bands;
}

List<GeneratorLookupRow> _parseLookupRows(Map<String, dynamic> body) {
  final valuesRaw = body['values'] ?? body['entries'];
  if (valuesRaw is! Map) return const [];
  final rows = <GeneratorLookupRow>[];
  final keys = valuesRaw.keys.map((k) => '$k').toList()..sort();
  for (final key in keys) {
    var formula = valuesRaw[key];
    if (formula is Map && formula['dice'] is Map) {
      formula = formula['dice'];
    }
    rows.add(
      GeneratorLookupRow(
        key: key,
        diceLabel: _diceLabel(formula) ?? '?',
      ),
    );
  }
  return rows;
}

String? _diceLabel(Object? raw) {
  if (raw is! Map) return null;
  final map = Map<String, dynamic>.from(raw);
  final count = _asInt(map['count']);
  final sides = _asInt(map['sides']);
  final bonus = _asInt(map['bonus']) ?? 0;
  if (count == null || sides == null) return null;
  if (bonus == 0) return '${count}d$sides';
  if (bonus > 0) return '${count}d$sides+$bonus';
  return '${count}d$sides$bonus';
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

void _collectProcessTableRefs(
  Object? stepsRaw,
  List<({String table, String op})> out,
) {
  if (stepsRaw is! List) return;
  for (final step in stepsRaw) {
    if (step is! Map) continue;
    final map = Map<String, dynamic>.from(step);
    final op = map['op'] as String? ?? '';
    final table = map['table'];
    if (table is String && table.trim().isNotEmpty) {
      final label = switch (op) {
        'roll' => 'roll',
        'lookup' => 'lookup',
        'rollMany' => 'rollMany',
        'gate' => 'gate',
        _ => op.isEmpty ? 'use' : op,
      };
      out.add((table: table.trim(), op: label));
    }
    _collectProcessTableRefs(map['then'], out);
  }
}
