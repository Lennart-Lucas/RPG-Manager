import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../markdown/wiki_link.dart';
import 'card_text_pagination.dart';

/// Lightweight markdown-ish body: bold/italic, lists, headings, tables, quotes,
/// wiki links, and `![[kind/id]]` embeds.
class SimpleCardRichText extends StatefulWidget {
  const SimpleCardRichText({
    super.key,
    required this.content,
    this.baseStyle,
    this.styleScale = 1.0,
    this.enableSelection = true,
    this.onWikiLinkTap,
    this.resolveWikiLinkLabel,
    this.resolveWikiEmbed,
    this.embedDepth = 0,
    this.maxEmbedDepth = 2,
  });

  final String content;
  final TextStyle? baseStyle;
  final double styleScale;
  final bool enableSelection;

  /// [kind] and [id] (or legacy name) from `[[kind/id]]`.
  final void Function(String kind, String id)? onWikiLinkTap;

  /// Resolves a live display name when a link has no alias.
  final Future<String?> Function(String kind, String id)? resolveWikiLinkLabel;

  /// Loads embed title + body for `![[kind/id]]`.
  /// [alias] is the optional display label from `![[kind/id|alias]]`.
  final Future<CatalogEmbedPayload?> Function(
    String kind,
    String id, {
    String? alias,
  })? resolveWikiEmbed;

  final int embedDepth;
  final int maxEmbedDepth;

  @override
  State<SimpleCardRichText> createState() => _SimpleCardRichTextState();
}

