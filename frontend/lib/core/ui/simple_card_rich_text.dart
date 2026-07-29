import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../markdown/wiki_link.dart';
/// Lightweight markdown-ish body: bold/italic, lists, headings, and wiki links.
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
  static final RegExp _underline = RegExp(r'<u>(.+?)</u>', caseSensitive: false);

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
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          _lineBlock(context, lines[i], bodyStyle, linkStyle),
          if (i != lines.length - 1) SizedBox(height: 6 * widget.styleScale),
        ],
      ],
    );
    if (widget.enableSelection && widget.onWikiLinkTap == null) {
      return SelectionArea(child: body);
    }
    return body;
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
