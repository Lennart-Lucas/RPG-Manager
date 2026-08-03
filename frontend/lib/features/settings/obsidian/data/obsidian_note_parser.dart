import '../../../catalog/data/catalog_kind.dart';

/// Parsed Obsidian note written by [ObsidianNoteMapper].
class ParsedObsidianNote {
  const ParsedObsidianNote({
    required this.id,
    required this.kind,
    required this.body,
    this.name,
  });

  final int id;
  final CatalogKind kind;
  final String body;
  final String? name;
}

/// Parses YAML frontmatter + markdown body from an exported note.
ParsedObsidianNote? parseObsidianNote(String contents) {
  final text = contents.replaceFirst(RegExp(r'^\uFEFF'), '');
  final match = RegExp(
    r'^---\r?\n([\s\S]*?)\r?\n---\r?\n?',
  ).firstMatch(text);
  if (match == null) return null;

  final fm = _parseFrontmatter(match.group(1) ?? '');
  final idRaw = fm['rpg_manager_id'];
  final kindRaw = fm['rpg_manager_kind'];
  if (idRaw == null || kindRaw == null) return null;

  final id = int.tryParse(idRaw.trim());
  final kind = CatalogKind.tryParseApiValue(kindRaw.trim());
  if (id == null || kind == null) return null;

  final nameRaw = fm['name'];
  final name = nameRaw?.trim();
  final body = text.substring(match.end).replaceAll('\r\n', '\n').trim();

  return ParsedObsidianNote(
    id: id,
    kind: kind,
    name: name == null || name.isEmpty ? null : name,
    body: body,
  );
}

Map<String, String> _parseFrontmatter(String yaml) {
  final out = <String, String>{};
  for (final rawLine in yaml.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trimRight();
    if (line.isEmpty || line.startsWith('#')) continue;
    final colon = line.indexOf(':');
    if (colon <= 0) continue;
    final key = line.substring(0, colon).trim();
    var value = line.substring(colon + 1).trim();
    if (value == 'null') {
      out[key] = '';
      continue;
    }
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
      value = value.replaceAll(r'\"', '"').replaceAll(r'\\', r'\');
    }
    out[key] = value;
  }
  return out;
}

/// Obsidian-style wikilinks, including multi-segment vault paths.
final RegExp obsidianWikiLinkPattern = RegExp(
  r'\[\[([^\]|#]+?)(?:\|([^\]]+))?\]\]',
);

/// Rewrites Obsidian vault-path wikilinks back to app `[[kind/name]]` form.
String rewriteWikiLinksFromObsidian(
  String text, {
  required Map<String, ({String kind, String name})> targetsByWikiPath,
}) {
  if (text.isEmpty) return text;
  return text.replaceAllMapped(obsidianWikiLinkPattern, (match) {
    var target = match.group(1)!.trim();
    final alias = match.group(2)?.trim();
    // Drop optional Obsidian heading suffix already excluded by regex, but
    // also strip trailing `.md` if present.
    if (target.toLowerCase().endsWith('.md')) {
      target = target.substring(0, target.length - 3);
    }
    target = target.replaceAll('\\', '/');

    final resolved = targetsByWikiPath[target.toLowerCase()];
    if (resolved != null) {
      if (alias != null && alias.isNotEmpty) {
        return '[[${resolved.kind}/${resolved.name}|$alias]]';
      }
      return '[[${resolved.kind}/${resolved.name}]]';
    }

    // Already app-shaped: [[kind/name]]
    final slash = target.indexOf('/');
    if (slash > 0 && !target.substring(slash + 1).contains('/')) {
      final kindApi = target.substring(0, slash);
      if (CatalogKind.tryParseApiValue(kindApi) != null) {
        return match.group(0)!;
      }
    }

    return match.group(0)!;
  });
}