/// Resolved embed content for [SimpleCardRichText.resolveWikiEmbed].
class CatalogEmbedPayload {
  const CatalogEmbedPayload({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;
}

class _SimpleCardRichTextState extends State<SimpleCardRichText> {
  final List<TapGestureRecognizer> _recognizers = [];

  static final RegExp _bullet = RegExp(r'^(\s*)[-*]\s+(.*)$');
  static final RegExp _ordered = RegExp(r'^(\s*)(\d+)\.\s+(.*)$');
  static final RegExp _quoteLine = RegExp(r'^\s*>\s?(.*)$');
  static final RegExp _quoteAuthor = RegExp(r'^\s*-\s+(.+)$');
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
        oldWidget.onWikiLinkTap != widget.onWikiLinkTap ||
        oldWidget.resolveWikiLinkLabel != widget.resolveWikiLinkLabel ||
        oldWidget.resolveWikiEmbed != widget.resolveWikiEmbed) {
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

    final normalized = stripCardBreakMarkers(widget.content);
    if (normalized.isEmpty) {
      return const SizedBox.shrink();
    }

    final lines = normalized.split('\n');
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
      final quoteMatch = _quoteLine.firstMatch(line);
      if (quoteMatch != null) {
        final contents = <String>[];
        while (i < lines.length) {
          final raw = lines[i].replaceAll('\r', '');
          final match = _quoteLine.firstMatch(raw);
          if (match == null) break;
          contents.add(match.group(1) ?? '');
          i++;
        }
        blocks.add(_parseQuoteBlock(contents));
        continue;
      }
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
            _addLineOrEmbeds(blocks, raw);
          }
        }
        continue;
      }
      _addLineOrEmbeds(blocks, line);
      i++;
    }
    return blocks;
  }

  void _addLineOrEmbeds(List<_RichBlock> blocks, String line) {
    final embeds = parseWikiEmbeds(line);
    if (embeds.isEmpty) {
      blocks.add(_RichBlock.line(line));
      return;
    }
    var offset = 0;
    for (final embed in embeds) {
      if (embed.start > offset) {
        blocks.add(_RichBlock.line(line.substring(offset, embed.start)));
      }
      blocks.add(_RichBlock.embed(embed));
      offset = embed.end;
    }
    if (offset < line.length) {
      blocks.add(_RichBlock.line(line.substring(offset)));
    }
  }

  _RichBlock _parseQuoteBlock(List<String> contents) {
    String? author;
    var bodyLines = contents;
    if (contents.isNotEmpty) {
      final last = contents.last;
      final authorMatch = _quoteAuthor.firstMatch(last);
      if (authorMatch != null) {
        author = (authorMatch.group(1) ?? '').trim();
        if (author.isEmpty) {
          author = null;
        } else {
          bodyLines = contents.sublist(0, contents.length - 1);
        }
      }
    }
    final body = bodyLines
        .map((l) => l.trimRight())
        .join('\n')
        .trim();
    return _RichBlock.quote(body: body, author: author);
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

  /// Split on `|` but do not break wiki links / embeds (`[[…]]` / `![[…]]`),
  /// whose aliases also use `|`.
  List<String> _splitTableCells(String line) {
    var trimmed = line.trim();
    if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
    if (trimmed.endsWith('|')) trimmed = trimmed.substring(0, trimmed.length - 1);

    final cells = <String>[];
    final buf = StringBuffer();
    var i = 0;
    while (i < trimmed.length) {
      if (trimmed.startsWith('![[', i) || trimmed.startsWith('[[', i)) {
        final end = trimmed.indexOf(']]', i);
        if (end >= 0) {
          buf.write(trimmed.substring(i, end + 2));
          i = end + 2;
          continue;
        }
      }
      final ch = trimmed[i];
      if (ch == '|') {
        cells.add(buf.toString().trim());
        buf.clear();
        i++;
        continue;
      }
      buf.write(ch);
      i++;
    }
    cells.add(buf.toString().trim());
    return cells;
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
    if (block.isQuote) {
      return _quoteWidget(context, block, bodyStyle, linkStyle);
    }
    if (block.isEmbed) {
      return _embedWidget(context, block.embed!, bodyStyle, linkStyle);
    }
    return _lineBlock(context, block.line!, bodyStyle, linkStyle);
  }

  Widget _embedWidget(
    BuildContext context,
    WikiLink embed,
    TextStyle bodyStyle,
    TextStyle linkStyle,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final canExpand = widget.embedDepth < widget.maxEmbedDepth &&
        widget.resolveWikiEmbed != null;

    if (!canExpand) {
      return Text.rich(
        TextSpan(
          style: bodyStyle,
          children: _inlineSpans(
            formatWikiLink(
              kind: embed.kind,
              id: embed.id,
              alias: embed.alias,
            ),
            bodyStyle,
            linkStyle,
          ),
        ),
      );
    }

    return _WikiEmbedView(
      embed: embed,
      resolve: widget.resolveWikiEmbed!,
      resolveWikiLinkLabel: widget.resolveWikiLinkLabel,
      onWikiLinkTap: widget.onWikiLinkTap,
      styleScale: widget.styleScale,
      baseStyle: bodyStyle,
      linkStyle: linkStyle,
      embedDepth: widget.embedDepth,
      maxEmbedDepth: widget.maxEmbedDepth,
      borderColor: scheme.outlineVariant,
      surface: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
    );
  }

  Widget _quoteWidget(
    BuildContext context,
    _RichBlock block,
    TextStyle bodyStyle,
    TextStyle linkStyle,
  ) {
    final colors = Theme.of(context).colorScheme;
    final italicStyle = bodyStyle.copyWith(fontStyle: FontStyle.italic);
    final authorStyle = bodyStyle.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: (bodyStyle.fontSize ?? 14) * 0.92,
    );
    final pad = 10 * widget.styleScale;

    return Container(
      padding: EdgeInsets.fromLTRB(pad, pad * 0.7, pad, pad * 0.7),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: colors.outlineVariant,
            width: 3 * widget.styleScale,
          ),
        ),
        color: colors.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (block.quoteBody != null && block.quoteBody!.isNotEmpty)
            Text.rich(
              TextSpan(
                style: italicStyle,
                children: _inlineSpans(
                  block.quoteBody!,
                  italicStyle,
                  linkStyle.copyWith(fontStyle: FontStyle.italic),
                ),
              ),
            ),
          if (block.quoteAuthor != null && block.quoteAuthor!.isNotEmpty) ...[
            if (block.quoteBody != null && block.quoteBody!.isNotEmpty)
              SizedBox(height: 6 * widget.styleScale),
            Text(
              '- ${block.quoteAuthor}',
              style: authorStyle,
              textAlign: TextAlign.right,
            ),
          ],
        ],
      ),
    );
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
          ..onTap = () => widget.onWikiLinkTap!(link.kind, link.id);
        _recognizers.add(recognizer);
        out.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _WikiLinkLabel(
              link: link,
              style: linkStyle,
              resolveLabel: widget.resolveWikiLinkLabel,
              recognizer: recognizer,
            ),
          ),
        );
      } else {
        out.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: _WikiLinkLabel(
              link: link,
              style: linkStyle,
              resolveLabel: widget.resolveWikiLinkLabel,
            ),
          ),
        );
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
    this.quoteBody,
    this.quoteAuthor,
    this.embed,
  });

  const _RichBlock.line(String value) : this._(line: value);

  const _RichBlock.table({
    required List<String> headers,
    required List<List<String>> rows,
  }) : this._(headers: headers, rows: rows);

  const _RichBlock.quote({
    required String body,
    String? author,
  }) : this._(quoteBody: body, quoteAuthor: author);

  const _RichBlock.embed(WikiLink link) : this._(embed: link);

  final String? line;
  final List<String>? headers;
  final List<List<String>>? rows;
  final String? quoteBody;
  final String? quoteAuthor;
  final WikiLink? embed;

  bool get isTable => headers != null && rows != null;
  bool get isQuote => quoteBody != null;
  bool get isEmbed => embed != null;
}

