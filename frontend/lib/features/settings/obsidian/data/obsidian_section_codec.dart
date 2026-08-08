import 'obsidian_field_map.dart';

final _h2 = RegExp(r'^##\s+(.+?)\s*$');
final _h3 = RegExp(r'^###\s+(.+?)\s*$');
final _levelSuffix = RegExp(r'^(.*?)\s*\(level\s+(\d+)\)\s*$', caseSensitive: false);
final _featureMetaComment = RegExp(
  r'<!--\s*rpg_feature\s+([^>]*)-->',
  caseSensitive: false,
);

/// Renders markdown body sections for export (no frontmatter).
///
/// The `description` field is written as leading body text without a
/// `## Description` heading so the note body is the description again.
/// Other markdown fields and nested blocks keep `##` / `###` sections.
String renderObsidianBody({
  required ObsidianKindFieldMap map,
  required Map<String, dynamic> payload,
  required String Function(String text) rewriteLinks,
}) {
  final buffer = StringBuffer();

  for (final field in map.markdownFields) {
    final raw = '${payload[field.payloadKey] ?? ''}'.trim();
    if (raw.isEmpty) continue;
    if (field.payloadKey == 'description') {
      buffer.writeln(rewriteLinks(raw).trimRight());
      buffer.writeln();
    } else {
      _writeH2(buffer, field.sectionTitle);
      buffer.writeln(rewriteLinks(raw).trimRight());
      buffer.writeln();
    }
  }

  if (map.spellHigherLevels) {
    final higher = payload['higherLevels'];
    if (higher is Map) {
      final higherDesc = '${higher['description'] ?? ''}'.trim();
      if (higherDesc.isNotEmpty) {
        _writeH2(buffer, ObsidianSectionTitles.atHigherLevels);
        buffer.writeln(rewriteLinks(higherDesc).trimRight());
        buffer.writeln();
      }
    }
  }

  for (final nested in map.nested) {
    switch (nested) {
      case ObsidianNestedProseKind.featuresByLevel:
        _writeFeaturesByLevel(buffer, payload['featuresByLevel'], rewriteLinks);
      case ObsidianNestedProseKind.namedFeatures:
        _writeNamedFeatures(buffer, payload['features'], rewriteLinks);
      case ObsidianNestedProseKind.typeSections:
        _writeTypeSections(buffer, payload['sections'], rewriteLinks);
      case ObsidianNestedProseKind.typeTraits:
        _writeTypeTraits(buffer, payload['traits'], rewriteLinks);
      case ObsidianNestedProseKind.creatureFeatures:
        _writeCreatureFeatures(buffer, payload['features'], rewriteLinks);
    }
  }

  return buffer.toString().trimRight();
}

/// Parsed body: top-level sections by title + optional nested blocks.
class ParsedObsidianBody {
  const ParsedObsidianBody({
    this.sections = const {},
    this.featuresByLevel,
    this.namedFeatures,
    this.typeSections,
    this.typeTraits,
    this.creatureFeatures,
  });

  /// `## Title` → body (excluding nested parent sections handled separately).
  final Map<String, String> sections;

  final Map<String, dynamic>? featuresByLevel;
  final List<Map<String, dynamic>>? namedFeatures;
  final List<Map<String, dynamic>>? typeSections;
  final List<Map<String, dynamic>>? typeTraits;
  final List<Map<String, dynamic>>? creatureFeatures;
}

