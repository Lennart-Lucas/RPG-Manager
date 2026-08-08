import 'dart:io';

import '../../../auth/data/auth_api.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import 'obsidian_field_map.dart';
import 'obsidian_note_mapper.dart';
import 'obsidian_note_parser.dart';

class ObsidianImportResult {
  const ObsidianImportResult({
    required this.item,
    required this.name,
    required this.kind,
    this.created = false,
  });

  final CatalogItem item;
  final String name;
  final CatalogKind kind;
  final bool created;
}

class ObsidianImportFileOutcome {
  const ObsidianImportFileOutcome({
    required this.path,
    this.result,
    this.error,
  });

  final String path;
  final ObsidianImportResult? result;
  final String? error;

  bool get ok => error == null && result != null;
}

class ObsidianImportBatchResult {
  const ObsidianImportBatchResult({required this.outcomes});

  final List<ObsidianImportFileOutcome> outcomes;

  int get successCount => outcomes.where((o) => o.ok).length;
  int get createdCount =>
      outcomes.where((o) => o.result?.created == true).length;
  int get updatedCount =>
      outcomes.where((o) => o.result != null && !o.result!.created).length;
  int get failureCount => outcomes.where((o) => !o.ok).length;

  String get summary => summarizeObsidianImportBatch(this);
}

/// Short user-facing summary for a batch import.
String summarizeObsidianImportBatch(ObsidianImportBatchResult batch) {
  final ok = batch.successCount;
  final failed = batch.failureCount;
  if (ok == 0 && failed == 0) return 'No notes imported';
  if (ok == 0) {
    final errors =
        batch.outcomes.map((o) => o.error).whereType<String>().toList();
    final first = errors.isEmpty ? null : errors.first;
    return first == null ? 'Import failed' : 'Import failed: $first';
  }
  final parts = <String>[
    'Imported $ok',
    if (batch.updatedCount > 0 || batch.createdCount > 0)
      '(${batch.updatedCount} updated, ${batch.createdCount} created)',
  ];
  var summary = parts.join(' ');
  if (failed > 0) {
    final errors =
        batch.outcomes.map((o) => o.error).whereType<String>().toList();
    final first = errors.isEmpty ? null : errors.first;
    summary += first == null
        ? '; $failed failed'
        : '; $failed failed ($first)';
  }
  return summary;
}

typedef ObsidianLinkMap = ({
  Map<String, ({String kind, int id})> byPath,
  Map<String, int> idsByKindName,
});

/// Imports Obsidian notes into the catalog (create or update).
class ObsidianImportService {
  ObsidianImportService({
    CatalogApi? api,
    ObsidianNoteMapper? mapper,
  })  : _api = api ?? CatalogApi(),
        _mapper = mapper ?? ObsidianNoteMapper();

  final CatalogApi _api;
  final ObsidianNoteMapper _mapper;

