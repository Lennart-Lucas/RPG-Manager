/// Wiki-style catalog references: `[[kind/name]]`, `[[kind/name|alias]]`,
/// and Obsidian-style embeds `![[kind/name]]` / `![[kind/name|alias]]`.
library;

final RegExp wikiLinkPattern = RegExp(
  r'\[\[([^\]|/]+)/([^\]|]+)(?:\|([^\]]+))?\]\]',
);

/// Embeds only (leading `!`). Does not match plain `[[…]]`.
final RegExp wikiEmbedPattern = RegExp(
  r'!\[\[([^\]|/]+)/([^\]|]+)(?:\|([^\]]+))?\]\]',
);

class WikiLink {
  const WikiLink({
    required this.kind,
    required this.name,
    this.alias,
    required this.start,
    required this.end,
    this.isEmbed = false,
  });

  final String kind;
  final String name;
  final String? alias;
  final int start;
  final int end;
  final bool isEmbed;

  String get reference => '$kind/$name';

  String get displayText =>
      (alias != null && alias!.isNotEmpty) ? alias! : name;

  String toMarkdown() {
    final inner = (alias != null && alias!.isNotEmpty)
        ? '[[$kind/$name|$alias]]'
        : '[[$kind/$name]]';
    return isEmbed ? '!$inner' : inner;
  }
}

class IncompleteWikiLink {
  const IncompleteWikiLink({
    required this.start,
    required this.query,
    this.isEmbed = false,
  });

  /// Index of the opening `[[` (or `![[` when [isEmbed]).
  final int start;

  /// Text typed after `[[` (may include a partial `kind/` prefix).
  final String query;

  /// True when the incomplete opener was `![[`.
  final bool isEmbed;
}

/// All embeds in [text], in document order.
List<WikiLink> parseWikiEmbeds(String text) {
  final embeds = <WikiLink>[];
  for (final match in wikiEmbedPattern.allMatches(text)) {
    embeds.add(
      WikiLink(
        kind: match.group(1)!.trim(),
        name: match.group(2)!.trim(),
        alias: match.group(3)?.trim(),
        start: match.start,
        end: match.end,
        isEmbed: true,
      ),
    );
  }
  return embeds;
}

/// Plain wiki links only (spans already covered by embeds are skipped).
List<WikiLink> parseWikiLinks(String text) {
  final embedRanges = [
    for (final e in parseWikiEmbeds(text)) (start: e.start, end: e.end),
  ];
  final links = <WikiLink>[];
  for (final match in wikiLinkPattern.allMatches(text)) {
    if (_overlapsAny(match.start, match.end, embedRanges)) continue;
    links.add(
      WikiLink(
        kind: match.group(1)!.trim(),
        name: match.group(2)!.trim(),
        alias: match.group(3)?.trim(),
        start: match.start,
        end: match.end,
      ),
    );
  }
  return links;
}

/// Embeds and plain links, sorted by start index.
List<WikiLink> parseWikiLinksAndEmbeds(String text) {
  final all = [...parseWikiEmbeds(text), ...parseWikiLinks(text)];
  all.sort((a, b) => a.start.compareTo(b.start));
  return all;
}

String stripWikiMarkup(String text) {
  var t = text.replaceAllMapped(wikiEmbedPattern, (match) {
    final alias = match.group(3)?.trim();
    final name = match.group(2)?.trim() ?? '';
    if (alias != null && alias.isNotEmpty) return alias;
    return name;
  });
  return t.replaceAllMapped(wikiLinkPattern, (match) {
    final alias = match.group(3)?.trim();
    final name = match.group(2)?.trim() ?? '';
    if (alias != null && alias.isNotEmpty) return alias;
    return name;
  });
}

String formatWikiLink({
  required String kind,
  required String name,
  String? alias,
  bool embed = false,
}) {
  final inner = (alias != null && alias.isNotEmpty)
      ? '[[$kind/$name|$alias]]'
      : '[[$kind/$name]]';
  return embed ? '!$inner' : inner;
}

