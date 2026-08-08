import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../../core/markdown/wiki_link.dart';
import 'obsidian_field_map.dart';
import 'obsidian_section_codec.dart';
import 'obsidian_vault_validator.dart';

/// One planned note under the managed vault folder.
class ObsidianPlannedNote {
  const ObsidianPlannedNote({
    required this.item,
    required this.relativePath,
    required this.contents,
  });

  final CatalogItem item;

  /// Path relative to the vault root, using `/` separators
  /// (e.g. `RPG Manager/Locations/Nation/City.md`).
  final String relativePath;

  final String contents;

  /// Wikilink target without `.md` (Obsidian path from vault root).
  String get wikiTarget {
    final withoutExt = relativePath.endsWith('.md')
        ? relativePath.substring(0, relativePath.length - 3)
        : relativePath;
    return withoutExt.replaceAll('\\', '/');
  }
}

/// Builds Obsidian notes from catalog items (excludes generators).
class ObsidianNoteMapper {
  static List<CatalogKind> get exportKinds => CatalogKind.values
      .where((k) => k != CatalogKind.generators)
      .toList(growable: false);

  /// Title-cased folder label for a kind (e.g. `Spell tags`).
  static String kindFolderName(CatalogKind kind) {
    return kind.pluralLabel
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static String sanitizeFileName(String name) {
    var result = name.trim();
    if (result.isEmpty) result = 'untitled';
    result = result.replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_');
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (result.isEmpty) result = 'untitled';
    // Avoid reserved Windows device names.
    final lower = result.toLowerCase();
    const reserved = {
      'con',
      'prn',
      'aux',
      'nul',
      'com1',
      'com2',
      'com3',
      'com4',
      'lpt1',
      'lpt2',
      'lpt3',
    };
    if (reserved.contains(lower)) {
      result = '_$result';
    }
    return result;
  }

  /// Plans all notes for [itemsByKind]. Keys must include every export kind
  /// that appears in the catalog (empty lists are fine).
  List<ObsidianPlannedNote> planAll(
    Map<CatalogKind, List<CatalogItem>> itemsByKind,
  ) {
    final byId = <int, CatalogItem>{};
    for (final items in itemsByKind.values) {
      for (final item in items) {
        byId[item.id] = item;
      }
    }

    final pathById = <int, String>{};
    for (final kind in exportKinds) {
      final items = itemsByKind[kind] ?? const <CatalogItem>[];
      for (final item in items) {
        pathById[item.id] = _relativePathFor(item, byId);
      }
    }

    _disambiguatePaths(pathById, byId);

    // Wikilink lookup: kind api + id (and legacy name/alias) → vault path.
    final linkTargets = <String, String>{};
    for (final entry in pathById.entries) {
      final item = byId[entry.key];
      if (item == null) continue;
      final wiki = _wikiTargetFromRelative(entry.value);
      linkTargets[_linkKey(item.kind.apiValue, '${item.id}')] = wiki;
      // Legacy name keys so unmigrated payloads still export cleanly.
      linkTargets.putIfAbsent(
        _linkKey(item.kind.apiValue, item.name),
        () => wiki,
      );
      final aliases = item.payload?['aliases'];
      if (aliases is List) {
        for (final alias in aliases) {
          final text = '$alias'.trim();
          if (text.isEmpty) continue;
          linkTargets.putIfAbsent(
            _linkKey(item.kind.apiValue, text),
            () => wiki,
          );
        }
      }
    }

    final notes = <ObsidianPlannedNote>[];
    for (final entry in pathById.entries) {
      final item = byId[entry.key]!;
      final relativePath = entry.value;
      notes.add(
        ObsidianPlannedNote(
          item: item,
          relativePath: relativePath,
          contents: _renderNote(
            item: item,
            relativePath: relativePath,
            byId: byId,
            linkTargets: linkTargets,
          ),
        ),
      );
    }
    return notes;
  }

  static String _linkKey(String kindApi, String name) =>
      '${kindApi.toLowerCase()}\u0000${name.trim().toLowerCase()}';

  static String _wikiTargetFromRelative(String relativePath) {
    final withoutExt = relativePath.endsWith('.md')
        ? relativePath.substring(0, relativePath.length - 3)
        : relativePath;
    return withoutExt.replaceAll('\\', '/');
  }

  String _relativePathFor(CatalogItem item, Map<int, CatalogItem> byId) {
    final fileName = '${sanitizeFileName(item.name)}.md';
    final kindFolder = kindFolderName(item.kind);
    final managed = obsidianManagedFolderName;

    switch (item.kind) {
      case CatalogKind.locations:
        final chain = _ancestorNameChain(
          item,
          byId,
          parentIdOf: (i) => (i.payload?['parentId'] as num?)?.toInt(),
        );
        final segments = [
          managed,
          kindFolder,
          ...chain.map(sanitizeFileName),
          fileName,
        ];
        return segments.join('/');

      case CatalogKind.sessions:
        final campaignId = (item.payload?['campaignId'] as num?)?.toInt();
        final campaign = campaignId == null ? null : byId[campaignId];
        final campaignName = campaign != null
            ? sanitizeFileName(campaign.name)
            : 'Unknown campaign';
        return [
          managed,
          kindFolderName(CatalogKind.campaigns),
          campaignName,
          'Sessions',
          fileName,
        ].join('/');

      case CatalogKind.subclasses:
        final parentId = (item.payload?['parentClassId'] as num?)?.toInt();
        final parent = parentId == null ? null : byId[parentId];
        final parentName =
            parent != null ? sanitizeFileName(parent.name) : 'Unknown class';
        return [
          managed,
          kindFolderName(CatalogKind.classes),
          parentName,
          kindFolder,
          fileName,
        ].join('/');

      case CatalogKind.rules:
        final chain = _ancestorNameChain(
          item,
          byId,
          parentIdOf: (i) => (i.payload?['parentRuleId'] as num?)?.toInt(),
        );
        return [
          managed,
          kindFolder,
          ...chain.map(sanitizeFileName),
          fileName,
        ].join('/');

      case CatalogKind.creatureTypes:
        final chain = _ancestorNameChain(
          item,
          byId,
          parentIdOf: (i) =>
              (i.payload?['parentCreatureTypeId'] as num?)?.toInt(),
        );
        return [
          managed,
          kindFolder,
          ...chain.map(sanitizeFileName),
          fileName,
        ].join('/');

      case CatalogKind.organisations:
        final chain = _ancestorNameChain(
          item,
          byId,
          parentIdOf: (i) => (i.payload?['parentId'] as num?)?.toInt(),
        );
        return [
          managed,
          kindFolder,
          ...chain.map(sanitizeFileName),
          fileName,
        ].join('/');

      default:
        return [managed, kindFolder, fileName].join('/');
    }
  }

  /// Parent names from root → immediate parent (excludes [item] itself).
  List<String> _ancestorNameChain(
    CatalogItem item,
    Map<int, CatalogItem> byId, {
    required int? Function(CatalogItem) parentIdOf,
  }) {
    final names = <String>[];
    final seen = <int>{item.id};
    var parentId = parentIdOf(item);
    while (parentId != null) {
      if (!seen.add(parentId)) break;
      final parent = byId[parentId];
      if (parent == null) break;
      names.add(parent.name);
      parentId = parentIdOf(parent);
    }
    return names.reversed.toList(growable: false);
  }

  void _disambiguatePaths(
    Map<int, String> pathById,
    Map<int, CatalogItem> byId,
  ) {
    final used = <String, int>{};
    final ids = pathById.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    for (final id in ids) {
      var path = pathById[id]!;
      final owner = used[path.toLowerCase()];
      if (owner == null) {
        used[path.toLowerCase()] = id;
        continue;
      }
      // Collision: append id before .md
      final item = byId[id]!;
      final dir = path.contains('/')
          ? path.substring(0, path.lastIndexOf('/'))
          : '';
      final base = sanitizeFileName(item.name);
      path = dir.isEmpty
          ? '$base ($id).md'
          : '$dir/$base ($id).md';
      // Still collide somehow — force unique.
      var n = 2;
      while (used.containsKey(path.toLowerCase())) {
        path = dir.isEmpty
            ? '$base ($id)-$n.md'
            : '$dir/$base ($id)-$n.md';
        n++;
      }
      pathById[id] = path;
      used[path.toLowerCase()] = id;
    }
  }

  String _renderNote({
    required CatalogItem item,
    required String relativePath,
    required Map<int, CatalogItem> byId,
    required Map<String, String> linkTargets,
  }) {
    final fieldMap = obsidianFieldMapFor(item.kind);
    final payload = Map<String, dynamic>.from(item.payload ?? const {});

    final fm = <String, dynamic>{
      'rpg_manager_id': item.id,
      'rpg_manager_kind': item.kind.apiValue,
      'name': item.name,
      ...frontmatterPayloadSlice(map: fieldMap, payload: payload),
    };

    String rewrite(String text) => rewriteWikiLinksForObsidian(
          text,
          linkTargets: linkTargets,
        );

    final body = renderObsidianBody(
      map: fieldMap,
      payload: payload,
      rewriteLinks: rewrite,
    );

    final buffer = StringBuffer();
    buffer.writeln('---');
    buffer.write(_encodeFrontmatter(fm));
    if (!buffer.toString().endsWith('\n')) buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();
    if (body.trim().isNotEmpty) {
      buffer.write(body.trimRight());
      buffer.writeln();
    }
    return buffer.toString();
  }

  String _encodeFrontmatter(Map<String, dynamic> fm) {
    // yaml package encodes a map; strip document markers if present.
    final encoded = _yamlMapToString(fm);
    return encoded.trimRight();
  }

  String _yamlMapToString(Map<String, dynamic> map) {
    final buffer = StringBuffer();
    for (final entry in map.entries) {
      buffer.write(_yamlEntry(entry.key, entry.value, 0));
    }
    return buffer.toString();
  }

  String _yamlEntry(String key, dynamic value, int indent) {
    final pad = '  ' * indent;
    if (value == null) return '$pad$key: null\n';
    if (value is num || value is bool) return '$pad$key: $value\n';
    if (value is String) {
      return '$pad$key: ${_yamlQuote(value)}\n';
    }
    if (value is List) {
      if (value.isEmpty) return '$pad$key: []\n';
      final buffer = StringBuffer('$pad$key:\n');
      for (final item in value) {
        if (item is Map) {
          buffer.writeln('$pad  -');
          final map = Map<String, dynamic>.from(item);
          for (final e in map.entries) {
            buffer.write(_yamlEntry(e.key, e.value, indent + 2));
          }
        } else if (item is List) {
          buffer.writeln('$pad  -');
          // Rare nested list — dump as JSON-ish string.
          buffer.write(_yamlEntry('value', item.toString(), indent + 2));
        } else {
          buffer.writeln('$pad  - ${_yamlScalar(item)}');
        }
      }
      return buffer.toString();
    }
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      if (map.isEmpty) return '$pad$key: {}\n';
      final buffer = StringBuffer('$pad$key:\n');
      for (final e in map.entries) {
        buffer.write(_yamlEntry(e.key, e.value, indent + 1));
      }
      return buffer.toString();
    }
    return '$pad$key: ${_yamlQuote('$value')}\n';
  }

