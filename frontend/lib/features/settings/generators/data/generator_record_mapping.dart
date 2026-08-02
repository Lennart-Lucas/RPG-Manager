import 'package:random_table_engine/generation_engine.dart';

import '../../../catalog/data/catalog_kind.dart';

/// App-owned sidecar that maps generated records onto catalog creates.
class GeneratorRecordMapping {
  const GeneratorRecordMapping({
    this.version = 1,
    this.bindings = const [],
  });

  final int version;
  final List<GeneratorRecordBinding> bindings;

  static Map<String, dynamic> get emptyDocument => {
        'version': 1,
        'bindings': <dynamic>[],
      };

  bool get hasBindings => bindings.isNotEmpty;

  /// Finds the binding for [record], including locations catalog-type aliases.
  ///
  /// Exact `matchType == record.type` wins. If a locations binding's
  /// `matchType` is a known location type name (e.g. `city`) and no generated
  /// record uses that type, the binding also matches the process root record
  /// (so authors can use matchType as the catalog location type).
  GeneratorRecordBinding? bindingFor(
    GeneratedRecord record, {
    required List<GeneratedRecord> allRecords,
    String? processRecordType,
  }) {
    final generatedTypes = {for (final r in allRecords) r.type};
    final rootType = processRecordType ?? _rootGeneratedType(allRecords);
    for (final b in bindings) {
      if (b.matchType == record.type) return b;
    }
    for (final b in bindings) {
      if (_isLocationsTypeAlias(
        binding: b,
        record: record,
        generatedTypes: generatedTypes,
        rootType: rootType,
      )) {
        return b;
      }
    }
    return null;
  }

  /// Binding used for Apply / plan, including default child location bindings.
  ///
  /// When a child has no explicit binding, is not folded via `fromChildren`, and
  /// its parent maps to [CatalogKind.locations], synthesizes a locations
  /// binding (type `site` unless [record.type] is already a location type)
  /// with `parentId` link and name from `name` or `value`.
  GeneratorRecordBinding? bindingForApply(
    GeneratedRecord record, {
    required List<GeneratedRecord> allRecords,
    String? processRecordType,
  }) {
    final explicit = bindingFor(
      record,
      allRecords: allRecords,
      processRecordType: processRecordType,
    );
    if (explicit != null) return explicit;

    final folded = _foldedParentFields();
    final parentField = record.parentField;
    if (parentField != null && folded.contains(parentField)) {
      return null;
    }

    final parentId = record.parentId;
    if (parentId == null) return null;
    GeneratedRecord? parent;
    for (final r in allRecords) {
      if (r.id == parentId) {
        parent = r;
        break;
      }
    }
    if (parent == null) return null;

    final parentBinding = bindingFor(
      parent,
      allRecords: allRecords,
      processRecordType: processRecordType,
    );
    if (parentBinding == null || parentBinding.kind != CatalogKind.locations) {
      return null;
    }

    return _synthesizeChildLocationBinding(record);
  }

  Set<String> _foldedParentFields() {
    final out = <String>{};
    for (final b in bindings) {
      for (final f in b.fields) {
        final children = f.fromChildren;
        if (children != null) out.add(children.parentField);
      }
    }
    return out;
  }

  static GeneratorRecordBinding _synthesizeChildLocationBinding(
    GeneratedRecord record,
  ) {
    final nameFrom = _preferredNameFrom(record);
    final locationType = _isKnownLocationTypeName(record.type)
        ? record.type.trim().toLowerCase()
        : 'site';
    return GeneratorRecordBinding(
      matchType: record.type,
      kind: CatalogKind.locations,
      nameFrom: nameFrom,
      link: const GeneratorRecordLink(to: 'parentId'),
      fields: [
        GeneratorFieldMapping(to: 'name', from: nameFrom),
        GeneratorFieldMapping(to: 'type', literal: locationType),
      ],
    );
  }

  static String _preferredNameFrom(GeneratedRecord record) {
    final name = _stringify(record.fields['name'])?.trim();
    if (name != null && name.isNotEmpty) return 'name';
    final value = _stringify(record.fields['value'])?.trim();
    if (value != null && value.isNotEmpty) return 'value';
    if (record.fields.containsKey('value')) return 'value';
    return 'name';
  }

  static String? _rootGeneratedType(List<GeneratedRecord> allRecords) {
    for (final r in allRecords) {
      if (r.parentId == null) return r.type;
    }
    return allRecords.isEmpty ? null : allRecords.first.type;
  }

