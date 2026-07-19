import 'package:flutter/material.dart';

/// One row in [showMultiPicklistSheet] — [id] is stored in the selection set.
class PicklistOption {
  const PicklistOption({required this.id, required this.label});

  final String id;
  final String label;
}

/// Result of a multi-pick sheet that may include free-text custom entries.
class MultiPicklistResult {
  const MultiPicklistResult({
    required this.selected,
    this.customStrings = const [],
  });

  final Set<String> selected;
  final List<String> customStrings;
}

/// Multi-select from [options] (checkbox list).
Future<Set<String>?> showMultiPicklistSheet(
  BuildContext context, {
  required String title,
  required List<PicklistOption> options,
  required Set<String> selected,
}) async {
  final result = await showMultiPicklistWithCustomsSheet(
    context,
    title: title,
    options: options,
    selected: selected,
    allowCustomEntries: false,
  );
  return result?.selected;
}

/// Multi-select with optional free-text custom rows in the same sheet (v3 pattern).
Future<MultiPicklistResult?> showMultiPicklistWithCustomsSheet(
  BuildContext context, {
  required String title,
  required List<PicklistOption> options,
  required Set<String> selected,
  List<String> customStrings = const [],
  bool allowCustomEntries = true,
}) async {
  return showModalBottomSheet<MultiPicklistResult>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      return _MultiPicklistSheetBody(
        title: title,
        options: options,
        initialSelected: selected,
        initialCustoms: customStrings,
        allowCustomEntries: allowCustomEntries,
      );
    },
  );
}

class _CustomDraftEntry {
  _CustomDraftEntry({required this.checked, String text = ''})
      : controller = TextEditingController(text: text);

  bool checked;
  final TextEditingController controller;

  void dispose() => controller.dispose();
}

class _MultiPicklistSheetBody extends StatefulWidget {
  const _MultiPicklistSheetBody({
    required this.title,
    required this.options,
    required this.initialSelected,
    required this.initialCustoms,
    required this.allowCustomEntries,
  });

  final String title;
  final List<PicklistOption> options;
  final Set<String> initialSelected;
  final List<String> initialCustoms;
  final bool allowCustomEntries;

  @override
  State<_MultiPicklistSheetBody> createState() =>
      _MultiPicklistSheetBodyState();
}

class _MultiPicklistSheetBodyState extends State<_MultiPicklistSheetBody> {
  late final Set<String> _working = Set<String>.from(widget.initialSelected);
  late final TextEditingController _searchController = TextEditingController();
  String _query = '';
  late List<_CustomDraftEntry> _customDraftEntries;

  @override
  void initState() {
    super.initState();
    if (widget.allowCustomEntries) {
      _customDraftEntries = [
        for (final s in widget.initialCustoms)
          _CustomDraftEntry(checked: true, text: s),
        _CustomDraftEntry(checked: false),
      ];
    } else {
      _customDraftEntries = const [];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final e in _customDraftEntries) {
      e.dispose();
    }
    super.dispose();
  }

  List<PicklistOption> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((o) => o.label.toLowerCase().contains(q))
        .toList();
  }

  void _onCustomTextChanged(int index, String value) {
    final isLast = index == _customDraftEntries.length - 1;
    final trimmed = value.trim();
    if (isLast && trimmed.isNotEmpty) {
      _customDraftEntries[index].checked = true;
      _customDraftEntries.add(_CustomDraftEntry(checked: false));
      setState(() {});
      return;
    }
    if (trimmed.isNotEmpty) {
      _customDraftEntries[index].checked = true;
    }
    setState(() {});
  }

  List<String> _committedCustoms() {
    return [
      for (final row in _customDraftEntries)
        if (row.checked && row.controller.text.trim().isNotEmpty)
          row.controller.text.trim(),
    ];
  }

  InputDecoration _customDecoration(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = BorderRadius.circular(8);
    final subtleBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.55),
        width: 1,
      ),
    );
    final fillAlpha = theme.brightness == Brightness.dark ? 0.22 : 0.35;
    return InputDecoration(
      hintText: 'Add other…',
      isDense: true,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: fillAlpha),
      border: subtleBorder,
      enabledBorder: subtleBorder,
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: cs.primary.withValues(alpha: 0.45),
          width: 1,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height *
        (widget.allowCustomEntries ? 0.72 : 0.7);
    final filtered = _filtered;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: maxHeight,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search…',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final opt in filtered)
                        CheckboxListTile(
                          value: _working.contains(opt.id),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _working.add(opt.id);
                              } else {
                                _working.remove(opt.id);
                              }
                            });
                          },
                          title: Text(opt.label),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      if (widget.allowCustomEntries) ...[
                        if (filtered.isNotEmpty || _query.isNotEmpty)
                          const Divider(height: 24),
                        for (var i = 0; i < _customDraftEntries.length; i++)
                          CheckboxListTile(
                            value: _customDraftEntries[i].checked,
                            onChanged: (v) {
                              setState(() {
                                _customDraftEntries[i].checked = v ?? false;
                              });
                            },
                            title: TextField(
                              controller: _customDraftEntries[i].controller,
                              decoration: _customDecoration(context),
                              onChanged: (v) => _onCustomTextChanged(i, v),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
                          ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _working.clear();
                            if (widget.allowCustomEntries) {
                              for (final e in _customDraftEntries) {
                                e.dispose();
                              }
                              _customDraftEntries = [
                                _CustomDraftEntry(checked: false),
                              ];
                            }
                          });
                        },
                        child: const Text('Clear selection'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(
                          MultiPicklistResult(
                            selected: _working,
                            customStrings: widget.allowCustomEntries
                                ? _committedCustoms()
                                : const [],
                          ),
                        ),
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