  /// Reads [absolutePath] and creates or updates the matching catalog record.
  Future<ObsidianImportResult> importFile({
    required String accessToken,
    required String absolutePath,
    ObsidianLinkMap? linkMap,
  }) async {
    final file = File(absolutePath);
    if (!file.existsSync()) {
      throw StateError('File does not exist');
    }
    if (!absolutePath.toLowerCase().endsWith('.md')) {
      throw StateError('Choose a Markdown (.md) note');
    }

    final kindHint = ObsidianNoteMapper.inferKindFromVaultPath(absolutePath);
    final contents = await file.readAsString();
    final parsed = parseObsidianNote(contents, kindHint: kindHint);
    if (parsed == null) {
      throw StateError(
        'Could not determine record type '
        '(set rpg_manager_kind or place the note under RPG Manager/<Kind>/)',
      );
    }
    if (parsed.kind == CatalogKind.generators) {
      throw StateError('Generators cannot be imported from Obsidian');
    }

    final resolvedLinkMap = linkMap ?? await _buildReverseLinkMap(accessToken);
    String rewrite(String text) => rewriteWikiLinksFromObsidian(
          text,
          targetsByWikiPath: resolvedLinkMap.byPath,
          idsByKindName: resolvedLinkMap.idsByKindName,
        );

    final recordName = () {
      final fromFm = parsed.name?.trim();
      if (fromFm != null && fromFm.isNotEmpty) return fromFm;
      return ObsidianNoteMapper.nameFromFilePath(absolutePath);
    }();

    CatalogItem? existing;
    final id = parsed.id;
    if (id != null) {
      try {
        existing = await _api.get(accessToken, parsed.kind, id);
      } on AuthApiException catch (e) {
        if (e.statusCode != 404) rethrow;
        existing = null;
      }
    }

    if (existing != null) {
      final payload = _buildPayload(
        base: Map<String, dynamic>.from(existing.payload ?? const {}),
        parsed: parsed,
        rewrite: rewrite,
      );
      final updated = await _api.update(
        accessToken: accessToken,
        kind: parsed.kind,
        itemId: existing.id,
        name: recordName != existing.name ? recordName : null,
        payload: payload,
      );
      return ObsidianImportResult(
        item: updated,
        name: updated.name,
        kind: parsed.kind,
        created: false,
      );
    }

    final payload = _buildPayload(
      base: <String, dynamic>{},
      parsed: parsed,
      rewrite: rewrite,
    );
    final created = await _api.create(
      accessToken: accessToken,
      kind: parsed.kind,
      name: recordName,
      payload: payload,
    );

    final rewritten = writeObsidianSystemFrontmatter(
      contents,
      id: created.id,
      kind: parsed.kind,
      name: created.name,
    );
    await file.writeAsString(rewritten);

    return ObsidianImportResult(
      item: created,
      name: created.name,
      kind: parsed.kind,
      created: true,
    );
  }

  /// Imports many notes, building the wiki link map once.
  Future<ObsidianImportBatchResult> importFiles({
    required String accessToken,
    required List<String> absolutePaths,
  }) async {
    final linkMap = await _buildReverseLinkMap(accessToken);
    final outcomes = <ObsidianImportFileOutcome>[];
    for (final path in absolutePaths) {
      try {
        final result = await importFile(
          accessToken: accessToken,
          absolutePath: path,
          linkMap: linkMap,
        );
        outcomes.add(ObsidianImportFileOutcome(path: path, result: result));
      } catch (e) {
        final message = e is AuthApiException
            ? e.message
            : e is StateError
                ? e.message
                : '$e';
        outcomes.add(ObsidianImportFileOutcome(path: path, error: message));
      }
    }
    return ObsidianImportBatchResult(outcomes: outcomes);
  }

  Map<String, dynamic> _buildPayload({
    required Map<String, dynamic> base,
    required ParsedObsidianNote parsed,
    required String Function(String) rewrite,
  }) {
    final payload = Map<String, dynamic>.from(base);
    final fieldMap = obsidianFieldMapFor(parsed.kind);

    for (final entry in parsed.frontmatter.entries) {
      if (obsidianSystemFrontmatterKeys.contains(entry.key)) continue;
      payload[entry.key] = _normalizeYamlValue(entry.value);
    }

    final body = parsed.parsedBody;
    final hasDescriptionField =
        fieldMap.markdownPayloadKeys.contains('description');
    final unmappedForDescription = <({String title, String body})>[];
    for (final entry in body.sections.entries) {
      final key = markdownFieldKeyForTitle(fieldMap, entry.key);
      if (key == null) {
        // Custom ## headings (not Founding/Motto/etc.) stay in description.
        if (hasDescriptionField &&
            entry.key.toLowerCase() != 'description') {
          unmappedForDescription.add((title: entry.key, body: entry.value));
        }
        continue;
      }
      final text = rewrite(entry.value);
      if (key == '__higherLevels.description__') {
        final higher = payload['higherLevels'];
        final map = higher is Map
            ? Map<String, dynamic>.from(higher)
            : <String, dynamic>{};
        map['description'] = text;
        payload['higherLevels'] = map;
      } else {
        payload[key] = text;
      }
    }

    if (unmappedForDescription.isNotEmpty) {
      final buffer = StringBuffer();
      final existing = '${payload['description'] ?? ''}'.trim();
      if (existing.isNotEmpty) {
        buffer.writeln(existing);
        buffer.writeln();
      }
      for (final chunk in unmappedForDescription) {
        buffer.writeln('## ${chunk.title}');
        buffer.writeln();
        buffer.writeln(rewrite(chunk.body).trimRight());
        buffer.writeln();
      }
      payload['description'] = buffer.toString().trimRight();
    }

    if (body.featuresByLevel != null) {
      payload['featuresByLevel'] = _rewriteNestedStrings(
        body.featuresByLevel!,
        rewrite,
        stringKeys: const {'description'},
      );
    }
    if (body.namedFeatures != null) {
      payload['features'] = [
        for (final f in body.namedFeatures!)
          _rewriteMapStrings(f, rewrite, stringKeys: const {'description'}),
      ];
    }
    if (body.typeSections != null) {
      payload['sections'] = [
        for (final s in body.typeSections!)
          _rewriteMapStrings(s, rewrite, stringKeys: const {'contents'}),
      ];
    }
    if (body.typeTraits != null) {
      payload['traits'] = [
        for (final t in body.typeTraits!)
          _rewriteMapStrings(t, rewrite, stringKeys: const {'description'}),
      ];
    }
    if (body.creatureFeatures != null) {
      payload['features'] = [
        for (final f in body.creatureFeatures!)
          _rewriteMapStrings(
            f,
            rewrite,
            stringKeys: const {'text', 'snapshotText'},
          ),
      ];
    }

    return payload;
  }

