List<String> paginateCardBodyText(
  String input, {
  int preferredCharsPerCard = 900,
  int maxCharsPerCard = 1300,
}) {
  final normalized = input.trim();
  if (normalized.isEmpty) return const [''];
  final chunks = <String>[];
  var start = 0;
  final total = normalized.length;

  while (start < total) {
    final remaining = total - start;
    if (remaining <= maxCharsPerCard) {
      chunks.add(normalized.substring(start).trim());
      break;
    }

    final idealEnd = (start + preferredCharsPerCard).clamp(start + 1, total);
    final hardEnd = (start + maxCharsPerCard).clamp(start + 1, total);

    var splitAt = _findBestBreak(normalized, start, idealEnd, hardEnd);
    if (splitAt <= start) splitAt = hardEnd;

    chunks.add(normalized.substring(start, splitAt).trim());
    start = splitAt;
    while (start < total && normalized[start].trim().isEmpty) {
      start++;
    }
  }

  return chunks.where((c) => c.isNotEmpty).toList(growable: false);
}

bool _looksLikeTableLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty || !trimmed.contains('|')) return false;
  var working = trimmed;
  if (working.startsWith('|')) working = working.substring(1);
  if (working.endsWith('|')) {
    working = working.substring(0, working.length - 1);
  }
  return working.split('|').length >= 2;
}

/// Prefer not to split inside a contiguous markdown table.
int? _tableAwareBreak(String text, int start, int idealEnd, int hardEnd) {
  final region = text.substring(start, hardEnd);
  final lines = region.split('\n');
  var offset = start;
  var tableStart = -1;
  var tableEnd = -1;

  for (final line in lines) {
    final lineStart = offset;
    final lineEnd = offset + line.length;
    final isTable = _looksLikeTableLine(line);
    if (isTable) {
      if (tableStart < 0) tableStart = lineStart;
      tableEnd = (lineEnd < hardEnd && text[lineEnd] == '\n')
          ? lineEnd + 1
          : lineEnd;
    } else if (tableStart >= 0) {
      // Finished a table block that intersects the candidate window.
      if (tableStart < idealEnd && tableEnd > idealEnd) {
        if (tableEnd <= hardEnd && tableEnd > start) return tableEnd;
        if (tableStart > start) return tableStart;
      }
      tableStart = -1;
      tableEnd = -1;
    }
    offset = lineEnd + 1;
  }
  if (tableStart >= 0 && tableStart < idealEnd && tableEnd > idealEnd) {
    if (tableEnd <= hardEnd && tableEnd > start) return tableEnd;
    if (tableStart > start) return tableStart;
  }
  return null;
}

