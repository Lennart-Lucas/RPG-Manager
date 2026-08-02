import 'package:random_table_engine/generation_engine.dart';

/// Human-readable label from a camelCase / snake_case identifier.
String humanizeGeneratorFieldId(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  final spaced = trimmed
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (m) => '${m[1]} ${m[2]}',
      )
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (spaced.isEmpty) return trimmed;
  return spaced[0].toUpperCase() + spaced.substring(1);
}

/// How a rollMany [countField] is produced earlier in the process.
class GeneratorCountSource {
  const GeneratorCountSource({
    required this.field,
    required this.tableId,
    required this.kind,
    this.keyField,
    this.keyTableId,
  });

  final String field;
  final String tableId;
  final GeneratorScalarKind kind;
  final String? keyField;

  /// Random table that produces [keyField], when that field is a roll step.
  final String? keyTableId;

  bool get canRoll =>
      kind == GeneratorScalarKind.roll || kind == GeneratorScalarKind.lookup;
}

/// UI-facing description of what a generator process can accept before a run.
class GeneratorInputSpec {
  const GeneratorInputSpec({
    required this.recordType,
    required this.nodes,
  });

  final String recordType;
  final List<GeneratorInputNode> nodes;

  bool get isEmpty => nodes.isEmpty;

  /// Builds a spec from parsed process + tables.
  factory GeneratorInputSpec.fromProcess({
    required GenerationProcess process,
    required TableRegistry registry,
  }) {
    final countFields = _countFieldsUsedByRollMany(process.steps);
    final countSources = _countSources(process.steps);
    final walked = _walkSteps(
      process.steps,
      registry,
      depth: 0,
      countFields: countFields,
      countSources: countSources,
    );
    // Root catalog names are almost always typed; offer a pin even when the
    // process has no name roll/lookup step.
    final nodes = _containsScalarId(walked, 'name')
        ? walked
        : [
            const GeneratorScalarInput(
              id: 'name',
              label: 'Name',
              tableId: '',
              options: [],
              kind: GeneratorScalarKind.manual,
              depth: 0,
              helperText: 'Catalog name for this record (typed manually)',
            ),
            ...walked,
          ];
    return GeneratorInputSpec(
      recordType: process.recordType,
      nodes: nodes,
    );
  }

  static bool _containsScalarId(List<GeneratorInputNode> nodes, String id) {
    final needle = id.toLowerCase();
    for (final node in nodes) {
      switch (node) {
        case GeneratorScalarInput():
          if (node.id.toLowerCase() == needle) return true;
        case GeneratorGateInput():
          if (_containsScalarId(node.thenNodes, id)) return true;
        case GeneratorCollectionInput():
          break;
      }
    }
    return false;
  }

  static Set<String> _countFieldsUsedByRollMany(List<ProcessStep> steps) {
    final out = <String>{};
    void walk(List<ProcessStep> list) {
      for (final step in list) {
        switch (step) {
          case RollManyStep():
            out.add(step.countField);
          case GateStep():
            walk(step.thenSteps);
          default:
            break;
        }
      }
    }

    walk(steps);
    return out;
  }

  static Map<String, GeneratorCountSource> _countSources(
    List<ProcessStep> steps,
  ) {
    final rollTables = <String, String>{};
    final out = <String, GeneratorCountSource>{};
    void walk(List<ProcessStep> list) {
      for (final step in list) {
        switch (step) {
          case RollStep():
            rollTables.putIfAbsent(step.field, () => step.table);
            out.putIfAbsent(
              step.field,
              () => GeneratorCountSource(
                field: step.field,
                tableId: step.table,
                kind: GeneratorScalarKind.roll,
              ),
            );
          case LookupStep():
            out.putIfAbsent(
              step.field,
              () => GeneratorCountSource(
                field: step.field,
                tableId: step.table,
                kind: GeneratorScalarKind.lookup,
                keyField: step.keyField,
                keyTableId: rollTables[step.keyField],
              ),
            );
          case GateStep():
            walk(step.thenSteps);
          default:
            break;
        }
      }
    }

    walk(steps);
    // Second pass: fill keyTableId if the key roll appeared after the lookup
    // in a nested gate (unusual) or we missed it on first insert.
    for (final e in out.entries.toList()) {
      final source = e.value;
      if (source.kind != GeneratorScalarKind.lookup) continue;
      if (source.keyTableId != null || source.keyField == null) continue;
      final keyTable = rollTables[source.keyField];
      if (keyTable == null) continue;
      out[e.key] = GeneratorCountSource(
        field: source.field,
        tableId: source.tableId,
        kind: source.kind,
        keyField: source.keyField,
        keyTableId: keyTable,
      );
    }
    return out;
  }

