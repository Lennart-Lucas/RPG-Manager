import 'dart:io';

import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
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

  /// Reads [absolutePath], maps body → primary payload field, PATCHes the record.
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
    final linkTargets = await _buildReverseLinkMap(accessToken);
    final body = rewriteWikiLinksFromObsidian(
      parsed.body,
      targetsByWikiPath: linkTargets,
    );

    final payload = Map<String, dynamic>.from(existing.payload ?? const {});
    _applyPrimaryBody(parsed.kind, payload, body);

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

  Future<Map<String, ({String kind, String name})>> _buildReverseLinkMap(
    String accessToken,
  ) async {
    final itemsByKind = <CatalogKind, List<CatalogItem>>{};
    for (final kind in ObsidianNoteMapper.exportKinds) {
      itemsByKind[kind] = await _api.list(accessToken, kind);
    }
    final notes = _mapper.planAll(itemsByKind);
    final map = <String, ({String kind, String name})>{};
    final ambiguousBases = <String>{};
    for (final note in notes) {
      final target = note.wikiTarget.toLowerCase();
      final value = (kind: note.item.kind.apiValue, name: note.item.name);
      map[target] = value;
      // Basename fallback when unique across the vault.
      final base = target.contains('/')
          ? target.substring(target.lastIndexOf('/') + 1)
          : target;
      if (ambiguousBases.contains(base)) continue;
      final prior = map[base];
      if (prior == null) {
        map[base] = value;
      } else if (prior.kind != value.kind || prior.name != value.name) {
        map.remove(base);
        ambiguousBases.add(base);
      }
    }
    return map;
  }

  void _applyPrimaryBody(
    CatalogKind kind,
    Map<String, dynamic> payload,
    String body,
  ) {
    switch (kind) {
      case CatalogKind.features:
        payload['text'] = body;
      case CatalogKind.creatures:
        payload['trigger'] = body;
      case CatalogKind.rules:
        payload['body'] = body;
      case CatalogKind.spells:
        _applySpellBody(payload, body);
      default:
        payload['description'] = body;
    }
  }

  void _applySpellBody(Map<String, dynamic> payload, String body) {
    final marker = RegExp(
      r'\n##\s*At higher levels\s*\n+',
      caseSensitive: false,
    );
    final match = marker.firstMatch(body);
    if (match == null) {
      payload['description'] = body;
      return;
    }
    payload['description'] = body.substring(0, match.start).trimRight();
    final higherDesc = body.substring(match.end).trim();
    final existing = payload['higherLevels'];
    if (existing is Map) {
      payload['higherLevels'] = {
        ...Map<String, dynamic>.from(existing),
        'description': higherDesc,
      };
    } else if (higherDesc.isNotEmpty) {
      payload['higherLevels'] = {'description': higherDesc};
    } else {
      payload.remove('higherLevels');
    }
  }
}
