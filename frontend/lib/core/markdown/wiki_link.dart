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