  String _yamlScalar(dynamic value) {
    if (value == null) return 'null';
    if (value is num || value is bool) return '$value';
    return _yamlQuote('$value');
  }

  String _yamlQuote(String text) {
    final escaped = text.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
  }
}

/// Rewrites app `[[kind/id]]` (or legacy `[[kind/name]]`) links to Obsidian
/// vault paths.
String rewriteWikiLinksForObsidian(
  String text, {
  required Map<String, String> linkTargets,
}) {
  if (text.isEmpty) return text;
  return text.replaceAllMapped(wikiLinkPattern, (match) {
    final kind = match.group(1)!.trim();
    final target = match.group(2)!.trim();
    final alias = match.group(3)?.trim();
    final key = '${kind.toLowerCase()}\u0000${target.toLowerCase()}';
    final resolved = linkTargets[key] ?? _fallbackWikiTarget(kind, target);
    if (alias != null && alias.isNotEmpty) {
      return '[[$resolved|$alias]]';
    }
    return '[[$resolved]]';
  });
}

String _fallbackWikiTarget(String kindApi, String target) {
  final kind = CatalogKind.tryParseApiValue(kindApi);
  final folder = kind != null
      ? ObsidianNoteMapper.kindFolderName(kind)
      : kindApi;
  return '$obsidianManagedFolderName/$folder/'
      '${ObsidianNoteMapper.sanitizeFileName(target)}';
}