  static List<GeneratorInputNode> _walkSteps(
    List<ProcessStep> steps,
    TableRegistry registry, {
    required int depth,
    required Set<String> countFields,
    required Map<String, GeneratorCountSource> countSources,
  }) {
    final nodes = <GeneratorInputNode>[];
    for (final step in steps) {
      switch (step) {
        case RollStep(:final emitAs)
            when emitAs == null || emitAs.trim().isEmpty:
          if (countFields.contains(step.field)) break;
          nodes.add(
            GeneratorScalarInput(
              id: step.field,
              label: humanizeGeneratorFieldId(step.field),
              tableId: step.table,
              options: _tableOptions(registry, step.table),
              kind: GeneratorScalarKind.roll,
              depth: depth,
            ),
          );
        case RollStep():
          if (countFields.contains(step.field)) break;
          nodes.add(
            GeneratorScalarInput(
              id: step.field,
              label: humanizeGeneratorFieldId(step.field),
              tableId: step.table,
              options: _tableOptions(registry, step.table),
              kind: GeneratorScalarKind.roll,
              depth: depth,
              helperText: step.emitAs == null
                  ? null
                  : 'Creates a ${step.emitAs} record',
            ),
          );
        case LookupStep():
          // Count fields are edited on their rollMany collection instead.
          if (countFields.contains(step.field)) break;
          nodes.add(
            GeneratorScalarInput(
              id: step.field,
              label: humanizeGeneratorFieldId(step.field),
              tableId: step.table,
              options: const [],
              kind: GeneratorScalarKind.lookup,
              depth: depth,
              helperText:
                  'Usually derived from ${humanizeGeneratorFieldId(step.keyField)}',
              keyField: step.keyField,
            ),
          );
        case GateStep():
          final gateId = step.field ?? step.table;
          nodes.add(
            GeneratorGateInput(
              id: gateId,
              label: humanizeGeneratorFieldId(gateId),
              tableId: step.table,
              options: _tableOptions(registry, step.table),
              proceedValue: step.proceedValue,
              depth: depth,
              thenNodes: _walkSteps(
                step.thenSteps,
                registry,
                depth: depth + 1,
                countFields: countFields,
                countSources: countSources,
              ),
            ),
          );
        case RollManyStep():
          final key = rollManyOverrideKey(
            parentField: step.parentField,
            field: step.field,
            table: step.table,
          );
          nodes.add(
            GeneratorCollectionInput(
              id: key,
              label: humanizeGeneratorFieldId(
                step.parentField ?? step.emitAs ?? step.field ?? step.table,
              ),
              tableId: step.table,
              options: _tableOptions(registry, step.table),
              countField: step.countField,
              countSource: countSources[step.countField],
              depth: depth,
              itemLabel: humanizeGeneratorFieldId(
                step.emitAs ?? step.field ?? 'item',
              ),
            ),
          );
        case AddDefaultRecordStep():
          break;
      }
    }
    return nodes;
  }

