import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../markdown/wiki_link.dart';

/// Lightweight markdown-ish body: bold/italic, lists, headings, tables, and
/// wiki links.
class SimpleCardRichText extends StatefulWidget {
  const SimpleCardRichText({
    super.key,
    required this.content,
    this.baseStyle,
    this.styleScale = 1.0,
    this.enableSelection = true,
    this.onWikiLinkTap,
  });

  final String content;
  final TextStyle? baseStyle;
  final double styleScale;
  final bool enableSelection;
  final void Function(String kind, String name)? onWikiLinkTap;

  @override
  State<SimpleCardRichText> createState() => _SimpleCardRichTextState();
}

class _SimpleCardRichTextState extends State<SimpleCardRichText> {
  final List<TapGestureRecognizer> _recognizers = [];

  static final RegExp _bullet = RegExp(r'^(\s*)[-*]\s+(.*)$');
  static final RegExp _ordered = RegExp(r'^(\s*)(\d+)\.\s+(.*)$');
  static final RegExp _underline =
      RegExp(r'<u>(.+?)</u>', caseSensitive: false);
  static final RegExp _tableSepCell = RegExp(r'^:?-{3,}:?$');

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SimpleCardRichText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content ||
        oldWidget.onWikiLinkTap != widget.onWikiLinkTap) {
      for (final r in _recognizers) {
        r.dispose();
      }
      _recognizers.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodyStyle =
        widget.baseStyle ?? theme.textTheme.bodyLarge ?? const TextStyle();
    final linkStyle = bodyStyle.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w600,
      decoration: widget.onWikiLinkTap == null ? null : TextDecoration.underline,
      decorationColor: theme.colorScheme.primary,
    );

    final normalized = widget.content.trim();
    if (normalized.isEmpty) {
      return const SizedBox.shrink();
    }

    final lines = widget.content.split('\n');
    final blocks = _parseBlocks(lines);
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          _blockWidget(context, blocks[i], bodyStyle, linkStyle),
          if (i != blocks.length - 1) SizedBox(height: 6 * widget.styleScale),
        ],
      ],
    );
    if (widget.enableSelection && widget.onWikiLinkTap == null) {
      return SelectionArea(child: body);
    }
    return body;
  }

  List<_RichBlock> _parseBlocks(List<String> lines) {
    final blocks = <_RichBlock>[];
    var i = 0;
    while (i < lines.length) {
      final line = lines[i].replaceAll('\r', '');
      if (_looksLikeTableRow(line)) {
        final tableLines = <String>[];
        while (i < lines.length &&
            _looksLikeTableRow(lines[i].replaceAll('\r', ''))) {
          tableLines.add(lines[i].replaceAll('\r', ''));
          i++;
        }
        final table = _tryParseTable(tableLines);
        if (table != null) {
          blocks.add(table);
        } else {
          for (final raw in tableLines) {
            blocks.add(_RichBlock.line(raw));
          }
        }
        continue;
      }
      blocks.add(_RichBlock.line(line));
      i++;
    }
    return blocks;
  }

  bool _looksLikeTableRow(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    if (!trimmed.contains('|')) return false;
    // Avoid treating plain prose that happens to include a pipe as a table.
    final cells = _splitTableCells(trimmed);
    return cells.length >= 2;
  }

  bool _isSeparatorRow(List<String> cells) {
    if (cells.isEmpty) return false;
    return cells.every((cell) => _tableSepCell.hasMatch(cell.trim()));
  }

  List<String> _splitTableCells(String line) {
    var trimmed = line.trim();
    if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
    if (trimmed.endsWith('|')) trimmed = trimmed.substring(0, trimmed.length - 1);
    return trimmed.split('|').map((c) => c.trim()).toList();
  }

  _RichBlock? _tryParseTable(List<String> tableLines) {
    if (tableLines.length < 2) return null;
    final rows = tableLines.map(_splitTableCells).toList();
    var headerIndex = 0;
    var separatorIndex = -1;
    for (var i = 0; i < rows.length; i++) {
      if (_isSeparatorRow(rows[i])) {
        separatorIndex = i;
        break;
      }
    }
    if (separatorIndex <= 0) {
      // Allow a body-only pipe grid without a markdown separator.
      final colCount = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);
      if (colCount < 2) return null;
      return _RichBlock.table(
        headers: const [],
        rows: [
          for (final row in rows) _padRow(row, colCount),
        ],
      );
    }
    headerIndex = separatorIndex - 1;
    final headers = rows[headerIndex];
    final colCount = headers.length;
    if (colCount < 1) return null;
    final body = <List<String>>[];
    for (var i = separatorIndex + 1; i < rows.length; i++) {
      if (_isSeparatorRow(rows[i])) continue;
      body.add(_padRow(rows[i], colCount));
    }
    return _RichBlock.table(
      headers: _padRow(headers, colCount),
      rows: body,
    );
  }

  List<String> _padRow(List<String> row, int colCount) {
    if (row.length == colCount) return row;
    if (row.length > colCount) return row.sublist(0, colCount);
    return [...row, for (var i = row.length; i < colCount; i++) ''];
  }

  Widget _blockWidget(
    BuildContext context,
    _RichBlock block,
    TextStyle bodyStyle,
    TextStyle linkStyle,
  ) {
    if (block.isTable) {
      return _tableWidget(context, block, bodyStyle, linkStyle);
    }
    return _lineBlock(context, block.line!, bodyStyle, linkStyle);
  }

  Widget _tableWidget(
    BuildContext context,
    _RichBlock block,
    TextStyle bodyStyle,
    TextStyle linkStyle,
  ) {
    final colors = Theme.of(context).colorScheme;
    final headers = block.headers!;
    final rows = block.rows!;
    final colCount = headers.isNotEmpty
        ? headers.length
        : (rows.isEmpty ? 0 : rows.first.length);
    if (colCount == 0) return const SizedBox.shrink();

    final cellPad = EdgeInsets.symmetric(
      horizontal: 6 * widget.styleScale,
      vertical: 4 * widget.styleScale,
    );
    final borderColor = colors.outlineVariant.withValues(alpha: 0.85);
    final headerBg = colors.surfaceContainerHigh;
    // Opaque zebra fills blended onto the card body surface so both bands
    // stay visible and distinct on light and dark themes.
    final rowBase = colors.surfaceContainerLowest;
    final rowEvenBg = Color.alphaBlend(
      colors.onSurface.withValues(alpha: 0.06),
      rowBase,
    );
    final rowOddBg = Color.alphaBlend(
      colors.onSurface.withValues(alpha: 0.14),
      rowBase,
    );
    final headerStyle = bodyStyle.copyWith(fontWeight: FontWeight.w700);

    Widget cellText(String text, TextStyle style) {
      return Text.rich(
        TextSpan(
          style: style,
          children: _inlineSpans(text, style, linkStyle),
        ),
      );
    }

    Widget paddedCell(String text, TextStyle style, Color bg) {
      return ColoredBox(
        color: bg,
        child: Padding(
          padding: cellPad,
          child: cellText(text, style),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6 * widget.styleScale),
      child: Table(
        border: TableBorder.all(color: borderColor, width: 1),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          if (headers.isNotEmpty)
            TableRow(
              children: [
                for (final header in headers)
                  paddedCell(header, headerStyle, headerBg),
              ],
            ),
          for (var r = 0; r < rows.length; r++)
            TableRow(
              children: [
                for (final cell in rows[r])
                  paddedCell(
                    cell,
                    bodyStyle,
                    r.isEven ? rowEvenBg : rowOddBg,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _lineBlock(
    BuildContext context,
    String rawLine,
    TextStyle bodyStyle,
    TextStyle linkStyle,
  ) {
    final line = rawLine.replaceAll('\r', '');
    final isH3 = line.startsWith('### ');
    final isH2 = !isH3 && line.startsWith('## ');
    final isH1 = !isH3 && !isH2 && line.startsWith('# ');
    final workingHeading = isH3
        ? line.substring(4)
        : isH2
            ? line.substring(3)
            : isH1
                ? line.substring(2)
                : null;

    if (workingHeading != null) {
      final textTheme = Theme.of(context).textTheme;
      final rawHeading = (isH1
              ? textTheme.headlineMedium
              : isH2
                  ? textTheme.headlineSmall
                  : textTheme.titleLarge) ??
          bodyStyle;
      final headingStyle = rawHeading.fontSize != null
          ? rawHeading.copyWith(
              fontSize: rawHeading.fontSize! * widget.styleScale,
            )
          : rawHeading;
      return Text.rich(
        TextSpan(
          style: headingStyle,
          children: _inlineSpans(workingHeading, headingStyle, linkStyle),
        ),
      );
    }

    final bullet = _bullet.firstMatch(line);
    if (bullet != null) {
      final item = bullet.group(2) ?? '';
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: bodyStyle),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: bodyStyle,
                children: _inlineSpans(item, bodyStyle, linkStyle),
              ),
            ),
          ),
        ],
      );
    }

    final ordered = _ordered.firstMatch(line);
    if (ordered != null) {
      final index = ordered.group(2) ?? '1';
      final item = ordered.group(3) ?? '';
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$index.',
              style: bodyStyle,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: bodyStyle,
                children: _inlineSpans(item, bodyStyle, linkStyle),
              ),
            ),
          ),
        ],
      );
    }

    return Text.rich(
      TextSpan(
        style: bodyStyle,
        children: _inlineSpans(line, bodyStyle, linkStyle),
      ),
    );
  }

  List<InlineSpan> _inlineSpans(
    String segment,
    TextStyle baseStyle,
    TextStyle linkStyle,
  ) {
    final links = parseWikiLinks(segment);
    if (links.isEmpty) {
      return _markdownSpans(segment, baseStyle);
    }
    final out = <InlineSpan>[];
    var offset = 0;
    for (final link in links) {
      if (link.start > offset) {
        out.addAll(
          _markdownSpans(segment.substring(offset, link.start), baseStyle),
        );
      }
      if (widget.onWikiLinkTap != null) {
        final recognizer = TapGestureRecognizer()
          ..onTap = () => widget.onWikiLinkTap!(link.kind, link.name);
        _recognizers.add(recognizer);
        out.add(
          TextSpan(
            text: link.displayText,
            style: linkStyle,
            recognizer: recognizer,
          ),
        );
      } else {
        out.add(TextSpan(text: link.displayText, style: linkStyle));
      }
      offset = link.end;
    }
    if (offset < segment.length) {
      out.addAll(_markdownSpans(segment.substring(offset), baseStyle));
    }
    return out;
  }

  List<InlineSpan> _markdownSpans(String text, TextStyle base) {
    if (text.isEmpty) return const [];
    final out = <InlineSpan>[];
    var cursor = 0;
    for (final match in _underline.allMatches(text)) {
      if (match.start > cursor) {
        out.addAll(_boldItalicSpans(text.substring(cursor, match.start), base));
      }
      out.addAll(
        _boldItalicSpans(
          match.group(1) ?? '',
          base.copyWith(decoration: TextDecoration.underline),
        ),
      );
      cursor = match.end;
    }
    if (cursor < text.length) {
      out.addAll(_boldItalicSpans(text.substring(cursor), base));
    }
    return out;
  }

  List<InlineSpan> _boldItalicSpans(String text, TextStyle base) {
    if (text.isEmpty) return const [];
    final out = <InlineSpan>[];
    var cursor = 0;
    final combined = RegExp(
      r'\*\*\*(.+?)\*\*\*|\*\*(.+?)\*\*|(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)',
    );
    for (final match in combined.allMatches(text)) {
      if (match.start > cursor) {
        out.add(TextSpan(text: text.substring(cursor, match.start), style: base));
      }
      if (match.group(1) != null) {
        out.add(
          TextSpan(
            text: match.group(1),
            style: base.copyWith(
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else if (match.group(2) != null) {
        out.add(
          TextSpan(
            text: match.group(2),
            style: base.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (match.group(3) != null) {
        out.add(
          TextSpan(
            text: match.group(3),
            style: base.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      out.add(TextSpan(text: text.substring(cursor), style: base));
    }
    return out;
  }
}

class _RichBlock {
  const _RichBlock._({
    this.line,
    this.headers,
    this.rows,
  });

  const _RichBlock.line(String value)
      : this._(line: value);

  const _RichBlock.table({
    required List<String> headers,
    required List<List<String>> rows,
  }) : this._(headers: headers, rows: rows);

  final String? line;
  final List<String>? headers;
  final List<List<String>>? rows;

  bool get isTable => headers != null && rows != null;
}
