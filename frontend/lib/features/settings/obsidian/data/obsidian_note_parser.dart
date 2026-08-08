import 'package:yaml/yaml.dart';

import '../../../catalog/data/catalog_kind.dart';
import 'obsidian_field_map.dart';
import 'obsidian_section_codec.dart';

/// Parsed Obsidian note written by [ObsidianNoteMapper] (or an orphan vault note).
class ParsedObsidianNote {
  const ParsedObsidianNote({
    required this.kind,
    required this.frontmatter,
    required this.body,
    required this.parsedBody,
    this.id,
    this.name,
  });

  /// Catalog id when `rpg_manager_id` is present; null for new-note imports.
  final int? id;
  final CatalogKind kind;
  final String? name;

  /// Full YAML frontmatter map (includes system keys).
  final Map<String, dynamic> frontmatter;

  /// Raw markdown body (after frontmatter).
  final String body;

  final ParsedObsidianBody parsedBody;
}

/// Parses YAML frontmatter + markdown body from an exported or orphan note.
///
/// Requires a resolvable [CatalogKind]: from `rpg_manager_kind`, or [kindHint]
/// (e.g. inferred from the vault path). [id] may be absent for creates.
ParsedObsidianNote? parseObsidianNote(
  String contents, {
  CatalogKind? kindHint,
}) {
  final text = contents.replaceFirst(RegExp(r'^\uFEFF'), '');
  final match = RegExp(
    r'^---\r?\n([\s\S]*?)\r?\n---\r?\n?',
  ).firstMatch(text);

  Map<String, dynamic> fm;
  String body;
  if (match != null) {
    fm = _parseYamlFrontmatter(match.group(1) ?? '');
    body = text.substring(match.end).replaceAll('\r\n', '\n').trim();
  } else if (kindHint != null) {
    // Plain markdown with no frontmatter — treat whole file as body.
    fm = <String, dynamic>{};
    body = text.replaceAll('\r\n', '\n').trim();
  } else {
    return null;
  }

  final kindRaw = fm['rpg_manager_kind'];
  final kind = kindRaw != null
      ? CatalogKind.tryParseApiValue('$kindRaw'.trim())
      : kindHint;
  if (kind == null) return null;

  final idRaw = fm['rpg_manager_id'];
  int? id;
  if (idRaw != null) {
    id = idRaw is int ? idRaw : int.tryParse(idRaw.toString().trim());
  }

  final nameRaw = fm['name'];
  final name = nameRaw == null ? null : '$nameRaw'.trim();
  final map = obsidianFieldMapFor(kind);
  final parsedBody = parseObsidianBody(body, map: map);

  return ParsedObsidianNote(
    id: id,
    kind: kind,
    name: name == null || name.isEmpty ? null : name,
    frontmatter: fm,
    body: body,
    parsedBody: parsedBody,
  );
}

/// Updates or inserts system frontmatter keys; preserves the markdown body and
/// any other frontmatter fields (including nested YAML).
String writeObsidianSystemFrontmatter(
  String contents, {
  required int id,
  required CatalogKind kind,
  required String name,
}) {
  final text = contents.replaceFirst(RegExp(r'^\uFEFF'), '');
  final match = RegExp(
    r'^---\r?\n([\s\S]*?)\r?\n---\r?\n?',
  ).firstMatch(text);

  final escapedName = name.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
  final idLine = 'rpg_manager_id: $id';
  final kindLine = 'rpg_manager_kind: "${kind.apiValue}"';
  final nameLine = 'name: "$escapedName"';

  if (match == null) {
    final body = text.replaceAll('\r\n', '\n').trimRight();
    final buffer = StringBuffer()
      ..writeln('---')
      ..writeln(idLine)
      ..writeln(kindLine)
      ..writeln(nameLine)
      ..writeln('---')
      ..writeln();
    if (body.isNotEmpty) {
      buffer.writeln(body);
    }
    return buffer.toString();
  }

  var yaml = match.group(1)!;
  yaml = _upsertFrontmatterLine(yaml, 'rpg_manager_id', idLine);
  yaml = _upsertFrontmatterLine(yaml, 'rpg_manager_kind', kindLine);
  yaml = _upsertFrontmatterLine(yaml, 'name', nameLine);

  final rest = text.substring(match.end);
  return '---\n$yaml\n---\n$rest';
}

