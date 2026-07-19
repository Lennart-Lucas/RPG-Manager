import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rpg_manager/core/ui/multi_picklist_sheet.dart';
import 'package:rpg_manager/features/world/data/labeled_amount.dart';

const movementPresets = ['Normal', 'Burrow', 'Climb', 'Fly', 'Swim'];
const sensePresets = ['Blindsight', 'Darkvision', 'Tremorsense', 'Truesight'];

String _amountText(num amount) {
  if (amount == amount.roundToDouble()) return amount.toInt().toString();
  return '$amount';
}

String summarizeLabeledAmounts(
  List<LabeledAmount> items, {
  String empty = 'None',
}) {
  final display = labeledAmountsDisplay(items);
  return display.isEmpty ? empty : display;
}

Future<void> pickLabeledAmounts({
  required BuildContext context,
  required String title,
  required List<String> presets,
  required List<LabeledAmount> items,
  required ValueChanged<List<LabeledAmount>> onDone,
}) async {
  final result = await showLabeledAmountPickSheet(
    context,
    title: title,
    presets: presets,
    items: items,
  );
  if (result == null) return;
  onDone(result);
}

Future<List<LabeledAmount>?> showLabeledAmountPickSheet(
  BuildContext context, {
  required String title,
  required List<String> presets,
  required List<LabeledAmount> items,
}) {
  return showModalBottomSheet<List<LabeledAmount>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _LabeledAmountPickSheet(
      title: title,
      presets: presets,
      initialItems: items,
    ),
  );
}

class _PresetDraft {
  _PresetDraft({
    required this.label,
    required this.checked,
    String amountText = '',
  }) : amountController = TextEditingController(text: amountText);

  final String label;
  bool checked;
  final TextEditingController amountController;

  void dispose() => amountController.dispose();
}

class _CustomDraft {
  _CustomDraft({
    required this.checked,
    String label = '',
    String amountText = '',
  })  : labelController = TextEditingController(text: label),
        amountController = TextEditingController(text: amountText);

  bool checked;
  final TextEditingController labelController;
  final TextEditingController amountController;

  void dispose() {
    labelController.dispose();
    amountController.dispose();
  }
}

class _LabeledAmountPickSheet extends StatefulWidget {
  const _LabeledAmountPickSheet({
    required this.title,
    required this.presets,
    required this.initialItems,
  });

  final String title;
  final List<String> presets;
  final List<LabeledAmount> initialItems;

  @override
  State<_LabeledAmountPickSheet> createState() =>
      _LabeledAmountPickSheetState();
}

