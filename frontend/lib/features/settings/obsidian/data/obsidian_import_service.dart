import 'dart:io';

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
  });

  final CatalogItem item;
  final String name;
  final CatalogKind kind;
}

/// Imports a single Obsidian note (with RPG Manager frontmatter) into the DB.
class ObsidianImportService {
  ObsidianImportService({
    CatalogApi? api,
    ObsidianNoteMapper? mapper,
  })  : _api = api ?? CatalogApi(),
        _mapper = mapper ?? ObsidianNoteMapper();

  final CatalogApi _api;
  final ObsidianNoteMapper _mapper;

  /// Reads [absolutePath], merges frontmatter + sections into payload, PATCHes.
  Future<ObsidianImportResult> importFile({
    required String accessToken,
    required String absolutePath,
  }) async {
    final file = File(absolutePath);
    if (!file.existsSync()) {
      throw StateError('File does not exist');
    }
    if (!absolutePath.toLowerCase().endsWith('.md')) {
      throw StateError('Choose a Markdown (.md) note');
    }

    final contents = await file.readAsString();
    final parsed = parseObsidianNote(contents);
    if (parsed == null) {
      throw StateError(
        'Not an RPG Manager note (missing rpg_manager_id / rpg_manager_kind)',
      );
    }
    if (parsed.kind == CatalogKind.generators) {
      throw StateError('Generators cannot be imported from Obsidian');
    }

    final existing = await _api.get(accessToken, parsed.kind, parsed.id);
    final linkMap = await _buildReverseLinkMap(accessToken);
    final fieldMap = obsidianFieldMapFor(parsed.kind);

    String rewrite(String text) => rewriteWikiLinksFromObsidian(
          text,
          targetsByWikiPath: linkMap.byPath,
          idsByKindName: linkMap.idsByKindName,
        );

    final payload = Map<String, dynamic>.from(existing.payload ?? const {});

    // 1) Overlay non-system frontmatter onto payload.
    for (final entry in parsed.frontmatter.entries) {
      if (obsidianSystemFrontmatterKeys.contains(entry.key)) continue;
      payload[entry.key] = _normalizeYamlValue(entry.value);
    }

    // 2) Overlay ## sections onto markdown keys (only when present).
    final body = parsed.parsedBody;
    for (final entry in body.sections.entries) {
      final key = markdownFieldKeyForTitle(fieldMap, entry.key);
      if (key == null) continue;
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

    // 3) Nested prose blocks (only when those ## parents exist).
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

    // Spells: if Description section present but higher-levels section absent,
    // keep existing higherLevels.description (sections overlay is additive).

    final name = parsed.name?.trim();
    final updated = await _api.update(
      accessToken: accessToken,
      kind: parsed.kind,
      itemId: parsed.id,
      name: (name != null && name.isNotEmpty && name != existing.name)
          ? name
          : null,
      payload: payload,
    );

    return ObsidianImportResult(
      item: updated,
      name: updated.name,
      kind: parsed.kind,
    );
  }

  Future<({
    Map<String, ({String kind, int id})> byPath,
    Map<String, int> idsByKindName,
  })> _buildReverseLinkMap(
    String accessToken,
  ) async {
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