ParsedObsidianBody parseObsidianBody(
  String body, {
  required ObsidianKindFieldMap map,
}) {
  final split = _splitH2BlocksWithPreamble(body);
  final sections = <String, String>{};
  Map<String, dynamic>? featuresByLevel;
  List<Map<String, dynamic>>? namedFeatures;
  List<Map<String, dynamic>>? typeSections;
  List<Map<String, dynamic>>? typeTraits;
  List<Map<String, dynamic>>? creatureFeatures;

  for (final block in split.blocks) {
    final title = block.title.trim();
    final titleLower = title.toLowerCase();
    final content = block.body.trim();

    if (map.nested.contains(ObsidianNestedProseKind.featuresByLevel) &&
        titleLower == ObsidianSectionTitles.features.toLowerCase()) {
      featuresByLevel = _parseFeaturesByLevel(content);
      continue;
    }
    if (map.nested.contains(ObsidianNestedProseKind.namedFeatures) &&
        titleLower == ObsidianSectionTitles.features.toLowerCase()) {
      namedFeatures = _parseNamedFeatures(content);
      continue;
    }
    if (map.nested.contains(ObsidianNestedProseKind.creatureFeatures) &&
        titleLower == ObsidianSectionTitles.features.toLowerCase()) {
      creatureFeatures = _parseCreatureFeatures(content);
      continue;
    }
    if (map.nested.contains(ObsidianNestedProseKind.typeSections) &&
        titleLower == ObsidianSectionTitles.sections.toLowerCase()) {
      typeSections = _parseTypeSections(content);
      continue;
    }
    if (map.nested.contains(ObsidianNestedProseKind.typeTraits) &&
        titleLower == ObsidianSectionTitles.traits.toLowerCase()) {
      typeTraits = _parseTypeTraits(content);
      continue;
    }

    sections[title] = content;
  }

  // Leading body (no ## heading) maps to description when that field exists
  // and there is no explicit ## Description section (legacy-friendly).
  final preamble = split.preamble.trim();
  if (preamble.isNotEmpty) {
    ObsidianMarkdownField? descriptionField;
    for (final f in map.markdownFields) {
      if (f.payloadKey == 'description') {
        descriptionField = f;
        break;
      }
    }
    if (descriptionField != null) {
      final hasExplicit = sections.keys.any(
        (k) => k.toLowerCase() == descriptionField!.sectionTitle.toLowerCase(),
      );
      if (!hasExplicit) {
        sections[descriptionField.sectionTitle] = preamble;
      }
    }
  }

  return ParsedObsidianBody(
    sections: sections,
    featuresByLevel: featuresByLevel,
    namedFeatures: namedFeatures,
    typeSections: typeSections,
    typeTraits: typeTraits,
    creatureFeatures: creatureFeatures,
  );
}

/// Builds frontmatter payload slice: all keys except body-owned markdown/nested.
Map<String, dynamic> frontmatterPayloadSlice({
  required ObsidianKindFieldMap map,
  required Map<String, dynamic> payload,
}) {
  final owned = map.bodyOwnedPayloadKeys;
  final out = <String, dynamic>{};
  for (final entry in payload.entries) {
    if (owned.contains(entry.key)) continue;
    if (entry.key == 'name') continue;
    out[entry.key] = entry.value;
  }

  if (map.spellHigherLevels) {
    final higher = payload['higherLevels'];
    if (higher is Map) {
      final copy = Map<String, dynamic>.from(higher);
      copy.remove('description');
      if (copy.isEmpty) {
        out.remove('higherLevels');
      } else {
        out['higherLevels'] = copy;
      }
    }
  }

  return out;
}

void _writeH2(StringBuffer buffer, String title) {
  buffer.writeln('## $title');
  buffer.writeln();
}

void _writeFeaturesByLevel(
  StringBuffer buffer,
  dynamic raw,
  String Function(String) rewriteLinks,
) {
  if (raw is! Map || raw.isEmpty) return;
  final levels = raw.keys
      .map((k) => int.tryParse(k.toString()))
      .whereType<int>()
      .toList()
    ..sort();
  if (levels.isEmpty) return;

  _writeH2(buffer, ObsidianSectionTitles.features);
  for (final level in levels) {
    final list = raw['$level'] ?? raw[level];
    if (list is! List) continue;
    for (final e in list) {
      final map = _asStringKeyedMap(e);
      if (map == null) continue;
      final name = '${map['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      final id = '${map['id'] ?? ''}'.trim();
      buffer.writeln('### $name (level $level)');
      buffer.writeln();
      if (id.isNotEmpty) {
        buffer.writeln('<!-- rpg_feature id="$id" -->');
        buffer.writeln();
      }
      final desc = '${map['description'] ?? ''}'.trim();
      if (desc.isNotEmpty) {
        buffer.writeln(rewriteLinks(desc).trimRight());
        buffer.writeln();
      }
    }
  }
}

