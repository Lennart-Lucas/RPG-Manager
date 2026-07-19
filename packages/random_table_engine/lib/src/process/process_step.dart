/// One step in a [GenerationProcess].
sealed class ProcessStep {
  const ProcessStep();

  factory ProcessStep.fromJson(Map<String, dynamic> json) {
    final op = json['op'];
    if (op is! String) {
      throw FormatException('ProcessStep requires string "op"');
    }
    switch (op) {
      case 'roll':
        return RollStep.fromJson(json);
      case 'lookup':
        return LookupStep.fromJson(json);
      case 'rollMany':
        return RollManyStep.fromJson(json);
      case 'gate':
        return GateStep.fromJson(json);
      case 'addDefaultRecord':
        return AddDefaultRecordStep.fromJson(json);
      default:
        throw FormatException('Unknown process step op "$op"');
    }
  }
}

class RollStep extends ProcessStep {
  const RollStep({
    required this.table,
    required this.field,
    this.modifierFrom,
    this.emitAs,
    this.parentField,
    this.fieldMap,
    this.staticFields,
  });

  final String table;
  final String field;
  final String? modifierFrom;
  final String? emitAs;
  final String? parentField;
  final Map<String, String>? fieldMap;
  final Map<String, dynamic>? staticFields;

  factory RollStep.fromJson(Map<String, dynamic> json) {
    return RollStep(
      table: _reqString(json, 'table'),
      field: _reqString(json, 'field'),
      modifierFrom: json['modifierFrom'] as String?,
      emitAs: json['emitAs'] as String?,
      parentField: json['parentField'] as String?,
      fieldMap: _stringMap(json['fieldMap']),
      staticFields: _dynMap(json['staticFields']),
    );
  }
}

class LookupStep extends ProcessStep {
  const LookupStep({
    required this.table,
    required this.keyField,
    required this.field,
  });

  final String table;
  final String keyField;
  final String field;

  factory LookupStep.fromJson(Map<String, dynamic> json) {
    return LookupStep(
      table: _reqString(json, 'table'),
      keyField: _reqString(json, 'keyField'),
      field: _reqString(json, 'field'),
    );
  }
}

class RollManyStep extends ProcessStep {
  const RollManyStep({
    required this.table,
    required this.countField,
    this.field,
    this.emitAs,
    this.parentField,
    this.staticFields,
    this.fieldMap,
    this.rerollIfTag,
  });

  final String table;
  final String countField;
  final String? field;
  final String? emitAs;
  final String? parentField;
  final Map<String, dynamic>? staticFields;
  final Map<String, String>? fieldMap;
  final String? rerollIfTag;

  factory RollManyStep.fromJson(Map<String, dynamic> json) {
    return RollManyStep(
      table: _reqString(json, 'table'),
      countField: _reqString(json, 'countField'),
      field: json['field'] as String?,
      emitAs: json['emitAs'] as String?,
      parentField: json['parentField'] as String?,
      staticFields: _dynMap(json['staticFields']),
      fieldMap: _stringMap(json['fieldMap']),
      rerollIfTag: json['rerollIfTag'] as String?,
    );
  }
}

class GateStep extends ProcessStep {
  const GateStep({
    required this.table,
    required this.proceedValue,
    required this.thenSteps,
    this.field,
    this.emitAs,
    this.parentField,
    this.staticFields,
  });

  final String table;
  final String proceedValue;
  final List<ProcessStep> thenSteps;
  final String? field;
  final String? emitAs;
  final String? parentField;
  final Map<String, dynamic>? staticFields;

  factory GateStep.fromJson(Map<String, dynamic> json) {
    final thenRaw = json['then'];
    if (thenRaw is! List) {
      throw FormatException('GateStep requires "then" list');
    }
    final thenSteps = <ProcessStep>[];
    for (final item in thenRaw) {
      if (item is! Map<String, dynamic>) {
        throw FormatException('GateStep.then entries must be objects');
      }
      thenSteps.add(ProcessStep.fromJson(item));
    }
    return GateStep(
      table: _reqString(json, 'table'),
      proceedValue: _reqString(json, 'proceedValue'),
      thenSteps: thenSteps,
      field: json['field'] as String?,
      emitAs: json['emitAs'] as String?,
      parentField: json['parentField'] as String?,
      staticFields: _dynMap(json['staticFields']),
    );
  }
}

class AddDefaultRecordStep extends ProcessStep {
  const AddDefaultRecordStep({
    required this.emitAs,
    this.parentField,
    this.staticFields,
  });

  final String emitAs;
  final String? parentField;
  final Map<String, dynamic>? staticFields;

  factory AddDefaultRecordStep.fromJson(Map<String, dynamic> json) {
    return AddDefaultRecordStep(
      emitAs: _reqString(json, 'emitAs'),
      parentField: json['parentField'] as String?,
      staticFields: _dynMap(json['staticFields']),
    );
  }
}

String _reqString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('ProcessStep requires non-empty string "$key"');
  }
  return value;
}

Map<String, String>? _stringMap(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map) {
    throw FormatException('Expected string map');
  }
  return {
    for (final e in raw.entries) '${e.key}': '${e.value}',
  };
}

Map<String, dynamic>? _dynMap(Object? raw) {
  if (raw == null) return null;
  if (raw is! Map) {
    throw FormatException('Expected object map');
  }
  return {
    for (final e in raw.entries) '${e.key}': e.value,
  };
}
