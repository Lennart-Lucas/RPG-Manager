import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rpg_manager/core/ui/multi_picklist_sheet.dart';
import 'package:rpg_manager/features/dm_tools/resources/ui/resource_form_helpers.dart';
import 'package:rpg_manager/features/world/data/labeled_amount.dart';

const movementPresets = ['Normal', 'Burrow', 'Climb', 'Fly', 'Swim'];
const sensePresets = ['Blindsight', 'Darkvision', 'Tremorsense', 'Truesight'];

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Add preset',
              onSelected: (label) {
                onChanged([...items, LabeledAmount(label: label, amount: 0)]);
              },
              itemBuilder: (context) => [
                for (final preset in presets)
                  PopupMenuItem(value: preset, child: Text(preset)),
                const PopupMenuItem(
                  value: '__custom__',
                  child: Text('Custom…'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            'None',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          )
        else
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      initialValue: items[i].label,
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'Label',
                      ),
                      onChanged: (value) {
                        final next = [...items];
                        next[i] = next[i].copyWith(label: value);
                        onChanged(next);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      initialValue: '${items[i].amount}',
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'Amount',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'-?\d*\.?\d+')),
                      ],
                      onChanged: (value) {
                        final parsed = num.tryParse(value.trim()) ?? 0;
                        final next = [...items];
                        next[i] = next[i].copyWith(amount: parsed);
                        onChanged(next);
                      },
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: () {
                      final next = [...items]..removeAt(i);
                      onChanged(next);
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

class CustomStringListField extends StatelessWidget {
  const CustomStringListField({
    super.key,
    required this.label,
    required this.values,
    required this.onChanged,
    this.hintText,
  });

  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: values.join(', '),
          decoration: ResourceFormStyles.inputDecoration(
            context,
            label: label,
            hintText: hintText ?? 'Comma-separated',
          ),
          onChanged: (text) {
            onChanged(
              text
                  .split(RegExp(r'[,\n]'))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList(),
            );
          },
        ),
      ],
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
  final result = await showMultiPicklistSheet(
    context,
    title: title,
    options: options,
    selected: {for (final id in selected) '$id'},
  );
  if (result == null) return;
  onDone({
    for (final id in result)
      if (int.tryParse(id) case final parsed?) parsed,
  });
}

String summarizeCatalogSelection({
  required Set<int> selected,
  required Map<int, String> namesById,
  String empty = 'None',
}) {
  if (selected.isEmpty) return empty;
  final labels = [
    for (final id in selected) namesById[id] ?? '$id',
  ]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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
