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

int _findBestBreak(String text, int start, int idealEnd, int hardEnd) {
  final tableBreak = _tableAwareBreak(text, start, idealEnd, hardEnd);
  if (tableBreak != null) return tableBreak;

  int scoreAt(int i) {
    final ch = text[i];
    if (ch == '\n') return 5;
    if (ch == '.' || ch == '!' || ch == '?') return 4;
    if (ch == ';' || ch == ':' || ch == ',') return 3;
    if (ch.trim().isEmpty) return 2;
    return 0;
  }

  var bestIndex = -1;
  var bestScore = -1;
  for (var i = idealEnd - 1; i >= start; i--) {
    final score = scoreAt(i);
    if (score > bestScore) {
      bestScore = score;
      bestIndex = i + 1;
      if (score >= 4) break;
    }
    if (i <= hardEnd - (hardEnd - start) ~/ 3 && bestScore >= 2) {
      break;
    }
  }

  if (bestIndex > start && bestIndex <= hardEnd) return bestIndex;

  for (var i = hardEnd - 1; i >= start; i--) {
    if (text[i].trim().isEmpty) return i + 1;
  }
  return hardEnd;
}
