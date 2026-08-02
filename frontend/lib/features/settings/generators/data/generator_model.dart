import 'dart:convert';

import 'package:random_table_engine/generation_engine.dart';

import 'generator_applies_to.dart';
import 'generator_record_mapping.dart';

/// Catalog payload for a Settings → Generator record.
///
/// Holds tables, process, and optional [recordMapping] for Apply-to-catalog.
/// Running the generator still produces a preview; persistence happens only
/// when the user applies results using [recordMapping].
class GeneratorRecord {
  const GeneratorRecord({
    required this.name,
    required this.tablesDocument,
    required this.processDocument,
    this.recordMappingDocument,
    this.appliesTo,
  });

  final String name;

  /// Full tables JSON: `{ "tables": { ... } }`.
  final Map<String, dynamic> tablesDocument;

  /// Process JSON: `{ "recordType": "...", "steps": [...] }`.
  final Map<String, dynamic> processDocument;

  /// Sidecar mapping JSON: `{ "version": 1, "bindings": [...] }`.
  final Map<String, dynamic>? recordMappingDocument;

  /// When set, this generator is offered on create FABs for [appliesTo.kind].
  final GeneratorAppliesTo? appliesTo;

  static Map<String, dynamic> get emptyTablesDocument => {
        'tables': <String, dynamic>{},
      };

  static Map<String, dynamic> get emptyProcessDocument => {
        'recordType': 'result',
        'steps': <dynamic>[],
      };

  static Map<String, dynamic> get emptyRecordMappingDocument =>
      GeneratorRecordMapping.emptyDocument;

  /// Parsed mapping, or empty bindings when document is null/empty.
  ///
  /// Throws [FormatException] when the document is present but invalid.
  GeneratorRecordMapping get recordMapping {
    final raw = recordMappingDocument;
    if (raw == null || raw.isEmpty) {
      return const GeneratorRecordMapping();
    }
    return GeneratorRecordMapping.fromJson(raw);
  }

  /// Non-null when [recordMappingDocument] exists but fails to parse/validate.
  String? get recordMappingError {
    final raw = recordMappingDocument;
    if (raw == null || raw.isEmpty) return null;
    try {
      final mapping = GeneratorRecordMapping.fromJson(raw);
      return mapping.validate();
    } catch (e) {
      return '$e';
    }
  }

  /// Safe mapping for UI that must not throw (empty on error).
  GeneratorRecordMapping get recordMappingOrEmpty {
    try {
      return recordMapping;
    } catch (_) {
      return const GeneratorRecordMapping();
    }
  }