  Future<ObsidianLinkMap> _buildReverseLinkMap(String accessToken) async {
    final itemsByKind = <CatalogKind, List<CatalogItem>>{};
    for (final kind in ObsidianNoteMapper.exportKinds) {
      itemsByKind[kind] = await _api.list(accessToken, kind);
    }
    final notes = _mapper.planAll(itemsByKind);
    final byPath = <String, ({String kind, int id})>{};
    final idsByKindName = <String, int>{};
    final ambiguousBases = <String>{};
    for (final note in notes) {
      final target = note.wikiTarget.toLowerCase();
      final value = (kind: note.item.kind.apiValue, id: note.item.id);
      byPath[target] = value;
      idsByKindName[
          '${note.item.kind.apiValue.toLowerCase()}\u0000${note.item.name.toLowerCase()}'] =
          note.item.id;
      final aliases = note.item.payload?['aliases'];
      if (aliases is List) {
        for (final alias in aliases) {
          final text = '$alias'.trim().toLowerCase();
          if (text.isEmpty) continue;
          idsByKindName.putIfAbsent(
            '${note.item.kind.apiValue.toLowerCase()}\u0000$text',
            () => note.item.id,
          );
        }
      }
      final base = target.contains('/')
          ? target.substring(target.lastIndexOf('/') + 1)
          : target;
      if (ambiguousBases.contains(base)) continue;
      final prior = byPath[base];
      if (prior == null) {
        byPath[base] = value;
      } else if (prior.kind != value.kind || prior.id != value.id) {
        byPath.remove(base);
        ambiguousBases.add(base);
      }
    }
    return (byPath: byPath, idsByKindName: idsByKindName);
  }

  dynamic _normalizeYamlValue(dynamic value) {
    if (value is Map) {
      return <String, dynamic>{
        for (final e in value.entries)
          '${e.key}': _normalizeYamlValue(e.value),
      };
    }
    if (value is List) {
      return [for (final e in value) _normalizeYamlValue(e)];
    }
    return value;
  }

  Map<String, dynamic> _rewriteNestedStrings(
    Map<String, dynamic> root,
    String Function(String) rewrite, {
    required Set<String> stringKeys,
  }) {
    final out = <String, dynamic>{};
    for (final entry in root.entries) {
      final v = entry.value;
      if (v is List) {
        out[entry.key] = [
          for (final item in v)
            if (item is Map)
              _rewriteMapStrings(
                Map<String, dynamic>.from(item),
                rewrite,
                stringKeys: stringKeys,
              )
            else
              item,
        ];
      } else {
        out[entry.key] = v;
      }
    }
    return out;
  }

  Map<String, dynamic> _rewriteMapStrings(
    Map<String, dynamic> map,
    String Function(String) rewrite, {
    required Set<String> stringKeys,
  }) {
    final out = Map<String, dynamic>.from(map);
    for (final key in stringKeys) {
      final v = out[key];
      if (v is String) out[key] = rewrite(v);
    }
    return out;
  }
}