/// Finds an unfinished `[[…` or `![[…` at [cursor] (no closing `]]` yet).
IncompleteWikiLink? findIncompleteWikiLink(String text, int cursor) {
  if (cursor < 0 || cursor > text.length) return null;

  final before = text.substring(0, cursor);
  final open = before.lastIndexOf('[[');
  if (open < 0) return null;

  final afterOpen = before.substring(open + 2);
  if (afterOpen.contains(']]')) return null;

  // Do not treat a completed link that ends before the cursor as incomplete.
  final closedBefore = before.lastIndexOf(']]');
  if (closedBefore > open) return null;

  final isEmbed = open > 0 && before[open - 1] == '!';
  return IncompleteWikiLink(
    start: isEmbed ? open - 1 : open,
    query: afterOpen,
    isEmbed: isEmbed,
  );
}

/// Rewrites `[[kind/oldName]]`, embeds, and aliased forms to [newName].
String rewriteWikiLinkNames(
  String text, {
  required String kind,
  required String oldName,
  required String newName,
}) {
  if (oldName == newName) return text;

  final escapedKind = RegExp.escape(kind);
  final escapedOld = RegExp.escape(oldName);
  final pattern = RegExp(
    '(!?)\\[\\[$escapedKind/$escapedOld(?:\\|([^\\]]+))?\\]\\]',
  );

  return text.replaceAllMapped(pattern, (match) {
    final bang = match.group(1) ?? '';
    final alias = match.group(2);
    return '$bang${formatWikiLink(kind: kind, name: newName, alias: alias)}';
  });
}

class _AutoLinkTarget {
  const _AutoLinkTarget({required this.kind, required this.name});

  final String kind;
  final String name;
}

/// Wraps plain-text mentions of [targets] as `[[kind/name]]`.
///
/// Longer names are applied first. Existing wiki links/embeds are left untouched.
/// Matching is case-insensitive and uses word boundaries.
String autoLinkCatalogNames(
  String text, {
  required Iterable<({String kind, String name})> targets,
}) {
  final sorted = targets
      .where((t) => t.name.trim().isNotEmpty)
      .map((t) => _AutoLinkTarget(kind: t.kind, name: t.name.trim()))
      .toList()
    ..sort((a, b) => b.name.length.compareTo(a.name.length));

  if (sorted.isEmpty || text.isEmpty) return text;

  var result = text;
  for (final target in sorted) {
    final protected = _wikiLinkRanges(result);
    final pattern = RegExp(
      '(?<![\\w])${RegExp.escape(target.name)}(?![\\w])',
      caseSensitive: false,
    );
    final replacements = <({int start, int end, String replacement})>[];
    for (final match in pattern.allMatches(result)) {
      if (_overlapsAny(match.start, match.end, protected)) continue;
      replacements.add((
        start: match.start,
        end: match.end,
        replacement: formatWikiLink(kind: target.kind, name: target.name),
      ));
    }
    for (final replacement in replacements.reversed) {
      result = result.replaceRange(
        replacement.start,
        replacement.end,
        replacement.replacement,
      );
    }
  }
  return result;
}

List<({int start, int end})> _wikiLinkRanges(String text) {
  // Prefer embed spans (include leading `!`) so auto-link skips them.
  final ranges = <({int start, int end})>[
    for (final e in parseWikiEmbeds(text)) (start: e.start, end: e.end),
  ];
  for (final match in wikiLinkPattern.allMatches(text)) {
    if (_overlapsAny(match.start, match.end, ranges)) continue;
    ranges.add((start: match.start, end: match.end));
  }
  return ranges;
}

bool _overlapsAny(
  int start,
  int end,
  List<({int start, int end})> ranges,
) {
  for (final range in ranges) {
    if (start < range.end && end > range.start) return true;
  }
  return false;
}