class _LabeledAmountPickSheetState extends State<_LabeledAmountPickSheet> {
  late final Map<String, _PresetDraft> _presets;
  late List<_CustomDraft> _customs;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    final presetSet = {for (final p in widget.presets) p.toLowerCase()};
    final presetAmounts = <String, num>{};
    final customs = <LabeledAmount>[];
    for (final item in widget.initialItems) {
      final key = item.label.trim();
      if (key.isEmpty) continue;
      if (presetSet.contains(key.toLowerCase()) &&
          !presetAmounts.containsKey(key.toLowerCase())) {
        final preset = widget.presets.firstWhere(
          (p) => p.toLowerCase() == key.toLowerCase(),
        );
        presetAmounts[preset.toLowerCase()] = item.amount;
      } else {
        customs.add(item);
      }
    }
    _presets = {
      for (final preset in widget.presets)
        preset: _PresetDraft(
          label: preset,
          checked: presetAmounts.containsKey(preset.toLowerCase()),
          amountText: presetAmounts.containsKey(preset.toLowerCase())
              ? _amountText(presetAmounts[preset.toLowerCase()]!)
              : '',
        ),
    };
    _customs = [
      for (final item in customs)
        _CustomDraft(
          checked: true,
          label: item.label,
          amountText: _amountText(item.amount),
        ),
      _CustomDraft(checked: false),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final d in _presets.values) {
      d.dispose();
    }
    for (final c in _customs) {
      c.dispose();
    }
    super.dispose();
  }

  List<_PresetDraft> get _filteredPresets {
    final q = _query.trim().toLowerCase();
    final all = _presets.values.toList();
    if (q.isEmpty) return all;
    return all.where((p) => p.label.toLowerCase().contains(q)).toList();
  }

  num _parseAmount(String text) {
    final trimmed = text.trim().replaceAll(',', '.');
    if (trimmed.isEmpty) return 0;
    return num.tryParse(trimmed) ?? 0;
  }

  List<LabeledAmount> _commit() {
    final out = <LabeledAmount>[];
    for (final preset in widget.presets) {
      final draft = _presets[preset]!;
      if (!draft.checked) continue;
      out.add(
        LabeledAmount(
          label: draft.label,
          amount: _parseAmount(draft.amountController.text),
        ),
      );
    }
    for (final row in _customs) {
      if (!row.checked) continue;
      final label = row.labelController.text.trim();
      if (label.isEmpty) continue;
      out.add(
        LabeledAmount(
          label: label,
          amount: _parseAmount(row.amountController.text),
        ),
      );
    }
    return out;
  }

  void _onCustomLabelChanged(int index, String value) {
    final isLast = index == _customs.length - 1;
    final trimmed = value.trim();
    if (isLast && trimmed.isNotEmpty) {
      _customs[index].checked = true;
      _customs.add(_CustomDraft(checked: false));
      setState(() {});
      return;
    }
    if (trimmed.isNotEmpty) {
      _customs[index].checked = true;
    }
    setState(() {});
  }

  InputDecoration _fieldDecoration(BuildContext context, {String? hint}) {
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
      hintText: hint,
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

  Widget _amountField({
    required TextEditingController controller,
    required VoidCallback onEdited,
  }) {
    return SizedBox(
      width: 88,
      child: TextField(
        controller: controller,
        decoration: _fieldDecoration(context, hint: 'ft.'),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'-?\d*[.,]?\d*')),
        ],
        onChanged: (_) => onEdited(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    final filtered = _filteredPresets;
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
                      for (final draft in filtered)
                        CheckboxListTile(
                          value: draft.checked,
                          onChanged: (v) {
                            setState(() {
                              draft.checked = v ?? false;
                              if (draft.checked &&
                                  draft.amountController.text.trim().isEmpty) {
                                draft.amountController.text =
                                    draft.label == 'Darkvision' ? '60' : '30';
                              }
                            });
                          },
                          title: Row(
                            children: [
                              Expanded(child: Text(draft.label)),
                              _amountField(
                                controller: draft.amountController,
                                onEdited: () {
                                  if (draft.amountController.text
                                      .trim()
                                      .isNotEmpty) {
                                    setState(() => draft.checked = true);
                                  }
                                },
                              ),
                            ],
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
                      const Divider(height: 24),
                      for (var i = 0; i < _customs.length; i++)
                        CheckboxListTile(
                          value: _customs[i].checked,
                          onChanged: (v) {
                            setState(() {
                              _customs[i].checked = v ?? false;
                            });
                          },
                          title: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _customs[i].labelController,
                                  decoration: _fieldDecoration(
                                    context,
                                    hint: 'Add other…',
                                  ),
                                  onChanged: (v) =>
                                      _onCustomLabelChanged(i, v),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _amountField(
                                controller: _customs[i].amountController,
                                onEdited: () {
                                  if (_customs[i]
                                      .amountController
                                      .text
                                      .trim()
                                      .isNotEmpty) {
                                    setState(() => _customs[i].checked = true);
                                  }
                                },
                              ),
                            ],
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),
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
                            for (final draft in _presets.values) {
                              draft.checked = false;
                              draft.amountController.clear();
                            }
                            for (final c in _customs) {
                              c.dispose();
                            }
                            _customs = [_CustomDraft(checked: false)];
                          });
                        },
                        child: const Text('Clear selection'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(context).pop(_commit()),
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

/// Tap-to-open labeled amount picker (same tile pattern as skills/languages).
class LabeledAmountEditor extends StatelessWidget {
  const LabeledAmountEditor({
    super.key,
    required this.title,
    required this.presets,
    required this.items,
    required this.onChanged,
  });

  final String title;
  final List<String> presets;
  final List<LabeledAmount> items;
  final ValueChanged<List<LabeledAmount>> onChanged;

  @override
  Widget build(BuildContext context) {
    return catalogMultiPickTile(
      context: context,
      label: title,
      summary: summarizeLabeledAmounts(items),
      onTap: () => pickLabeledAmounts(
        context: context,
        title: title,
        presets: presets,
        items: items,
        onDone: onChanged,
      ),
    );
  }
}

Future<void> pickCatalogIds({
  required BuildContext context,
  required String title,
  required List<PicklistOption> options,
  required Set<int> selected,
  required ValueChanged<Set<int>> onDone,
}) async {
  final result = await showMultiPicklistWithCustomsSheet(
    context,
    title: title,
    options: options,
    selected: {for (final id in selected) '$id'},
    allowCustomEntries: false,
  );
  if (result == null) return;
  onDone({
    for (final id in result.selected)
      if (int.tryParse(id) case final parsed?) parsed,
  });
}

class CatalogAndCustomPick {
  const CatalogAndCustomPick({
    required this.ids,
    required this.customs,
    this.expertiseIds = const [],
    this.expertiseCustoms = const [],
  });

  final List<int> ids;
  final List<String> customs;
  final List<int> expertiseIds;
  final List<String> expertiseCustoms;
}

Future<void> pickCatalogIdsWithCustoms({
  required BuildContext context,
  required String title,
  required List<PicklistOption> options,
  required Set<int> selected,
  required List<String> customStrings,
  required ValueChanged<CatalogAndCustomPick> onDone,
  bool enableExpertise = false,
  Set<int> expertiseIds = const {},
  List<String> expertiseCustoms = const [],
}) async {
  final result = await showMultiPicklistWithCustomsSheet(
    context,
    title: title,
    options: options,
    selected: {for (final id in selected) '$id'},
    customStrings: customStrings,
    allowCustomEntries: true,
    enableExpertise: enableExpertise,
    expertise: {
      for (final id in expertiseIds) '$id',
      ...expertiseCustoms,
    },
  );
  if (result == null) return;
  final ids = <int>[
    for (final id in result.selected)
      if (int.tryParse(id) case final parsed?) parsed,
  ];
  final idSet = ids.toSet();
  final customSet = result.customStrings.map((s) => s.trim()).toSet();
  onDone(
    CatalogAndCustomPick(
      ids: ids,
      customs: result.customStrings,
      expertiseIds: [
        for (final id in result.expertise)
          if (int.tryParse(id) case final parsed?)
            if (idSet.contains(parsed)) parsed,
      ],
      expertiseCustoms: [
        for (final name in result.expertise)
          if (int.tryParse(name) == null && customSet.contains(name.trim()))
            name.trim(),
      ],
    ),
  );
}

String summarizeCatalogSelection({
  required Set<int> selected,
  required Map<int, String> namesById,
  List<String> customStrings = const [],
  Set<int> expertiseIds = const {},
  List<String> expertiseCustoms = const [],
  String empty = 'None',
}) {
  final expertiseCustomKeys = {
    for (final s in expertiseCustoms) s.trim().toLowerCase(),
  };
  final labels = [
    for (final id in selected)
      expertiseIds.contains(id)
          ? '${namesById[id] ?? '$id'} (Expertise)'
          : (namesById[id] ?? '$id'),
    for (final s in customStrings.where((s) => s.trim().isNotEmpty))
      expertiseCustomKeys.contains(s.trim().toLowerCase())
          ? '$s (Expertise)'
          : s,
  ];
  if (labels.isEmpty) return empty;
  labels.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return labels.join(', ');
}

Widget catalogMultiPickTile({
  required BuildContext context,
  required String label,
  required String summary,
  required VoidCallback onTap,
}) {
  return ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(summary),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

List<PicklistOption> catalogPicklistOptions(Map<int, String> namesById) {
  final entries = namesById.entries.toList()
    ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
  return [
    for (final entry in entries)
      PicklistOption(id: '${entry.key}', label: entry.value),
  ];
}

Map<int, String> namesByIdFromCatalogItems(
  Iterable<({int id, String name})> items,
) {
  return {for (final item in items) item.id: item.name};
}