  static List<String> _tableOptions(TableRegistry registry, String tableId) {
    try {
      final table = registry.get(tableId);
      final seen = <String>{};
      final out = <String>[];
      for (final entry in table.entries) {
        final v = entry.value.trim();
        if (v.isEmpty) continue;
        final key = v.toLowerCase();
        if (seen.contains(key)) continue;
        seen.add(key);
        out.add(v);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}

sealed class GeneratorInputNode {
  const GeneratorInputNode({
    required this.id,
    required this.label,
    required this.depth,
  });

  final String id;
  final String label;
  final int depth;
}

enum GeneratorScalarKind { roll, lookup, manual }

/// Whether [fieldId] is treated as a manually typed name in the generate UI.
bool generatorFieldIsName(String fieldId) =>
    fieldId.trim().toLowerCase() == 'name';

class GeneratorScalarInput extends GeneratorInputNode {
  const GeneratorScalarInput({
    required super.id,
    required super.label,
    required this.tableId,
    required this.options,
    required this.kind,
    required super.depth,
    this.helperText,
    this.keyField,
  });

  final String tableId;
  final List<String> options;
  final GeneratorScalarKind kind;
  final String? helperText;
  final String? keyField;

  bool get canRoll =>
      kind == GeneratorScalarKind.roll && tableId.trim().isNotEmpty;

  /// Prefer an inline text field (names are usually typed, not rolled).
  bool get prefersTextInput =>
      kind == GeneratorScalarKind.manual || generatorFieldIsName(id);
}

class GeneratorGateInput extends GeneratorInputNode {
  const GeneratorGateInput({
    required super.id,
    required super.label,
    required this.tableId,
    required this.options,
    required this.proceedValue,
    required super.depth,
    this.thenNodes = const [],
  });

  final String tableId;
  final List<String> options;
  final String proceedValue;
  final List<GeneratorInputNode> thenNodes;
}

class GeneratorCollectionInput extends GeneratorInputNode {
  const GeneratorCollectionInput({
    required super.id,
    required super.label,
    required this.tableId,
    required this.options,
    required this.countField,
    required super.depth,
    required this.itemLabel,
    this.countSource,
  });

  final String tableId;
  final List<String> options;
  final String countField;
  final String itemLabel;
  final GeneratorCountSource? countSource;

  bool get canRollCount => countSource?.canRoll == true;
}

/// Mutable user session for the Generate workspace.
class GeneratorRunSession {
  GeneratorRunSession();

  /// Pinned scalar / gate field values (absent = Auto).
  final Map<String, String> fieldPins = {};

  /// Forced collection counts (absent = Auto from countField).
  final Map<String, int> collectionCounts = {};

  /// Per-collection slot pins: null/missing entry = Auto for that index.
  final Map<String, List<String?>> collectionSlots = {};

  /// Minimum slots the user explicitly reserved ("Add known"), not count padding.
  final Map<String, int> collectionKnownFloors = {};

  void clear() {
    fieldPins.clear();
    collectionCounts.clear();
    collectionSlots.clear();
    collectionKnownFloors.clear();
  }

  bool get hasPins =>
      fieldPins.isNotEmpty ||
      collectionCounts.isNotEmpty ||
      collectionSlots.values.any((slots) => slots.any((s) => s != null));

  /// Fills pins/slots/counts from a preview so the setup form shows rolled values.
  void hydrateFromRecords({
    required List<GeneratedRecord> records,
    required List<GeneratorInputNode> nodes,
  }) {
    if (records.isEmpty) return;
    GeneratedRecord root = records.first;
    for (final r in records) {
      if (r.parentId == null) {
        root = r;
        break;
      }
    }

    void walk(List<GeneratorInputNode> list) {
      for (final node in list) {
        switch (node) {
          case GeneratorScalarInput():
            final text = _stringifyField(root.fields[node.id]);
            if (text != null) fieldPins[node.id] = text;
          case GeneratorGateInput():
            final text = _stringifyField(root.fields[node.id]);
            if (text != null) fieldPins[node.id] = text;
            walk(node.thenNodes);
          case GeneratorCollectionInput():
            final children = [
              for (final r in records)
                if (r.parentField == node.id) r,
            ];
            collectionCounts[node.id] = children.length;
            fieldPins[node.countField] = '${children.length}';
            final slots = <String?>[
              for (final child in children) preferredRecordName(child),
            ];
            collectionSlots[node.id] = slots;
            collectionKnownFloors[node.id] = children.length;
        }
      }
    }

    walk(nodes);
  }

  /// Collection node ids (parentField keys) covered by the input spec.
  static Set<String> collectionIdsIn(List<GeneratorInputNode> nodes) {
    final out = <String>{};
    void walk(List<GeneratorInputNode> list) {
      for (final node in list) {
        switch (node) {
          case GeneratorCollectionInput():
            out.add(node.id);
          case GeneratorGateInput():
            walk(node.thenNodes);
          case GeneratorScalarInput():
            break;
        }
      }
    }

    walk(nodes);
    return out;
  }

  static String? preferredRecordName(GeneratedRecord record) {
    final name = _stringifyField(record.fields['name']);
    if (name != null) return name;
    return _stringifyField(record.fields['value']);
  }

  static String preferredNameFieldKey(GeneratedRecord record) {
    final name = _stringifyField(record.fields['name']);
    if (name != null) return 'name';
    if (record.fields.containsKey('value')) return 'value';
    return 'name';
  }

  static String? _stringifyField(Object? value) {
    if (value == null) return null;
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  void setFieldPin(String id, String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      fieldPins.remove(id);
    } else {
      fieldPins[id] = trimmed;
    }
  }

  /// Floor for count changes: known reserved slots and/or filled pins.
  /// Empty Auto pads from a previous count roll do not count.
  int knownSlotFloor(String collectionId) {
    final reserved = collectionKnownFloors[collectionId] ?? 0;
    final slots = collectionSlots[collectionId] ?? const <String?>[];
    var filledThrough = 0;
    for (var i = 0; i < slots.length; i++) {
      if (slots[i] != null) filledThrough = i + 1;
    }
    return reserved > filledThrough ? reserved : filledThrough;
  }

  void setCollectionCount(String id, int? count, {String? countField}) {
    if (count == null || count < 0) {
      collectionCounts.remove(id);
      if (countField != null) fieldPins.remove(countField);
      final floor = knownSlotFloor(id);
      final slots = List<String?>.from(collectionSlots[id] ?? const []);
      if (slots.length > floor) {
        slots.removeRange(floor, slots.length);
      }
      if (slots.isEmpty) {
        collectionSlots.remove(id);
      } else {
        collectionSlots[id] = slots;
      }
      return;
    }
    final floor = knownSlotFloor(id);
    final effective = count < floor ? floor : count;
    collectionCounts[id] = effective;
    if (countField != null) {
      fieldPins[countField] = '$effective';
    }
    final slots = List<String?>.from(collectionSlots[id] ?? const []);
    while (slots.length < effective) {
      slots.add(null);
    }
    if (slots.length > effective) {
      slots.removeRange(effective, slots.length);
    }
    collectionSlots[id] = slots;
  }

  void setSlotPin(String collectionId, int index, String? value,
      {String? countField}) {
    final slots = List<String?>.from(collectionSlots[collectionId] ?? const []);
    while (slots.length <= index) {
      slots.add(null);
    }
    final trimmed = value?.trim();
    slots[index] = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    collectionSlots[collectionId] = slots;
    if (trimmed != null && trimmed.isNotEmpty) {
      final reserved = collectionKnownFloors[collectionId] ?? 0;
      if (index + 1 > reserved) {
        collectionKnownFloors[collectionId] = index + 1;
      }
    }
    final needed = knownSlotFloor(collectionId);
    final current = collectionCounts[collectionId];
    // Only raise an explicit count; Auto keeps a slot floor via minCount.
    if (current != null && current < needed) {
      collectionCounts[collectionId] = needed;
      if (countField != null) fieldPins[countField] = '$needed';
    }
  }

  void addKnownSlot(String collectionId, {String? countField}) {
    final slots = List<String?>.from(collectionSlots[collectionId] ?? const []);
    slots.add(null);
    collectionSlots[collectionId] = slots;
    final reserved = collectionKnownFloors[collectionId] ?? 0;
    collectionKnownFloors[collectionId] =
        slots.length > reserved ? slots.length : reserved;
    final current = collectionCounts[collectionId];
    if (current != null && current < slots.length) {
      collectionCounts[collectionId] = slots.length;
      if (countField != null) fieldPins[countField] = '${slots.length}';
    }
  }

  int slotCountFor(String collectionId) {
    final forced = collectionCounts[collectionId];
    final slots = collectionSlots[collectionId]?.length ?? 0;
    if (forced != null) return forced > slots ? forced : slots;
    return knownSlotFloor(collectionId);
  }

  bool get hasSparseCollectionPins {
    for (final slots in collectionSlots.values) {
      var seenNull = false;
      for (final slot in slots) {
        if (slot == null) {
          seenNull = true;
        } else if (seenNull) {
          return true;
        }
      }
    }
    return false;
  }

  /// Collection ids that have a pin after an Auto (null) slot.
  List<String> get sparseCollectionPinIds {
    final out = <String>[];
    for (final e in collectionSlots.entries) {
      var seenNull = false;
      for (final slot in e.value) {
        if (slot == null) {
          seenNull = true;
        } else if (seenNull) {
          out.add(e.key);
          break;
        }
      }
    }
    return out;
  }

  GenerationOverrides toOverrides() {
    final fields = <String, dynamic>{...fieldPins};
    final collections = <String, RollManyOverride>{};
    for (final e in collectionSlots.entries) {
      final slots = e.value;
      final pinned = <String>[];
      for (final slot in slots) {
        if (slot == null) break;
        pinned.add(slot);
      }
      var count = collectionCounts[e.key];
      final floor = knownSlotFloor(e.key);
      if (count != null && count < floor) count = floor;
      // Auto + known slots: minCount floors the generated/lookup count.
      final minCount = count == null && floor > 0 ? floor : null;
      if (count == null && pinned.isEmpty && minCount == null) continue;
      collections[e.key] = RollManyOverride(
        count: count,
        minCount: minCount,
        pinnedValues: pinned,
      );
    }
    for (final e in collectionCounts.entries) {
      if (collections.containsKey(e.key)) continue;
      collections[e.key] = RollManyOverride(count: e.value);
    }
    return GenerationOverrides(fields: fields, collections: collections);
  }
}
