import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/dm_tools/resources/ui/resource_form_helpers.dart';
import '../markdown/wiki_link.dart';

/// A catalog record that can be inserted as `[[kind/name]]`.
class CatalogLinkTarget {
  const CatalogLinkTarget({
    required this.id,
    required this.kind,
    required this.name,
  });

  final int id;
  final String kind;
  final String name;

  factory CatalogLinkTarget.fromJson(Map<String, dynamic> json) {
    return CatalogLinkTarget(
      id: json['id'] as int,
      kind: json['kind'] as String,
      name: json['name'] as String,
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
      _removeOverlay();
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
                    return ListTile(
                      dense: true,
                      title: Text(item.name),
                      subtitle: Text(item.kind),
                      onTap: () => _insertLink(item),
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
    final cursor = _controller.selection.baseOffset;
    if (cursor < incomplete.start) return;

    final insertion = formatWikiLink(kind: target.kind, name: target.name);
    final newText = text.replaceRange(incomplete.start, cursor, insertion);
    final newOffset = incomplete.start + insertion.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
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

  Future<void> _autoLink() async {
    final loader = widget.loadAutoLinkTargets;
    if (loader == null || _autoLinking) return;

    setState(() => _autoLinking = true);
    try {
      final targets = await loader();
      if (!mounted) return;
      final linked = autoLinkCatalogNames(
        _controller.text,
        targets: targets.map((t) => (kind: t.kind, name: t.name)),
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
              onBold: () => _wrapSelection(prefix: '**', suffix: '**'),
              onItalic: () => _wrapSelection(prefix: '*', suffix: '*'),
              onUnderline: () =>
                  _wrapSelection(prefix: '<u>', suffix: '</u>'),
              onBullet: () => _toggleLinePrefix(numbered: false),
              onNumbered: () => _toggleLinePrefix(numbered: true),
              onTable: _insertTable,
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
    required this.onTable,
    required this.onAutoLink,
    required this.autoLinkEnabled,
    required this.autoLinking,
  });

  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onBullet;
  final VoidCallback onNumbered;
  final VoidCallback onTable;
  final VoidCallback onAutoLink;
  final bool autoLinkEnabled;
  final bool autoLinking;

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
          tooltip: 'Table',
          icon: Icons.table_chart_outlined,
          onPressed: onTable,
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
