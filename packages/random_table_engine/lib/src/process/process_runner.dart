import '../core/id_generator.dart';
import '../core/modifier_accumulator.dart';
import '../core/roller.dart';
import '../model/generated_record.dart';
import '../model/roll_result.dart';
import '../model/table_registry.dart';
import 'generation_process.dart';
import 'process_step.dart';

/// Interprets a [GenerationProcess] against a [TableRegistry].
class ProcessRunner {
  ProcessRunner({
    required TableRegistry registry,
    required Roller roller,
    required IdGenerator idGenerator,
  })  : _registry = registry,
        _roller = roller,
        _ids = idGenerator;

  final TableRegistry _registry;
  final Roller _roller;
  final IdGenerator _ids;

  List<GeneratedRecord> run(
    GenerationProcess process, {
    Map<String, dynamic>? overrides,
  }) {
    final emitted = <GeneratedRecord>[];
    final modifiers = ModifierAccumulator();
    final root = GeneratedRecord(
      id: _ids.next(),
      type: process.recordType,
    );
    emitted.add(root);

    _runSteps(
      steps: process.steps,
      current: root,
      parentScopeId: root.id,
      emitted: emitted,
      modifiers: modifiers,
      overrides: overrides ?? const {},
    );

    root.fields[GeneratedRecord.modifiersField] = Map<String, int>.from(
      modifiers.snapshot,
    );
    return emitted;
  }

  void _attachRollMeta(
    Map<String, dynamic> fields,
    String field,
    RollResult result,
  ) {
    final rolls = fields.putIfAbsent(
      GeneratedRecord.rollsField,
      () => <String, dynamic>{},
    ) as Map<String, dynamic>;
    rolls[field] = {
      ...result.toMetaMap(),
      'value': result.value,
    };
  }

  void _runSteps({
    required List<ProcessStep> steps,
    required GeneratedRecord current,
    required String parentScopeId,
    required List<GeneratedRecord> emitted,
    required ModifierAccumulator modifiers,
    required Map<String, dynamic> overrides,
  }) {
    for (final step in steps) {
      switch (step) {
        case RollStep():
          _runRoll(
            step,
            current: current,
            parentScopeId: parentScopeId,
            emitted: emitted,
            modifiers: modifiers,
            overrides: overrides,
          );
        case LookupStep():
          _runLookup(step, current: current);
        case RollManyStep():
          _runRollMany(
            step,
            current: current,
            parentScopeId: parentScopeId,
            emitted: emitted,
            modifiers: modifiers,
          );
        case GateStep():
          _runGate(
            step,
            current: current,
            parentScopeId: parentScopeId,
            emitted: emitted,
            modifiers: modifiers,
            overrides: overrides,
          );
        case AddDefaultRecordStep():
          _runAddDefault(
            step: step,
            parentScopeId: parentScopeId,
            emitted: emitted,
          );
      }
    }
  }

  void _runRoll(
    RollStep step, {
    required GeneratedRecord current,
    required String parentScopeId,
    required List<GeneratedRecord> emitted,
    required ModifierAccumulator modifiers,
    required Map<String, dynamic> overrides,
  }) {
    final RollResult result;
    if (overrides.containsKey(step.field)) {
      final pinned = overrides[step.field];
      result = RollResult(value: '$pinned');
    } else {
      final mod = step.modifierFrom == null
          ? 0
          : modifiers.total(step.modifierFrom!);
      result = _registry.get(step.table).roll(
            _roller,
            _registry,
            modifier: mod,
          );
      modifiers.add(result.allModifiers);
    }

    final fieldValues = <String, dynamic>{
      step.field: result.value,
      if (result.detail != null) '${step.field}Detail': result.detail!.value,
      ...?step.staticFields,
    };
    if (step.fieldMap != null) {
      for (final e in step.fieldMap!.entries) {
        fieldValues[e.value] = fieldValues[e.key] ?? result.value;
      }
    }
    _attachRollMeta(fieldValues, step.field, result);
    if (result.detail != null) {
      _attachRollMeta(fieldValues, '${step.field}Detail', result.detail!);
    }

    if (step.emitAs != null) {
      final child = GeneratedRecord(
        id: _ids.next(),
        type: step.emitAs!,
        parentId: parentScopeId,
        parentField: step.parentField,
        fields: fieldValues,
      );
      emitted.add(child);
    } else {
      _mergeFields(current.fields, fieldValues);
    }
  }

  void _mergeFields(
    Map<String, dynamic> target,
    Map<String, dynamic> incoming,
  ) {
    final incomingRolls = incoming.remove(GeneratedRecord.rollsField);
    target.addAll(incoming);
    if (incomingRolls is Map) {
      final rolls = target.putIfAbsent(
        GeneratedRecord.rollsField,
        () => <String, dynamic>{},
      ) as Map<String, dynamic>;
      for (final e in incomingRolls.entries) {
        rolls['${e.key}'] = e.value;
      }
    }
  }