void _writeNamedFeatures(
  StringBuffer buffer,
  dynamic raw,
  String Function(String) rewriteLinks,
) {
  if (raw is! List || raw.isEmpty) return;
  _writeH2(buffer, ObsidianSectionTitles.features);
  for (final e in raw) {
    final map = _asStringKeyedMap(e);
    if (map == null) continue;
    final name = '${map['name'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    buffer.writeln('### $name');
    buffer.writeln();
    final meta = <String>[];
    final kind = map['kind'];
    final level = map['level'];
    if (kind != null) meta.add('kind="$kind"');
    if (level != null) meta.add('level="$level"');
    if (meta.isNotEmpty) {
      buffer.writeln('<!-- rpg_feature ${meta.join(' ')} -->');
      buffer.writeln();
    }
    final desc = '${map['description'] ?? ''}'.trim();
    if (desc.isNotEmpty) {
      buffer.writeln(rewriteLinks(desc).trimRight());
      buffer.writeln();
    }
  }
}

void _writeTypeSections(
  StringBuffer buffer,
  dynamic raw,
  String Function(String) rewriteLinks,
) {
  if (raw is! List || raw.isEmpty) return;
  _writeH2(buffer, ObsidianSectionTitles.sections);
  for (final e in raw) {
    final map = _asStringKeyedMap(e);
    if (map == null) continue;
    final title = '${map['title'] ?? ''}'.trim();
    if (title.isEmpty) continue;
    buffer.writeln('### $title');
    buffer.writeln();
    final contents = '${map['contents'] ?? ''}'.trim();
    if (contents.isNotEmpty) {
      buffer.writeln(rewriteLinks(contents).trimRight());
      buffer.writeln();
    }
  }
}

void _writeTypeTraits(
  StringBuffer buffer,
  dynamic raw,
  String Function(String) rewriteLinks,
) {
  if (raw is! List || raw.isEmpty) return;
  _writeH2(buffer, ObsidianSectionTitles.traits);
  for (final e in raw) {
    final map = _asStringKeyedMap(e);
    if (map == null) continue;
    final name = '${map['name'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    buffer.writeln('### $name');
    buffer.writeln();
    final catalogId = map['featureCatalogItemId'];
    if (catalogId != null) {
      buffer.writeln('<!-- rpg_feature featureCatalogItemId="$catalogId" -->');
      buffer.writeln();
    }
    final desc = '${map['description'] ?? ''}'.trim();
    if (desc.isNotEmpty) {
      buffer.writeln(rewriteLinks(desc).trimRight());
      buffer.writeln();
    }
  }
}

void _writeCreatureFeatures(
  StringBuffer buffer,
  dynamic raw,
  String Function(String) rewriteLinks,
) {
  if (raw is! List || raw.isEmpty) return;
  _writeH2(buffer, ObsidianSectionTitles.features);
  for (final e in raw) {
    final map = _asStringKeyedMap(e);
    if (map == null) continue;
    final name = '${map['name'] ?? map['snapshotName'] ?? ''}'.trim();
    if (name.isEmpty) continue;
    buffer.writeln('### $name');
    buffer.writeln();
    final meta = <String>[];
    if (map['catalogItemId'] != null) {
      meta.add('catalogItemId="${map['catalogItemId']}"');
    }
    if (map['id'] != null) meta.add('id="${map['id']}"');
    if (meta.isNotEmpty) {
      buffer.writeln('<!-- rpg_feature ${meta.join(' ')} -->');
      buffer.writeln();
    }
    final text = '${map['text'] ?? map['snapshotText'] ?? ''}'.trim();
    if (text.isNotEmpty) {
      buffer.writeln(rewriteLinks(text).trimRight());
      buffer.writeln();
    }
  }
}

class _H2Block {
  const _H2Block({required this.title, required this.body});
  final String title;
  final String body;
}

List<_H2Block> _splitH2Blocks(String body) {
  return _splitH2BlocksWithPreamble(body).blocks;
}

({String preamble, List<_H2Block> blocks}) _splitH2BlocksWithPreamble(
  String body,
) {
  final lines = body.replaceAll('\r\n', '\n').split('\n');
  final blocks = <_H2Block>[];
  final preamble = StringBuffer();
  String? currentTitle;
  final current = StringBuffer();

  void flush() {
    if (currentTitle == null) return;
    blocks.add(_H2Block(title: currentTitle!, body: current.toString()));
    current.clear();
  }

  for (final line in lines) {
    final m = _h2.firstMatch(line);
    if (m != null) {
      flush();
      currentTitle = m.group(1)!.trim();
      continue;
    }
    if (currentTitle != null) {
      current.writeln(line);
    } else {
      preamble.writeln(line);
    }
  }
  flush();
  return (preamble: preamble.toString(), blocks: blocks);
}