  factory GeneratorRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return GeneratorRecord(
        name: name,
        tablesDocument: emptyTablesDocument,
        processDocument: emptyProcessDocument,
        recordMappingDocument: emptyRecordMappingDocument,
      );
    }
    final tablesRaw = payload['tablesDocument'];
    final processRaw = payload['processDocument'];
    final mappingRaw = payload['recordMapping'];
    GeneratorAppliesTo? appliesTo;
    try {
      appliesTo = GeneratorAppliesTo.tryParse(payload['appliesTo']);
    } catch (_) {
      appliesTo = null;
    }
    return GeneratorRecord(
      name: payload['name'] as String? ?? name,
      tablesDocument: tablesRaw is Map
          ? Map<String, dynamic>.from(tablesRaw)
          : emptyTablesDocument,
      processDocument: processRaw is Map
          ? Map<String, dynamic>.from(processRaw)
          : emptyProcessDocument,
      recordMappingDocument: mappingRaw is Map
          ? Map<String, dynamic>.from(mappingRaw)
          : emptyRecordMappingDocument,
      appliesTo: appliesTo,
    );
  }

  Map<String, dynamic> toJson() {
    final out = <String, dynamic>{
      'name': name,
      'tablesDocument': tablesDocument,
      'processDocument': processDocument,
      'recordMapping': recordMappingDocument ?? emptyRecordMappingDocument,
    };
    final target = appliesTo;
    if (target != null) {
      out['appliesTo'] = target.toJson();
    }
    return out;
  }

  String get recordTypeLabel {
    final type = processDocument['recordType'];
    if (type is String && type.trim().isNotEmpty) return type.trim();
    return 'result';
  }

  /// Validates config and returns a human-readable error, or null if OK.
  String? validateConfig() {
    late final TableRegistry registry;
    try {
      registry = TableRegistry.fromJson(tablesDocument);
    } catch (e) {
      return 'Tables config: $e';
    }
    late final GenerationProcess process;
    try {
      process = GenerationProcess.fromJson(processDocument);
    } catch (e) {
      return 'Process config: $e';
    }
    final processErrors = process.validate(registry);
    if (processErrors.isNotEmpty) {
      return 'Process config:\n- ${processErrors.join('\n- ')}';
    }
    try {
      final mapping = GeneratorRecordMapping.fromJson(recordMappingDocument);
      final mappingError = mapping.validate();
      if (mappingError != null) return mappingError;
    } catch (e) {
      return 'Record mapping: $e';
    }
    final targetError = appliesTo?.validate();
    if (targetError != null) return 'Applies to: $targetError';
    return null;
  }

  /// If [decoded] is a full generator payload, returns its appliesTo.
  static GeneratorAppliesTo? appliesToFromPayload(
    Map<String, dynamic> decoded,
  ) {
    try {
      return GeneratorAppliesTo.tryParse(decoded['appliesTo']);
    } catch (_) {
      return null;
    }
  }

  /// Soft warnings for Apply (does not block Generate).
  List<String> applyWarnings({
    List<GeneratedRecord>? sampleRecords,
  }) {
    final mappingError = recordMappingError;
    if (mappingError != null) return ['Record mapping: $mappingError'];
    final mapping = recordMappingOrEmpty;
    if (!mapping.hasBindings) return const [];
    if (sampleRecords == null) return const [];
    return mapping.nameFromWarnings(
      records: sampleRecords,
      processRecordType: recordTypeLabel,
    );
  }

  /// Normalizes pasted Tables JSON into the engine tables document shape.
  ///
  /// Accepts:
  /// - `{ "tables": { … } }` (canonical)
  /// - full catalog payload with `tablesDocument`
  /// - bare `{ "origin": {…}, … }` table id map
  static Map<String, dynamic> normalizeTablesDocument(
    Map<String, dynamic> decoded,
  ) {
    final nested = decoded['tablesDocument'];
    if (nested is Map) {
      return normalizeTablesDocument(Map<String, dynamic>.from(nested));
    }
    if (decoded['tables'] is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    final looksLikeBareTableMap = decoded.isNotEmpty &&
        decoded.values.every(
          (v) =>
              v is Map &&
              (v['type'] == 'random' ||
                  v['type'] == 'lookup' ||
                  v.containsKey('entries') ||
                  v.containsKey('dice')),
        );
    if (looksLikeBareTableMap) {
      return {'tables': Map<String, dynamic>.from(decoded)};
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// If [decoded] is a full generator payload, returns its process document.
  static Map<String, dynamic>? processDocumentFromPayload(
    Map<String, dynamic> decoded,
  ) {
    final process = decoded['processDocument'];
    if (process is Map) {
      return Map<String, dynamic>.from(process);
    }
    return null;
  }

  /// If [decoded] is a full generator payload, returns its record mapping.
  static Map<String, dynamic>? recordMappingFromPayload(
    Map<String, dynamic> decoded,
  ) {
    final mapping = decoded['recordMapping'];
    if (mapping is Map) {
      return Map<String, dynamic>.from(mapping);
    }
    return null;
  }

  /// If [decoded] is a full generator payload, returns its name.
  static String? nameFromPayload(Map<String, dynamic> decoded) {
    final name = decoded['name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
    return null;
  }

  /// Runs the generator and returns preview records (not persisted).
  List<GeneratedRecord> runPreview({
    Roller? roller,
    IdGenerator? idGenerator,
    GenerationOverrides? overrides,
    Map<String, dynamic>? fieldOverrides,
  }) {
    final error = validateConfig();
    if (error != null) {
      throw FormatException(error);
    }
    final registry = TableRegistry.fromJson(tablesDocument);
    final process = GenerationProcess.fromJson(processDocument);
    final records = ProcessRunner(
      registry: registry,
      roller: roller ?? RandomRoller(),
      idGenerator: idGenerator ?? UuidIdGenerator(),
    ).run(
      process,
      generationOverrides: overrides,
      overrides: fieldOverrides,
    );
    _applyManualNamePin(records, overrides, fieldOverrides);
    return records;
  }

  /// Pins a root `name` when the process has no name step (manual input only).
  static void _applyManualNamePin(
    List<GeneratedRecord> records,
    GenerationOverrides? overrides,
    Map<String, dynamic>? fieldOverrides,
  ) {
    if (records.isEmpty) return;
    final pinned = overrides?.fields['name'] ?? fieldOverrides?['name'];
    if (pinned == null) return;
    final text = '$pinned'.trim();
    if (text.isEmpty) return;
    GeneratedRecord root = records.first;
    for (final r in records) {
      if (r.parentId == null) {
        root = r;
        break;
      }
    }
    final existing = root.fields['name'];
    if (existing != null && '$existing'.trim().isNotEmpty) return;
    root.fields['name'] = text;
  }

  static String encodePretty(Map<String, dynamic> document) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(document);
  }

  static Map<String, dynamic> decodeObject(String raw, String label) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw FormatException('$label JSON is empty');
    }
    final decoded = jsonDecode(trimmed);
    if (decoded is! Map) {
      throw FormatException('$label must be a JSON object');
    }
    return Map<String, dynamic>.from(decoded);
  }
}