  static bool _isKnownLocationTypeName(String raw) {
    const names = {
      'plane',
      'continent',
      'nation',
      'region',
      'settlement',
      'city',
      'village',
      'tradingpost',
      'district',
      'site',
    };
    return names.contains(raw.trim().toLowerCase());
  }

  static bool _isLocationsTypeAlias({
    required GeneratorRecordBinding binding,
    required GeneratedRecord record,
    required Set<String> generatedTypes,
    required String? rootType,
  }) {
    if (binding.kind != CatalogKind.locations) return false;
    if (!_isKnownLocationTypeName(binding.matchType)) return false;
    // Only alias when nothing was generated under that type name.
    if (generatedTypes.contains(binding.matchType)) return false;
    if (record.parentId != null) return false;
    if (rootType == null || rootType.isEmpty) return false;
    return record.type == rootType;
  }

  factory GeneratorRecordMapping.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const GeneratorRecordMapping();
    }
    // Common mistake: pasting a single fields[] entry as the whole document.
    if (json.containsKey('to') &&
        (json.containsKey('from') ||
            json.containsKey('literal') ||
            json.containsKey('fromChildren')) &&
        !json.containsKey('bindings')) {
      throw FormatException(
        'Record mapping must wrap field rules in bindings. '
        'Expected { "version": 1, "bindings": [ { "matchType", "kind", '
        '"nameFrom", "fields": [ { "to", "from" } ] } ] }, '
        'not a bare { "to", "from" } field object.',
      );
    }
    final versionRaw = json['version'];
    final version = switch (versionRaw) {
      int v => v,
      num v => v.toInt(),
      String v => int.tryParse(v) ?? 1,
      _ => 1,
    };
    final bindingsRaw = json['bindings'];
    final bindings = <GeneratorRecordBinding>[];
    if (bindingsRaw is List) {
      for (final item in bindingsRaw) {
        if (item is Map) {
          bindings.add(
            GeneratorRecordBinding.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return GeneratorRecordMapping(version: version, bindings: bindings);
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'bindings': [for (final b in bindings) b.toJson()],
      };

  /// Returns a human-readable validation error, or null if OK.
  String? validate() {
    for (var i = 0; i < bindings.length; i++) {
      final err = bindings[i].validate(index: i);
      if (err != null) return err;
    }
    return null;
  }

  /// Builds catalog name + payload for one generated record.
  GeneratorMappedCreate buildCreate({
    required GeneratedRecord record,
    required List<GeneratedRecord> allRecords,
    Map<String, int> catalogIdByGenId = const {},
    int? rootParentCatalogId,
    String? processRecordType,
  }) {
    final binding = bindingForApply(
      record,
      allRecords: allRecords,
      processRecordType: processRecordType,
    );
    if (binding == null) {
      throw StateError('No binding for generated type "${record.type}"');
    }
    final children = [
      for (final r in allRecords)
        if (r.parentId == record.id) r,
    ];
    final payload = <String, dynamic>{};
    for (final field in binding.fields) {
      final value = field.resolve(
        record: record,
        children: children,
      );
      if (value == null) continue;
      payload[field.to] = value;
    }

    // When matchType is used as a catalog location-type alias, ensure type.
    if (binding.kind == CatalogKind.locations &&
        binding.matchType != record.type &&
        _isKnownLocationTypeName(binding.matchType)) {
      payload.putIfAbsent('type', () => binding.matchType);
    }

    final link = binding.link;
    if (link != null) {
      int? parentCatalogId;
      final genParent = record.parentId;
      if (genParent != null && catalogIdByGenId.containsKey(genParent)) {
        parentCatalogId = catalogIdByGenId[genParent];
      } else if (genParent == null && rootParentCatalogId != null) {
        parentCatalogId = rootParentCatalogId;
      }
      if (parentCatalogId != null) {
        payload[link.to] = parentCatalogId;
      }
    }

    final nameRaw = record.fields[binding.nameFrom];
    final name = _stringify(nameRaw)?.trim() ?? '';
    if (name.isEmpty) {
      throw FormatException(
        'Generated ${record.type} is missing name field "${binding.nameFrom}"',
      );
    }

    // Keep payload.name in sync when present on domain models.
    payload.putIfAbsent('name', () => name);

    return GeneratorMappedCreate(
      genId: record.id,
      kind: binding.kind,
      name: name,
      payload: payload,
      matchType: binding.matchType,
      linkField: link?.to,
    );
  }

  /// Whether Apply should prompt for an external parent for [root].
  bool needsExternalParent(
    GeneratedRecord? root, {
    List<GeneratedRecord> allRecords = const [],
    String? processRecordType,
  }) {
    if (root == null) return false;
    final records = allRecords.isEmpty ? [root] : allRecords;
    final binding = bindingFor(
      root,
      allRecords: records,
      processRecordType: processRecordType,
    );
    if (binding?.link == null) return false;
    return root.parentId == null;
  }

  /// Catalog kind to list when picking an external parent for [root].
  CatalogKind? externalParentPickerKind(
    GeneratedRecord? root, {
    List<GeneratedRecord> allRecords = const [],
    String? processRecordType,
  }) {
    if (root == null) return null;
    final records = allRecords.isEmpty ? [root] : allRecords;
    final binding = bindingFor(
      root,
      allRecords: records,
      processRecordType: processRecordType,
    );
    final link = binding?.link;
    if (link == null) return null;
    return parentPickerKind(link.to, binding!.kind);
  }

  /// Builds a create/skip plan for every generated record.
  List<GeneratorApplyPlanEntry> buildApplyPlan({
    required List<GeneratedRecord> records,
    String? processRecordType,
  }) {
    final byId = {for (final r in records) r.id: r};
    final foldedParentFields = <String>{};
    for (final b in bindings) {
      for (final f in b.fields) {
        final children = f.fromChildren;
        if (children != null) {
          foldedParentFields.add(children.parentField);
        }
      }
    }

    return [
      for (final record in records)
        _planEntryFor(
          record,
          allRecords: records,
          byId: byId,
          foldedParentFields: foldedParentFields,
          processRecordType: processRecordType,
        ),
    ];
  }

  GeneratorApplyPlanEntry _planEntryFor(
    GeneratedRecord record, {
    required List<GeneratedRecord> allRecords,
    required Map<String, GeneratedRecord> byId,
    required Set<String> foldedParentFields,
    String? processRecordType,
  }) {
    final explicit = bindingFor(
      record,
      allRecords: allRecords,
      processRecordType: processRecordType,
    );
    final binding = bindingForApply(
      record,
      allRecords: allRecords,
      processRecordType: processRecordType,
    );
    if (binding != null) {
      final nameRaw = record.fields[binding.nameFrom];
      final name = _stringify(nameRaw)?.trim();
      final missingName = name == null || name.isEmpty;
      final defaultChild = explicit == null;
      return GeneratorApplyPlanEntry(
        genId: record.id,
        fate: GeneratorApplyFate.willCreate,
        kind: binding.kind,
        name: missingName ? null : name,
        nameFrom: binding.nameFrom,
        detail: missingName
            ? 'Will create ${binding.kind.singularLabel} — missing '
                '"${binding.nameFrom}" (check fieldMap / nameFrom)'
            : defaultChild
                ? 'Will create ${binding.kind.singularLabel}: $name '
                    '(default child → site under parent)'
                : 'Will create ${binding.kind.singularLabel}: $name',
        missingNameFrom: missingName,
      );
    }

    final parentField = record.parentField;
    if (parentField != null && foldedParentFields.contains(parentField)) {
      final parent = record.parentId == null ? null : byId[record.parentId!];
      return GeneratorApplyPlanEntry(
        genId: record.id,
        fate: GeneratorApplyFate.skipped,
        detail: parent == null
            ? 'Skipped — folded into parent via fromChildren ($parentField)'
            : 'Skipped — folded into ${parent.type} via fromChildren '
                '($parentField)',
      );
    }

    return GeneratorApplyPlanEntry(
      genId: record.id,
      fate: GeneratorApplyFate.skipped,
      detail: 'Skipped — no binding for type "${record.type}"',
    );
  }

  /// Warns when bindings would fail nameFrom on sample records.
  List<String> nameFromWarnings({
    required List<GeneratedRecord> records,
    String? processRecordType,
  }) {
    final warnings = <String>[];
    for (final record in records) {
      final binding = bindingForApply(
        record,
        allRecords: records,
        processRecordType: processRecordType,
      );
      if (binding == null) continue;
      final name = _stringify(record.fields[binding.nameFrom])?.trim();
      if (name == null || name.isEmpty) {
        warnings.add(
          'Binding "${binding.matchType}" nameFrom "${binding.nameFrom}" '
          'is empty on a ${record.type} result '
          '(rollMany children often use "value" unless fieldMap renames it).',
        );
      }
    }
    return warnings.toSet().toList();
  }
}

enum GeneratorApplyFate { willCreate, skipped }

class GeneratorApplyPlanEntry {
  const GeneratorApplyPlanEntry({
    required this.genId,
    required this.fate,
    required this.detail,
    this.kind,
    this.name,
    this.nameFrom,
    this.missingNameFrom = false,
  });

  final String genId;
  final GeneratorApplyFate fate;
  final CatalogKind? kind;
  final String? name;

  /// Generated field key used as the catalog name ([GeneratorRecordBinding.nameFrom]).
  final String? nameFrom;
  final String detail;
  final bool missingNameFrom;

  bool get willCreate => fate == GeneratorApplyFate.willCreate;
}

class GeneratorRecordBinding {
  const GeneratorRecordBinding({
    required this.matchType,
    required this.kind,
    required this.nameFrom,
    required this.fields,
    this.link,
  });

  final String matchType;
  final CatalogKind kind;
  final String nameFrom;
  final GeneratorRecordLink? link;
  final List<GeneratorFieldMapping> fields;

  factory GeneratorRecordBinding.fromJson(Map<String, dynamic> json) {
    final matchType = '${json['matchType'] ?? ''}'.trim();
    final kindRaw = '${json['kind'] ?? ''}'.trim();
    final kind = CatalogKind.tryParseApiValue(kindRaw);
    if (kind == null) {
      throw FormatException('Unknown catalog kind "$kindRaw"');
    }
    final nameFrom = '${json['nameFrom'] ?? ''}'.trim();
    final linkRaw = json['link'];
    GeneratorRecordLink? link;
    if (linkRaw is Map) {
      link = GeneratorRecordLink.fromJson(Map<String, dynamic>.from(linkRaw));
    }
    final fieldsRaw = json['fields'];
    final fields = <GeneratorFieldMapping>[];
    if (fieldsRaw is List) {
      for (final item in fieldsRaw) {
        if (item is Map) {
          fields.add(
            GeneratorFieldMapping.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return GeneratorRecordBinding(
      matchType: matchType,
      kind: kind,
      nameFrom: nameFrom,
      link: link,
      fields: fields,
    );
  }

  Map<String, dynamic> toJson() => {
        'matchType': matchType,
        'kind': kind.apiValue,
        'nameFrom': nameFrom,
        'link': link?.toJson(),
        'fields': [for (final f in fields) f.toJson()],
      };

  String? validate({required int index}) {
    if (matchType.isEmpty) {
      return 'Binding $index: matchType is required';
    }
    if (nameFrom.isEmpty) {
      return 'Binding "$matchType": nameFrom is required';
    }
    for (var i = 0; i < fields.length; i++) {
      final err = fields[i].validate(binding: matchType, index: i);
      if (err != null) return err;
    }
    return null;
  }
}

class GeneratorRecordLink {
  const GeneratorRecordLink({required this.to});

  final String to;

  factory GeneratorRecordLink.fromJson(Map<String, dynamic> json) {
    final to = '${json['to'] ?? ''}'.trim();
    if (to.isEmpty) {
      throw FormatException('link.to is required');
    }
    return GeneratorRecordLink(to: to);
  }

  Map<String, dynamic> toJson() => {'to': to};
}

class GeneratorFieldMapping {
  const GeneratorFieldMapping({
    required this.to,
    this.from,
    this.fromList,
    this.literal,
    this.fromChildren,
    this.join = '\n',
  });

  final String to;
  final String? from;
  final List<String>? fromList;
  final Object? literal;
  final GeneratorChildrenConcat? fromChildren;
  final String join;

  factory GeneratorFieldMapping.fromJson(Map<String, dynamic> json) {
    final to = '${json['to'] ?? ''}'.trim();
    if (to.isEmpty) {
      throw FormatException('fields[].to is required');
    }
    final join = json['join'] is String ? json['join'] as String : '\n';
    GeneratorChildrenConcat? fromChildren;
    final childrenRaw = json['fromChildren'];
    if (childrenRaw is Map) {
      fromChildren = GeneratorChildrenConcat.fromJson(
        Map<String, dynamic>.from(childrenRaw),
      );
    }

    String? from;
    List<String>? fromList;
    final fromRaw = json['from'];
    if (fromRaw is String) {
      from = fromRaw.trim();
    } else if (fromRaw is List) {
      fromList = [
        for (final item in fromRaw)
          if ('$item'.trim().isNotEmpty) '$item'.trim(),
      ];
    }

    return GeneratorFieldMapping(
      to: to,
      from: from,
      fromList: fromList,
      literal: json.containsKey('literal') ? json['literal'] : null,
      fromChildren: fromChildren,
      join: join,
    );
  }

  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{'to': to};
    if (literal != null) {
      out['literal'] = literal;
    } else if (fromChildren != null) {
      out['fromChildren'] = fromChildren!.toJson();
      out['join'] = join;
    } else if (fromList != null) {
      out['from'] = fromList;
      out['join'] = join;
    } else if (from != null) {
      out['from'] = from;
    }
    return out;
  }

  String? validate({required String binding, required int index}) {
    final modes = [
      if (from != null || fromList != null) 'from',
      if (literal != null) 'literal',
      if (fromChildren != null) 'fromChildren',
    ];
    if (modes.isEmpty) {
      return 'Binding "$binding" field $index: need from, literal, or fromChildren';
    }
    if (modes.length > 1) {
      return 'Binding "$binding" field $index: use only one of from, literal, fromChildren';
    }
    return null;
  }

  Object? resolve({
    required GeneratedRecord record,
    required List<GeneratedRecord> children,
  }) {
    if (literal != null) return literal;
    if (fromChildren != null) {
      return fromChildren!.resolve(children: children, join: join);
    }
    if (fromList != null) {
      final parts = <String>[];
      for (final key in fromList!) {
        final part = _stringify(record.fields[key]);
        if (part != null && part.trim().isNotEmpty) parts.add(part.trim());
      }
      if (parts.isEmpty) return null;
      return parts.join(join);
    }
    if (from != null) {
      return _valueOrNull(record.fields[from]);
    }
    return null;
  }
}

class GeneratorChildrenConcat {
  const GeneratorChildrenConcat({
    required this.parentField,
    required this.from,
  });

  final String parentField;
  final String from;

  factory GeneratorChildrenConcat.fromJson(Map<String, dynamic> json) {
    final parentField = '${json['parentField'] ?? ''}'.trim();
    final from = '${json['from'] ?? ''}'.trim();
    if (parentField.isEmpty || from.isEmpty) {
      throw FormatException(
        'fromChildren requires parentField and from',
      );
    }
    return GeneratorChildrenConcat(parentField: parentField, from: from);
  }

  Map<String, dynamic> toJson() => {
        'parentField': parentField,
        'from': from,
      };

  String? resolve({
    required List<GeneratedRecord> children,
    required String join,
  }) {
    final parts = <String>[];
    for (final child in children) {
      if (child.parentField != parentField) continue;
      final part = _stringify(child.fields[from]);
      if (part != null && part.trim().isNotEmpty) parts.add(part.trim());
    }
    if (parts.isEmpty) return null;
    return parts.join(join);
  }
}

class GeneratorMappedCreate {
  const GeneratorMappedCreate({
    required this.genId,
    required this.kind,
    required this.name,
    required this.payload,
    required this.matchType,
    this.linkField,
  });

  final String genId;
  final CatalogKind kind;
  final String name;
  final Map<String, dynamic> payload;
  final String matchType;
  final String? linkField;
}

/// Catalog kind to browse when picking a value for [linkField].
CatalogKind parentPickerKind(String linkField, CatalogKind childKind) {
  return switch (linkField) {
    'campaignId' => CatalogKind.campaigns,
    'parentClassId' => CatalogKind.classes,
    'raceId' => CatalogKind.races,
    'parentRuleId' => CatalogKind.rules,
    'parentCreatureTypeId' => CatalogKind.creatureTypes,
    _ => childKind,
  };
}

/// Parent-first order among [records] that have bindings; skips unmapped.
List<GeneratedRecord> recordsToApplyInOrder({
  required List<GeneratedRecord> records,
  required GeneratorRecordMapping mapping,
  String? processRecordType,
}) {
  final selected = [
    for (final r in records)
      if (mapping.bindingForApply(
            r,
            allRecords: records,
            processRecordType: processRecordType,
          ) !=
          null)
        r,
  ];
  final byId = {for (final r in selected) r.id: r};
  final remaining = selected.map((r) => r.id).toSet();
  final ordered = <GeneratedRecord>[];

  while (remaining.isNotEmpty) {
    final ready = <String>[];
    for (final id in remaining) {
      final r = byId[id]!;
      final parent = r.parentId;
      if (parent == null ||
          !byId.containsKey(parent) ||
          !remaining.contains(parent)) {
        ready.add(id);
      }
    }
    if (ready.isEmpty) {
      // Cycle or orphaned parent among selected — append rest in input order.
      for (final id in remaining) {
        ordered.add(byId[id]!);
      }
      break;
    }
    ready.sort();
    for (final id in ready) {
      ordered.add(byId[id]!);
      remaining.remove(id);
    }
  }
  return ordered;
}

Object? _valueOrNull(Object? value) {
  if (value == null) return null;
  if (value is String && value.trim().isEmpty) return null;
  return value;
}

String? _stringify(Object? value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return '$value';
  if (value is List) {
    return value.map(_stringify).whereType<String>().join(', ');
  }
  return value.toString();
}
