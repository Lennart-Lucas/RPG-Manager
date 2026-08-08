import 'package:yaml/yaml.dart';

import '../../../catalog/data/catalog_kind.dart';
import 'obsidian_field_map.dart';
import 'obsidian_section_codec.dart';

/// Parsed Obsidian note written by [ObsidianNoteMapper].
class ParsedObsidianNote {
  const ParsedObsidianNote({
    required this.id,
    required this.kind,
    required this.frontmatter,
    required this.body,
    required this.parsedBody,
    this.name,
  });

  final int id;
  final CatalogKind kind;
  final String? name;

  /// Full YAML frontmatter map (includes system keys).
  final Map<String, dynamic> frontmatter;

  /// Raw markdown body (after frontmatter).
  final String body;

  final ParsedObsidianBody parsedBody;
}

/// Parses YAML frontmatter + markdown body from an exported note.
ParsedObsidianNote? parseObsidianNote(String contents) {
  final text = contents.replaceFirst(RegExp(r'^\uFEFF'), '');
  final match = RegExp(
    r'^---\r?\n([\s\S]*?)\r?\n---\r?\n?',
  ).firstMatch(text);
  if (match == null) return null;

  final fm = _parseYamlFrontmatter(match.group(1) ?? '');
  final idRaw = fm['rpg_manager_id'];
  final kindRaw = fm['rpg_manager_kind'];
  if (idRaw == null || kindRaw == null) return null;

  final id = idRaw is int
      ? idRaw
      : int.tryParse(idRaw.toString().trim());
  final kind = CatalogKind.tryParseApiValue('${kindRaw}'.trim());
  if (id == null || kind == null) return null;

  final nameRaw = fm['name'];
  final name = nameRaw == null ? null : '$nameRaw'.trim();
  final body = text.substring(match.end).replaceAll('\r\n', '\n').trim();
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
