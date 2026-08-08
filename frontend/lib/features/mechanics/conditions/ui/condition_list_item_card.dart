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
    final descPreview = record.descriptionPreview;
    final descText = descPreview.isEmpty ? null : descPreview;

    final leading = Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
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
      trailing: selected && selectionEmphasis
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