bool _isWordChar(String ch) {
  if (ch.isEmpty) return false;
  final code = ch.codeUnitAt(0);
  final isAz = (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  final isDigit = code >= 48 && code <= 57;
  return isAz || isDigit || ch == '_' || ch == "'";
}

/// Ranges of inline markdown that should not be split across cards.
List<({int start, int end})> _protectedInlineSpans(String text) {
  final spans = <({int start, int end})>[];

  void addDelimited(String delimiter) {
    var i = 0;
    while (i < text.length) {
      final open = text.indexOf(delimiter, i);
      if (open < 0) break;
      final close = text.indexOf(delimiter, open + delimiter.length);
      if (close < 0) {
        spans.add((start: open, end: text.length));
        break;
      }
      spans.add((start: open, end: close + delimiter.length));
      i = close + delimiter.length;
    }
  }

  addDelimited('**');
  addDelimited('__');
  addDelimited('`');

  // Wiki links: [[kind/name]] or [[kind/name|label]]
  var i = 0;
  while (i < text.length) {
    final open = text.indexOf('[[', i);
    if (open < 0) break;
    final close = text.indexOf(']]', open + 2);
    if (close < 0) {
      spans.add((start: open, end: text.length));
      break;
    }
    spans.add((start: open, end: close + 2));
    i = close + 2;
  }

  spans.sort((a, b) => a.start.compareTo(b.start));
  return spans;
}

({int start, int end})? _spanContaining(
  List<({int start, int end})> spans,
  int index,
) {
  for (final span in spans) {
    if (index > span.start && index < span.end) return span;
  }
  return null;
}

bool _isSafeBreakAt(
  String text,
  int breakAt,
  List<({int start, int end})> spans,
) {
  if (breakAt <= 0 || breakAt >= text.length) return true;
  if (_spanContaining(spans, breakAt) != null) return false;
  // Keep whole words together.
  if (_isWordChar(text[breakAt - 1]) && _isWordChar(text[breakAt])) {
    return false;
  }
  return true;
}

/// Snap an unsafe break to before the protected span (move whole span next).
int _snapBreakOutsideSpan(
  String text,
  int start,
  int breakAt,
  int hardEnd,
  List<({int start, int end})> spans,
) {
  final span = _spanContaining(spans, breakAt);
  if (span == null) return breakAt;
  if (span.start > start) return span.start;
  if (span.end <= hardEnd && span.end > start) return span.end;
  return breakAt;
}

int _scoreBreakAfter(String text, int index) {
  // Score the character at [index]; caller breaks after it (at index + 1).
  final ch = text[index];
  if (ch == '\n') {
    final prevNewline = index > 0 && text[index - 1] == '\n';
    final nextNewline =
        index + 1 < text.length && text[index + 1] == '\n';
    if (prevNewline || nextNewline) return 8; // paragraph boundary
    return 6; // line / soft paragraph break
  }
  if (ch == '.' || ch == '!' || ch == '?') return 4;
  if (ch == ';' || ch == ':' || ch == ',') return 3;
  if (ch.trim().isEmpty) return 2;
  return 0;
}

int _findBestBreak(String text, int start, int idealEnd, int hardEnd) {
  final tableBreak = _tableAwareBreak(text, start, idealEnd, hardEnd);
  if (tableBreak != null) return tableBreak;

  final spans = _protectedInlineSpans(text);

  int? closestBreak({
    required int minScore,
    int? maxScore,
  }) {
    var bestIndex = -1;
    var bestDist = 1 << 30;
    for (var i = start; i < hardEnd; i++) {
      final score = _scoreBreakAfter(text, i);
      if (score < minScore) continue;
      if (maxScore != null && score > maxScore) continue;
      final breakAt = i + 1;
      if (breakAt <= start || breakAt > hardEnd) continue;
      if (!_isSafeBreakAt(text, breakAt, spans)) continue;
      final dist = (breakAt - idealEnd).abs();
      // Prefer not going far past the ideal when distances are close.
      final pastPenalty = breakAt > idealEnd ? (breakAt - idealEnd) ~/ 4 : 0;
      final weighted = dist + pastPenalty;
      if (weighted < bestDist) {
        bestDist = weighted;
        bestIndex = breakAt;
      }
    }
    return bestIndex > start ? bestIndex : null;
  }

  // 1) Prefer a paragraph break (\n\n) closest to the ideal length.
  final paragraph = closestBreak(minScore: 8);
  if (paragraph != null) {
    return _snapBreakOutsideSpan(text, start, paragraph, hardEnd, spans);
  }

  // 2) Prefer any newline.
  final newline = closestBreak(minScore: 6, maxScore: 6);
  if (newline != null) {
    return _snapBreakOutsideSpan(text, start, newline, hardEnd, spans);
  }

  // 3) Sentence / punctuation / whitespace near ideal end.
  final soft = closestBreak(minScore: 2, maxScore: 5);
  if (soft != null) {
    return _snapBreakOutsideSpan(text, start, soft, hardEnd, spans);
  }

  // 4) Last resort: hard end, snapped outside protected spans / mid-word.
  var fallback = hardEnd;
  fallback = _snapBreakOutsideSpan(text, start, fallback, hardEnd, spans);
  if (!_isSafeBreakAt(text, fallback, spans)) {
    for (var i = fallback - 1; i > start; i--) {
      if (_isSafeBreakAt(text, i, spans)) return i;
    }
  }
  return fallback;
}