class _WikiEmbedView extends StatefulWidget {
  const _WikiEmbedView({
    required this.embed,
    required this.resolve,
    required this.onWikiLinkTap,
    required this.styleScale,
    required this.baseStyle,
    required this.linkStyle,
    required this.embedDepth,
    required this.maxEmbedDepth,
    required this.borderColor,
    required this.surface,
    this.resolveWikiLinkLabel,
  });

  final WikiLink embed;
  final Future<CatalogEmbedPayload?> Function(
    String kind,
    String id, {
    String? alias,
  }) resolve;
  final Future<String?> Function(String kind, String id)? resolveWikiLinkLabel;
  final void Function(String kind, String id)? onWikiLinkTap;
  final double styleScale;
  final TextStyle baseStyle;
  final TextStyle linkStyle;
  final int embedDepth;
  final int maxEmbedDepth;
  final Color borderColor;
  final Color surface;

  @override
  State<_WikiEmbedView> createState() => _WikiEmbedViewState();
}

class _WikiEmbedViewState extends State<_WikiEmbedView> {
  late final Future<CatalogEmbedPayload?> _future = widget.resolve(
    widget.embed.kind,
    widget.embed.id,
    alias: widget.embed.alias,
  );

  @override
  Widget build(BuildContext context) {
    final pad = 10 * widget.styleScale;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.borderColor),
      ),
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: FutureBuilder<CatalogEmbedPayload?>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return SizedBox(
                height: 28 * widget.styleScale,
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final content = snapshot.data;
            // Prefer authored alias; otherwise use resolved embed title.
            final title = widget.embed.hasAlias
                ? widget.embed.displayText
                : (content?.title ?? widget.embed.id);
            final muted = widget.baseStyle.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: widget.onWikiLinkTap == null
                      ? null
                      : () => widget.onWikiLinkTap!(
                            widget.embed.kind,
                            widget.embed.id,
                          ),
                  child: Text(
                    title,
                    style: widget.linkStyle.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (content == null) ...[
                  SizedBox(height: 6 * widget.styleScale),
                  Text(
                    'Could not load ${widget.embed.reference}',
                    style: muted,
                  ),
                ] else if (content.body.trim().isNotEmpty) ...[
                  SizedBox(height: 8 * widget.styleScale),
                  SimpleCardRichText(
                    content: content.body,
                    baseStyle: widget.baseStyle,
                    styleScale: widget.styleScale,
                    enableSelection: false,
                    onWikiLinkTap: widget.onWikiLinkTap,
                    resolveWikiLinkLabel: widget.resolveWikiLinkLabel,
                    resolveWikiEmbed: widget.resolve,
                    embedDepth: widget.embedDepth + 1,
                    maxEmbedDepth: widget.maxEmbedDepth,
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Shows alias immediately, or resolves the live record name for bare id links.
class _WikiLinkLabel extends StatefulWidget {
  const _WikiLinkLabel({
    required this.link,
    required this.style,
    this.resolveLabel,
    this.recognizer,
  });

  final WikiLink link;
  final TextStyle style;
  final Future<String?> Function(String kind, String id)? resolveLabel;
  final TapGestureRecognizer? recognizer;

  @override
  State<_WikiLinkLabel> createState() => _WikiLinkLabelState();
}

class _WikiLinkLabelState extends State<_WikiLinkLabel> {
  late String _text;

  @override
  void initState() {
    super.initState();
    _text = widget.link.displayText;
    _loadLabel();
  }

  @override
  void didUpdateWidget(covariant _WikiLinkLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.link.kind != widget.link.kind ||
        oldWidget.link.id != widget.link.id ||
        oldWidget.link.alias != widget.link.alias ||
        oldWidget.resolveLabel != widget.resolveLabel) {
      _text = widget.link.displayText;
      _loadLabel();
    }
  }

  Future<void> _loadLabel() async {
    if (widget.link.hasAlias) return;
    final resolve = widget.resolveLabel;
    if (resolve == null) return;
    final name = await resolve(widget.link.kind, widget.link.id);
    if (!mounted || name == null || name.isEmpty) return;
    if (name != _text) setState(() => _text = name);
  }

  @override
  Widget build(BuildContext context) {
    final child = Text(_text, style: widget.style);
    final recognizer = widget.recognizer;
    if (recognizer == null) return child;
    return GestureDetector(
      onTap: recognizer.onTap,
      child: child,
    );
  }
}
