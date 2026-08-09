import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/dm_tools/resources/ui/resource_form_helpers.dart';
import '../markdown/wiki_link.dart';
import 'card_text_pagination.dart';

/// A catalog record that can be inserted as `[[kind/name]]`.
class CatalogLinkTarget {
  const CatalogLinkTarget({
    required this.id,
    required this.kind,
    required this.name,
    this.snippet,
  });

  final int id;
  final String kind;
  final String name;

  /// Plain-text excerpt when the hit matched markdown content, not the name.
  final String? snippet;

  factory CatalogLinkTarget.fromJson(Map<String, dynamic> json) {
    final rawSnippet = json['snippet'];
    return CatalogLinkTarget(
      id: json['id'] as int,
      kind: json['kind'] as String,
      name: json['name'] as String,
      snippet: rawSnippet is String && rawSnippet.trim().isNotEmpty
          ? rawSnippet.trim()
          : null,
    );
  }
}

typedef CatalogLinkSearch = Future<List<CatalogLinkTarget>> Function(
  String query,
);

typedef CatalogAutoLinkLoader = Future<List<CatalogLinkTarget>> Function();

/// Multiline markdown editor with a formatting toolbar and `[[` wiki-link
/// autocomplete. Stores raw markdown text.
class MarkdownFormField extends StatefulWidget {
  const MarkdownFormField({
    super.key,
    this.controller,
    this.initialValue,
    required this.label,
    this.hintText,
    this.minLines = 4,
    this.maxLines = 12,
    this.searchLinks,
    this.loadAutoLinkTargets,
    this.searchDebounce = const Duration(milliseconds: 200),
    this.validator,
    this.onChanged,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.enableCardBreak = false,
  }) : assert(
          controller == null || initialValue == null,
          'Provide either a controller or an initialValue, not both.',
        );

  final TextEditingController? controller;
  final String? initialValue;
  final String label;
  final String? hintText;
  final int minLines;
  final int maxLines;
  final CatalogLinkSearch? searchLinks;
  /// Records used by the auto-link toolbar action (e.g. conditions + damage types).
  final CatalogAutoLinkLoader? loadAutoLinkTargets;
  final Duration searchDebounce;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode autovalidateMode;

  /// Shows a toolbar action that inserts an explicit printable-card page break.
  final bool enableCardBreak;

  @override
  State<MarkdownFormField> createState() => _MarkdownFormFieldState();
}

