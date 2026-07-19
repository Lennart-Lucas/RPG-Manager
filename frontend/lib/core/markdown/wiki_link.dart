/// Wiki-style catalog references: `[[kind/name]]` or `[[kind/name|alias]]`.
library;

final RegExp wikiLinkPattern = RegExp(
  r'\[\[([^\]|/]+)/([^\]|]+)(?:\|([^\]]+))?\]\]',
);

class WikiLink {
  const WikiLink({
    required this.kind,
    required this.name,
    this.alias,
    required this.start,
    required this.end,
  });

  final String kind;
  final String name;
  final String? alias;
  final int start;
  final int end;

  String get reference => '$kind/$name';

  String get displayText =>
      (alias != null && alias!.isNotEmpty) ? alias! : name;

  String toMarkdown() {
    if (alias != null && alias!.isNotEmpty) {
      return '[[$kind/$name|$alias]]';
    }
    return '[[$kind/$name]]';
  }
}

class IncompleteWikiLink {
  const IncompleteWikiLink({
    required this.start,
    required this.query,
  });

  /// Index of the opening `[[`.
  final int start;

  /// Text typed after `[[` (may include a partial `kind/` prefix).
  final String query;
}

List<WikiLink> parseWikiLinks(String text) {
  final links = <WikiLink>[];
  for (final match in wikiLinkPattern.allMatches(text)) {
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

String formatWikiLink({
  required String kind,
  required String name,
  String? alias,
}) {
  if (alias != null && alias.isNotEmpty) {
    return '[[$kind/$name|$alias]]';
  }
  return '[[$kind/$name]]';
}

/// Finds an unfinished `[[…` at [cursor] (no closing `]]` yet).
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

  return IncompleteWikiLink(start: open, query: afterOpen);
}

/// Rewrites `[[kind/oldName]]` and `[[kind/oldName|alias]]` to [newName].
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
    '\\[\\[$escapedKind/$escapedOld(?:\\|([^\\]]+))?\\]\\]',
  );

  return text.replaceAllMapped(pattern, (match) {
    final alias = match.group(1);
    return formatWikiLink(kind: kind, name: newName, alias: alias);
  });
}

class _AutoLinkTarget {
  const _AutoLinkTarget({required this.kind, required this.name});

  final String kind;
  final String name;
}

/// Wraps plain-text mentions of [targets] as `[[kind/name]]`.
///
/// Longer names are applied first. Existing wiki links are left untouched.
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
  return [
    for (final match in wikiLinkPattern.allMatches(text))
      (start: match.start, end: match.end),
  ];
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