List<({String title, String body})> _splitH3Blocks(String body) {
  final lines = body.replaceAll('\r\n', '\n').split('\n');
  final blocks = <({String title, String body})>[];
  String? currentTitle;
  final current = StringBuffer();

  void flush() {
    if (currentTitle == null) return;
    blocks.add((title: currentTitle!, body: current.toString().trim()));
    current.clear();
  }

  for (final line in lines) {
    final m = _h3.firstMatch(line);
    if (m != null) {
      flush();
      currentTitle = m.group(1)!.trim();
      continue;
    }
    if (currentTitle != null) {
      current.writeln(line);
    }
  }
  flush();
  return blocks;
}

Map<String, dynamic> _parseFeaturesByLevel(String content) {
  final result = <String, List<Map<String, dynamic>>>{};
  for (final block in _splitH3Blocks(content)) {
    var name = block.title;
    var level = 1;
    final levelMatch = _levelSuffix.firstMatch(name);
    if (levelMatch != null) {
      name = levelMatch.group(1)!.trim();
      level = int.tryParse(levelMatch.group(2)!) ?? 1;
    }
    final meta = _parseFeatureMeta(block.body);
    final desc = _stripFeatureMeta(block.body).trim();
    final feature = <String, dynamic>{
      'name': name,
      'level': level,
      'description': desc,
      if (meta['id'] != null) 'id': meta['id'],
    };
    final key = '$level';
    result.putIfAbsent(key, () => []).add(feature);
  }
  return result;
}

List<Map<String, dynamic>> _parseNamedFeatures(String content) {
  final out = <Map<String, dynamic>>[];
  for (final block in _splitH3Blocks(content)) {
    final meta = _parseFeatureMeta(block.body);
    final desc = _stripFeatureMeta(block.body).trim();
    out.add({
      'name': block.title,
      'description': desc,
      if (meta['kind'] != null) 'kind': meta['kind'],
      if (meta['level'] != null)
        'level': int.tryParse('${meta['level']}') ?? meta['level'],
    });
  }
  return out;
}

List<Map<String, dynamic>> _parseTypeSections(String content) {
  return [
    for (final block in _splitH3Blocks(content))
      {'title': block.title, 'contents': block.body.trim()},
  ];
}

List<Map<String, dynamic>> _parseTypeTraits(String content) {
  final out = <Map<String, dynamic>>[];
  for (final block in _splitH3Blocks(content)) {
    final meta = _parseFeatureMeta(block.body);
    final desc = _stripFeatureMeta(block.body).trim();
    final catalogId = meta['featureCatalogItemId'];
    out.add({
      'name': block.title,
      'description': desc,
      if (catalogId != null)
        'featureCatalogItemId': int.tryParse('$catalogId') ?? catalogId,
    });
  }
  return out;
}

List<Map<String, dynamic>> _parseCreatureFeatures(String content) {
  final out = <Map<String, dynamic>>[];
  for (final block in _splitH3Blocks(content)) {
    final meta = _parseFeatureMeta(block.body);
    final text = _stripFeatureMeta(block.body).trim();
    final catalogId = meta['catalogItemId'];
    if (catalogId != null) {
      out.add({
        'catalogItemId': int.tryParse('$catalogId') ?? catalogId,
        'snapshotName': block.title,
        'snapshotText': text,
      });
    } else {
      out.add({
        if (meta['id'] != null) 'id': meta['id'],
        'name': block.title,
        'text': text,
      });
    }
  }
  return out;
}

Map<String, String> _parseFeatureMeta(String body) {
  final match = _featureMetaComment.firstMatch(body);
  if (match == null) return const {};
  final raw = match.group(1) ?? '';
  final out = <String, String>{};
  final attr = RegExp(r'(\w+)="([^"]*)"');
  for (final m in attr.allMatches(raw)) {
    out[m.group(1)!] = m.group(2)!;
  }
  return out;
}

String _stripFeatureMeta(String body) {
  return body.replaceAll(_featureMetaComment, '').trim();
}

Map<String, dynamic>? _asStringKeyedMap(dynamic e) {
  if (e is Map<String, dynamic>) return e;
  if (e is Map) return Map<String, dynamic>.from(e);
  return null;
}
