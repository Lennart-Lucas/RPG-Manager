import 'package:flutter/material.dart';

import '../../../../core/ui/record_list_card.dart';
import '../data/spell_display.dart';
import '../data/spell_model.dart';

class SpellListItemCard extends StatelessWidget {
  const SpellListItemCard({
    required this.spell,
    required this.classNames,
    required this.tagEntries,
    required this.onTap,
    this.onLongPress,
    this.minWidth = 280,
    this.maxWidth = 1060,
    this.selected = false,
    this.selectionEmphasis = false,
    super.key,
  });

  final Spell spell;
  final List<String> classNames;
  final List<({String id, String name})> tagEntries;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double minWidth;
  final double maxWidth;
  final bool selected;
  final bool selectionEmphasis;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final heading = spell.name.trim().isEmpty ? 'Spell' : spell.name.trim();
    final infoBlockColor = Color.alphaBlend(
      colors.shadow.withValues(alpha: 0.42),
      colors.surfaceContainerLow,
    );

    return RecordListCard(
      leading: spell.school.buildIcon(size: 30, color: colors.onSurface),
      title: heading,
      subtitle: spell.listSubtitle,
      onTap: onTap,
      onLongPress: onLongPress,
      minWidth: minWidth,
      maxWidth: maxWidth,
      selected: selected,
      selectionEmphasis: selectionEmphasis,
      trailing: selected && selectionEmphasis
          ? Icon(Icons.check_circle, size: 26, color: colors.primary)
          : null,
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: infoBlockColor,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RecordListCardMetaStat(
                  label: 'Casting',
                  value: spell.castingAndRangeLine,
                ),
              ),
              RecordListCardMetaDivider(
                color: colors.outlineVariant.withValues(alpha: 0.42),
              ),
              Expanded(
                child: RecordListCardMetaStat(
                  label: 'Duration',
                  value: spell.durationListDisplay,
                ),
              ),
              RecordListCardMetaDivider(
                color: colors.outlineVariant.withValues(alpha: 0.42),
              ),
              Expanded(
                child: RecordListCardMetaStat(
                  label: 'Components',
                  value: spell.componentsAbbrev,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RecordListCardChipGroup(
                title: 'Classes',
                labels: classNames,
                emptyLabel: 'Unassigned',
                accentColor: colors.primary,
                textTheme: textTheme,
                colors: colors,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RecordListCardChipGroup(
                title: 'Tags',
                labels: tagEntries.map((e) => e.name).toList(growable: false),
                emptyLabel: null,
                accentColor: colors.tertiary,
                textTheme: textTheme,
                colors: colors,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