  void _runLookup(LookupStep step, {required GeneratedRecord current}) {
    final key = current.fields[step.keyField];
    if (key == null) {
      throw StateError(
        'LookupStep: current record missing keyField "${step.keyField}"',
      );
    }
    final value = _registry.getLookup(step.table).resolve('$key', _roller);
    current.fields[step.field] = value;
    final rolls = current.fields.putIfAbsent(
      GeneratedRecord.rollsField,
      () => <String, dynamic>{},
    ) as Map<String, dynamic>;
    rolls[step.field] = {
      'roll': value,
      'modifier': 0,
      'total': value,
      'value': value,
      'lookupKey': '$key',
    };
  }

  void _runRollMany(
    RollManyStep step, {
    required GeneratedRecord current,
    required String parentScopeId,
    required List<GeneratedRecord> emitted,
    required ModifierAccumulator modifiers,
  }) {
    final countRaw = current.fields[step.countField];
    final count = switch (countRaw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ??
          (throw StateError('rollMany countField is not an int: $countRaw')),
      _ => throw StateError('rollMany countField is not an int: $countRaw'),
    };

    bool Function(String)? rerollIf;
    if (step.rerollIfTag != null) {
      final tag = step.rerollIfTag!;
      rerollIf = (value) {
        return value == tag;
      };
    }

    final results = _registry.get(step.table).rollMany(
          count,
          _roller,
          _registry,
          rerollIf: rerollIf,
        );

    if (step.emitAs != null) {
      for (final result in results) {
        modifiers.add(result.allModifiers);
        final fields = <String, dynamic>{
          'value': result.value,
          if (result.detail != null) 'detail': result.detail!.value,
          ...?step.staticFields,
        };
        if (step.fieldMap != null) {
          for (final e in step.fieldMap!.entries) {
            fields[e.value] = fields[e.key] ?? result.value;
          }
        }
        final metaField = step.fieldMap?['value'] ?? 'value';
        _attachRollMeta(fields, metaField, result);
        if (result.detail != null) {
          _attachRollMeta(fields, 'detail', result.detail!);
        }
        emitted.add(
          GeneratedRecord(
            id: _ids.next(),
            type: step.emitAs!,
            parentId: parentScopeId,
            parentField: step.parentField,
            fields: fields,
          ),
        );
      }
    } else {
      final field = step.field ?? step.table;
      final list = <String>[];
      final metaList = <Map<String, dynamic>>[];
      for (final result in results) {
        modifiers.add(result.allModifiers);
        list.add(result.value);
        metaList.add({
          ...result.toMetaMap(),
          'value': result.value,
        });
      }
      current.fields[field] = list;
      final rolls = current.fields.putIfAbsent(
        GeneratedRecord.rollsField,
        () => <String, dynamic>{},
      ) as Map<String, dynamic>;
      rolls[field] = metaList;
    }
  }

  void _runGate(
    GateStep step, {
    required GeneratedRecord current,
    required String parentScopeId,
    required List<GeneratedRecord> emitted,
    required ModifierAccumulator modifiers,
    required Map<String, dynamic> overrides,
  }) {
    final result = _registry.get(step.table).roll(_roller, _registry);
    modifiers.add(result.allModifiers);

    if (result.value != step.proceedValue) {
      final metaKey = step.field ?? step.table;
      _attachRollMeta(current.fields, metaKey, result);
      if (step.field != null) {
        current.fields[step.field!] = result.value;
      }
      return;
    }

    if (step.emitAs != null) {
      final childFields = <String, dynamic>{
        ...?step.staticFields,
        if (step.field != null) step.field!: result.value,
      };
      if (step.field != null) {
        _attachRollMeta(childFields, step.field!, result);
      } else {
        _attachRollMeta(childFields, step.table, result);
      }
      final child = GeneratedRecord(
        id: _ids.next(),
        type: step.emitAs!,
        parentId: parentScopeId,
        parentField: step.parentField,
        fields: childFields,
      );
      emitted.add(child);
      _runSteps(
        steps: step.thenSteps,
        current: child,
        parentScopeId: child.id,
        emitted: emitted,
        modifiers: modifiers,
        overrides: overrides,
      );
    } else {
      if (step.field != null) {
        current.fields[step.field!] = result.value;
        _attachRollMeta(current.fields, step.field!, result);
      } else {
        _attachRollMeta(current.fields, step.table, result);
      }
      _runSteps(
        steps: step.thenSteps,
        current: current,
        parentScopeId: parentScopeId,
        emitted: emitted,
        modifiers: modifiers,
        overrides: overrides,
      );
    }
  }

  void _runAddDefault({
    required AddDefaultRecordStep step,
    required String parentScopeId,
    required List<GeneratedRecord> emitted,
  }) {
    emitted.add(
      GeneratedRecord(
        id: _ids.next(),
        type: step.emitAs,
        parentId: parentScopeId,
        parentField: step.parentField,
        fields: {...?step.staticFields},
      ),
    );
  }
}