String _upsertFrontmatterLine(String yaml, String key, String fullLine) {
  final pattern = RegExp(
    '^${RegExp.escape(key)}\\s*:.*\$',
    multiLine: true,
  );
  if (pattern.hasMatch(yaml)) {
    return yaml.replaceFirst(pattern, fullLine);
  }
  final trimmed = yaml.trimRight();
  if (trimmed.isEmpty) return fullLine;
  return '$trimmed\n$fullLine';
}

Map<String, dynamic> _parseYamlFrontmatter(String yamlText) {
  try {
    final loaded = loadYaml(yamlText);
    if (loaded is YamlMap) {
      return _yamlToDartMap(loaded);
    }
    if (loaded is Map) {
      return Map<String, dynamic>.from(
        loaded.map((k, v) => MapEntry('$k', _yamlValue(v))),
      );
    }
  } catch (_) {
    // Fall through to legacy line parser.
  }
  return _parseFrontmatterLegacy(yamlText);
}

Map<String, dynamic> _yamlToDartMap(YamlMap map) {
  final out = <String, dynamic>{};
  for (final entry in map.entries) {
    out['${entry.key}'] = _yamlValue(entry.value);
  }
  return out;
}

dynamic _yamlValue(dynamic value) {
  if (value == null) return null;
  if (value is YamlMap) return _yamlToDartMap(value);
  if (value is YamlList) {
    return [for (final e in value) _yamlValue(e)];
  }
  return value;
}

Map<String, dynamic> _parseFrontmatterLegacy(String yaml) {
  final out = <String, dynamic>{};
  for (final rawLine in yaml.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trimRight();
    if (line.isEmpty || line.startsWith('#')) continue;
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    final key = line.substring(0, colon).trim();
    var value = line.substring(colon + 1).trim();
    if (value == 'null') {
      out[key] = null;
      continue;
    }
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
      value = value.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
    }
    final asInt = int.tryParse(value);
    if (asInt != null) {
      out[key] = asInt;
      continue;
    }
    if (value == 'true' || value == 'false') {
      out[key] = value == 'true';
      continue;
    }
    out[key] = value;
  }
  return out;
}

/// Obsidian-style wikilinks, including multi-segment vault paths.
final RegExp obsidianWikiLinkPattern = RegExp(
  r'\[\[([^\]|#]+?)(?:\|([^\]]+))?\]\]',
);

/// Rewrites Obsidian vault-path wikilinks back to app `[[kind/id]]` form.
String rewriteWikiLinksFromObsidian(
  String text, {
  required Map<String, ({String kind, int id})> targetsByWikiPath,
  Map<String, int>? idsByKindName,
}) {
  if (text.isEmpty) return text;
  return text.replaceAllMapped(obsidianWikiLinkPattern, (match) {
    var target = match.group(1)!.trim();
    final alias = match.group(2)?.trim();
    if (target.toLowerCase().endsWith('.md')) {
      target = target.substring(0, target.length - 3);
    }
    target = target.replaceAll('\\', '/');

    String linkFor(String kind, int id) {
      if (alias != null && alias.isNotEmpty) {
        return '[[$kind/$id|$alias]]';
      }
      return '[[$kind/$id]]';
    }

    final resolved = targetsByWikiPath[target.toLowerCase()];
    if (resolved != null) {
      return linkFor(resolved.kind, resolved.id);
    }

    final slash = target.indexOf('/');
    if (slash > 0 && !target.substring(slash + 1).contains('/')) {
      final kindApi = target.substring(0, slash);
      final rest = target.substring(slash + 1).trim();
      if (CatalogKind.tryParseApiValue(kindApi) != null) {
        // Already canonical `kind/id`.
        if (RegExp(r'^\d+$').hasMatch(rest)) {
          return match.group(0)!;
        }
        // Legacy `kind/name` → id when we can resolve it.
        final id = idsByKindName?['${kindApi.toLowerCase()}\u0000${rest.toLowerCase()}'];
        if (id != null) return linkFor(kindApi, id);
        return match.group(0)!;
      }
    }

    return match.group(0)!;
  });
}
