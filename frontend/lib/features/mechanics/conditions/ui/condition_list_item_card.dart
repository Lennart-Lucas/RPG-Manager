import 'package:flutter/material.dart';

import '../../../../core/ui/record_list_card.dart';
import '../../../catalog/ui/catalog_appearance.dart';
import '../../data/styled_mechanics_record.dart';
import '../../mechanics_icons.dart';

class ConditionListItemCard extends StatelessWidget {
  const ConditionListItemCard({
    required this.record,
    required this.onTap,
    this.onLongPress,
    this.onDelete,
    this.minWidth = 280,
    this.maxWidth = 1060,
    this.selected = false,
    this.selectionEmphasis = false,
    this.fallbackIcon = conditionsPageIcon,
    super.key,
  });

  final StyledMechanicsRecord record;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final double minWidth;
  final double maxWidth;
  final bool selected;
  final bool selectionEmphasis;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final heading =
        record.name.trim().isEmpty ? 'Condition' : record.name.trim();
    final accent = record.resolvedColor(fallback: colors.primary);
    final icon = record.resolvedIcon(fallback: fallbackIcon);
    final infoBlockColor = Color.alphaBlend(
      colors.shadow.withValues(alpha: 0.42),
      colors.surfaceContainerLow,
    );
    final descPreview = record.descriptionPreview;
    final descText = descPreview.isEmpty ? null : descPreview;

    final leading = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: catalogAppearanceIconWidget(icon, size: 22, color: accent),
    );

    return RecordListCard(
      leading: leading,
      title: heading,
      subtitle: 'Condition',
      trailing: onDelete != null
          ? IconButton(
              tooltip: 'Delete',
              onPressed: onDelete,
              icon: Icon(Icons.delete_outline, color: colors.onSurfaceVariant),
            )
          : selected && selectionEmphasis
              ? Icon(Icons.check_circle, size: 22, color: colors.primary)
              : Icon(
                  Icons.chevron_right,
                  color: colors.onSurfaceVariant,
                ),
      onTap: onTap,
      onLongPress: onLongPress,
      minWidth: minWidth,
      maxWidth: maxWidth,
      selected: selected,
      selectionEmphasis: selectionEmphasis,
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
                  label: 'Effect',
                  value: descText == null ? 'None' : 'Described',
                ),
              ),
              if (record.sourcePage != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: RecordListCardMetaStat(
                    label: 'Page',
                    value: '${record.sourcePage}',
                  ),
                ),
              ],
            ],
          ),
        ),
        if (descText != null) ...[
          const SizedBox(height: 10),
          Text(
            descText,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}
