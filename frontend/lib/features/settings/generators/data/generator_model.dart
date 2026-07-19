import 'dart:convert';

import 'package:random_table_engine/generation_engine.dart';

/// Catalog payload for a Settings → Generator record.
///
/// Holds the table registry document and process spec used by
/// [random_table_engine]. Running the generator produces a preview only —
/// it does not persist generated world records.
class GeneratorRecord {
  const GeneratorRecord({
    required this.name,
    required this.tablesDocument,
    required this.processDocument,
  });

  final String name;

  /// Full tables JSON: `{ "tables": { ... } }`.
  final Map<String, dynamic> tablesDocument;

  /// Process JSON: `{ "recordType": "...", "steps": [...] }`.
  final Map<String, dynamic> processDocument;

  static Map<String, dynamic> get emptyTablesDocument => {
        'tables': <String, dynamic>{},
      };

  static Map<String, dynamic> get emptyProcessDocument => {
        'recordType': 'result',
        'steps': <dynamic>[],
      };

  factory GeneratorRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return GeneratorRecord(
        name: name,
        tablesDocument: emptyTablesDocument,
        processDocument: emptyProcessDocument,
      );
    }
    final tablesRaw = payload['tablesDocument'];
    final processRaw = payload['processDocument'];
    return GeneratorRecord(
      name: payload['name'] as String? ?? name,
      tablesDocument: tablesRaw is Map
          ? Map<String, dynamic>.from(tablesRaw)
          : emptyTablesDocument,
      processDocument: processRaw is Map
          ? Map<String, dynamic>.from(processRaw)
          : emptyProcessDocument,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'tablesDocument': tablesDocument,
        'processDocument': processDocument,
      };

  String get recordTypeLabel {
    final type = processDocument['recordType'];
    if (type is String && type.trim().isNotEmpty) return type.trim();
    return 'result';
  }

  /// Validates config and returns a human-readable error, or null if OK.
  String? validateConfig() {
    try {
      TableRegistry.fromJson(tablesDocument);
    } catch (e) {
      return 'Tables config: $e';
    }
    try {
      GenerationProcess.fromJson(processDocument);
    } catch (e) {
      return 'Process config: $e';
    }
    return null;
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
  }) {
    final error = validateConfig();
    if (error != null) {
      throw FormatException(error);
    }
    final registry = TableRegistry.fromJson(tablesDocument);
    final process = GenerationProcess.fromJson(processDocument);
    return ProcessRunner(
      registry: registry,
      roller: roller ?? RandomRoller(),
      idGenerator: idGenerator ?? UuidIdGenerator(),
    ).run(process);
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