class _MarkdownFormFieldState extends State<MarkdownFormField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey<FormFieldState<String>> _fieldKey =
      GlobalKey<FormFieldState<String>>();
  OverlayEntry? _overlayEntry;
  List<CatalogLinkTarget> _suggestions = const [];
  IncompleteWikiLink? _incomplete;
  Timer? _debounce;
  bool _ownsController = false;
  bool _autoLinking = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _ownsController = true;
      _controller = TextEditingController(text: widget.initialValue ?? '');
    }
    _focusNode = FocusNode()..addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant MarkdownFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onTextChanged);
      if (_ownsController) {
        _controller.dispose();
      }
      if (widget.controller != null) {
        _ownsController = false;
        _controller = widget.controller!;
      } else {
        _ownsController = true;
        _controller = TextEditingController(text: widget.initialValue ?? '');
      }
      _controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) {
      // Defer so suggestion pointer-down/tap can insert before overlay is torn down.
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        if (!_focusNode.hasFocus) {
          _removeOverlay();
        }
      });
    }
  }

  void _onTextChanged() {
    _fieldKey.currentState?.didChange(_controller.text);
    widget.onChanged?.call(_controller.text);
    _scheduleLinkSearch();
  }

  void _scheduleLinkSearch() {
    _debounce?.cancel();
    final search = widget.searchLinks;
    if (search == null) {
      _removeOverlay();
      return;
    }

    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) {
      _removeOverlay();
      return;
    }

    final incomplete = findIncompleteWikiLink(_controller.text, cursor);
    _incomplete = incomplete;
    if (incomplete == null) {
      _removeOverlay();
      return;
    }

    final query = incomplete.query;
    final start = incomplete.start;
    _debounce = Timer(widget.searchDebounce, () async {
      final results = await search(query);
      if (!mounted) return;
      final currentCursor = _controller.selection.baseOffset;
      final still = findIncompleteWikiLink(_controller.text, currentCursor);
      if (still == null || still.start != start) {
        _removeOverlay();
        return;
      }
      setState(() => _suggestions = results);
      _showOverlay();
    });
  }

  void _showOverlay() {
    _removeOverlay();
    if (_suggestions.isEmpty || _incomplete == null) return;

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Positioned(
          width: 320,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, 8),
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            child: Material(
              elevation: 6,
              color: scheme.surface,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final item = _suggestions[index];
                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (_) => _insertLink(item),
                      child: ListTile(
                        dense: true,
                        title: Text(item.name),
                        subtitle: Text(item.kind),
                        onTap: () => _insertLink(item),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _insertLink(CatalogLinkTarget target) {
    final incomplete = _incomplete;
    if (incomplete == null) return;

    final text = _controller.text;
    var cursor = _controller.selection.baseOffset;
    // After overlay tap, selection can collapse to -1; use end of incomplete query.
    if (cursor < incomplete.start) {
      cursor = incomplete.start + incomplete.query.length;
    }
    if (cursor < incomplete.start) return;
    // Clamp to text length in case focus already mutated selection.
    if (cursor > text.length) cursor = text.length;

    final insertion = formatWikiLink(
      kind: target.kind,
      id: '${target.id}',
      embed: incomplete.isEmbed,
    );
    final newText = text.replaceRange(incomplete.start, cursor, insertion);
    final newOffset = incomplete.start + insertion.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    _incomplete = null;
    _removeOverlay();
    _focusNode.requestFocus();
  }

  void _wrapSelection({
    required String prefix,
    required String suffix,
    String placeholder = 'text',
  }) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start;
    final end = selection.end;
    if (start < 0 || end < 0) return;

    if (start == end) {
      final inserted = '$prefix$placeholder$suffix';
      final newText = text.replaceRange(start, end, inserted);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: start + prefix.length,
          extentOffset: start + prefix.length + placeholder.length,
        ),
      );
    } else {
      final selected = text.substring(start, end);
      final inserted = '$prefix$selected$suffix';
      final newText = text.replaceRange(start, end, inserted);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + inserted.length),
      );
    }
    _focusNode.requestFocus();
  }

  void _toggleLinePrefix({required bool numbered}) {
    final text = _controller.text;
    final selection = _controller.selection;
    if (selection.start < 0) return;

    final lineStart = text.lastIndexOf('\n', selection.start - 1) + 1;
    var lineEnd = text.indexOf('\n', selection.start);
    if (lineEnd < 0) lineEnd = text.length;

    final line = text.substring(lineStart, lineEnd);
    final bullet = numbered ? '1. ' : '- ';
    final newLine = line.startsWith(bullet)
        ? line.substring(bullet.length)
        : '$bullet$line';
    final newText = text.replaceRange(lineStart, lineEnd, newLine);
    final delta = newLine.length - line.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (selection.baseOffset + delta).clamp(0, newText.length),
      ),
    );
    _focusNode.requestFocus();
  }

  void _insertTable() {
    const table = '| Header | Header |\n'
        '| --- | --- |\n'
        '| Cell | Cell |\n'
        '| Cell | Cell |';
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? start : selection.end;

    final before = start > 0 && text[start - 1] != '\n' ? '\n' : '';
    final after = end < text.length && text[end] != '\n' ? '\n' : '';
    final inserted = '$before$table$after';
    final newText = text.replaceRange(start, end, inserted);
    // Select first "Header"
    final headerOffset = start + before.length + 2;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: headerOffset,
        extentOffset: headerOffset + 'Header'.length,
      ),
    );
    _focusNode.requestFocus();
  }

  void _insertQuote() {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? start : selection.end;

    final before = start > 0 && text[start - 1] != '\n' ? '\n' : '';
    final after = end < text.length && text[end] != '\n' ? '\n' : '';

    if (start != end) {
      final selected = text.substring(start, end);
      final quotedLines = selected.split('\n').map((line) {
        final trimmed = line.trimRight();
        if (trimmed.isEmpty) return '>';
        if (RegExp(r'^\s*>\s?').hasMatch(trimmed)) return trimmed;
        return '> $trimmed';
      }).join('\n');
      final inserted = '$before$quotedLines$after';
      final newText = text.replaceRange(start, end, inserted);
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: start + inserted.length,
        ),
      );
      _focusNode.requestFocus();
      return;
    }

    const placeholder = 'quote';
    final block = '> $placeholder\n> - Author';
    final inserted = '$before$block$after';
    final newText = text.replaceRange(start, end, inserted);
    final quoteOffset = start + before.length + 2;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection(
        baseOffset: quoteOffset,
        extentOffset: quoteOffset + placeholder.length,
      ),
    );
    _focusNode.requestFocus();
  }

  void _insertCardBreak() {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? start : selection.end;

    final needsLeadingNewline = start > 0 && text[start - 1] != '\n';
    final needsTrailingNewline = end >= text.length || text[end] != '\n';
    final inserted = '${needsLeadingNewline ? '\n' : ''}'
        '$kCardBreakMarker'
        '${needsTrailingNewline ? '\n' : ''}';
    final newText = text.replaceRange(start, end, inserted);
    final newOffset = start + inserted.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
    _focusNode.requestFocus();
  }

  Future<void> _autoLink() async {
    final loader = widget.loadAutoLinkTargets;
    if (loader == null || _autoLinking) return;

    setState(() => _autoLinking = true);
    try {
      final targets = await loader();
      if (!mounted) return;
      final linked = autoLinkCatalogNames(
        _controller.text,
        targets: targets.map(
          (t) => (kind: t.kind, id: '${t.id}', name: t.name),
        ),
      );
      if (linked == _controller.text) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('No new links found')),
        );
        return;
      }
      final cursor = _controller.selection.baseOffset;
      _controller.value = TextEditingValue(
        text: linked,
        selection: TextSelection.collapsed(
          offset: cursor.clamp(0, linked.length),
        ),
      );
      _focusNode.requestFocus();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not auto-link records')),
      );
    } finally {
      if (mounted) setState(() => _autoLinking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      key: _fieldKey,
      initialValue: _controller.text,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toolbar(
              autoLinkEnabled: widget.loadAutoLinkTargets != null,
              autoLinking: _autoLinking,
              cardBreakEnabled: widget.enableCardBreak,
              onBold: () => _wrapSelection(prefix: '**', suffix: '**'),
              onItalic: () => _wrapSelection(prefix: '*', suffix: '*'),
              onUnderline: () =>
                  _wrapSelection(prefix: '<u>', suffix: '</u>'),
              onBullet: () => _toggleLinePrefix(numbered: false),
              onNumbered: () => _toggleLinePrefix(numbered: true),
              onQuote: _insertQuote,
              onTable: _insertTable,
              onCardBreak: _insertCardBreak,
              onAutoLink: _autoLink,
            ),
            const SizedBox(height: 8),
            CompositedTransformTarget(
              link: _layerLink,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: widget.label,
                  hintText: widget.hintText,
                ).copyWith(errorText: field.errorText),
                minLines: widget.minLines,
                maxLines: widget.maxLines,
                onChanged: (value) => field.didChange(value),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onBullet,
    required this.onNumbered,
    required this.onQuote,
    required this.onTable,
    required this.onCardBreak,
    required this.onAutoLink,
    required this.autoLinkEnabled,
    required this.autoLinking,
    required this.cardBreakEnabled,
  });

  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onBullet;
  final VoidCallback onNumbered;
  final VoidCallback onQuote;
  final VoidCallback onTable;
  final VoidCallback onCardBreak;
  final VoidCallback onAutoLink;
  final bool autoLinkEnabled;
  final bool autoLinking;
  final bool cardBreakEnabled;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        _ToolButton(
          tooltip: 'Bold',
          icon: Icons.format_bold,
          onPressed: onBold,
        ),
        _ToolButton(
          tooltip: 'Italic',
          icon: Icons.format_italic,
          onPressed: onItalic,
        ),
        _ToolButton(
          tooltip: 'Underline',
          icon: Icons.format_underline,
          onPressed: onUnderline,
        ),
        _ToolButton(
          tooltip: 'Bullet list',
          icon: Icons.format_list_bulleted,
          onPressed: onBullet,
        ),
        _ToolButton(
          tooltip: 'Numbered list',
          icon: Icons.format_list_numbered,
          onPressed: onNumbered,
        ),
        _ToolButton(
          tooltip: 'Quote',
          icon: Icons.format_quote,
          onPressed: onQuote,
        ),
        _ToolButton(
          tooltip: 'Table',
          icon: Icons.table_chart_outlined,
          onPressed: onTable,
        ),
        if (cardBreakEnabled)
          _ToolButton(
            tooltip: 'Card break (new printed card)',
            icon: Icons.insert_page_break_outlined,
            onPressed: onCardBreak,
          ),
        if (autoLinkEnabled)
          _ToolButton(
            tooltip: 'Auto-link conditions & damage types',
            icon: Icons.link,
            onPressed: autoLinking ? null : onAutoLink,
          ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
