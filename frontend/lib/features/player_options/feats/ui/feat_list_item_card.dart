import 'package:flutter/material.dart';

import '../../../../core/ui/record_list_card.dart';
import '../../player_options_icons.dart';
import '../data/feat_display.dart';
import '../data/feat_model.dart';

class FeatListItemCard extends StatelessWidget {
  const FeatListItemCard({
    required this.feat,
    required this.onTap,
    this.onLongPress,
    this.minWidth = 280,
    this.maxWidth = 1060,
    this.selected = false,
    this.selectionEmphasis = false,
    super.key,
  });

  final FeatRecord feat;
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
    final heading = feat.name.trim().isEmpty ? 'Feat' : feat.name.trim();
    final infoBlockColor = Color.alphaBlend(
      colors.shadow.withValues(alpha: 0.42),
      colors.surfaceContainerLow,
    );
    final descPreview = feat.descriptionPreview;
    final descText = descPreview.isEmpty ? null : descPreview;
    final requirementPreview = feat.listSubtitle;

    final leading = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        featsPageIcon,
        size: 22,
        color: colors.onPrimaryContainer,
      ),
    );

    return RecordListCard(
      leading: leading,
      title: heading,
      subtitle: requirementPreview ?? '',
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
                  label: 'Requirement',
                  value: feat.hasRequirement ? 'Yes' : 'None',
                ),
              ),
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
