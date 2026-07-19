import 'package:flutter/material.dart';

import '../../../../core/ui/record_list_card.dart';
import '../data/item_display.dart';
import '../data/item_model.dart';

class ItemListItemCard extends StatelessWidget {
  const ItemListItemCard({
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.minWidth = 280,
    this.maxWidth = 1060,
    this.selected = false,
    this.selectionEmphasis = false,
    super.key,
  });

  final Item item;
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
    final heading = item.name.trim().isEmpty ? 'Item' : item.name.trim();
    final infoBlockColor = Color.alphaBlend(
      colors.shadow.withValues(alpha: 0.42),
      colors.surfaceContainerLow,
    );
    final descPreview = itemDescriptionPreview(item.description);
    final descText = descPreview.isEmpty ? null : descPreview;

    final leading = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        item.itemType.listIcon,
        size: 22,
        color: colors.onPrimaryContainer,
      ),
    );

    return RecordListCard(
      leading: leading,
      title: heading,
      subtitle: item.listSubtitle,
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
                  label: 'Type',
                  value: item.itemType.label,
                ),
              ),
              RecordListCardMetaDivider(
                color: colors.outlineVariant.withValues(alpha: 0.42),
              ),
              Expanded(
                child: RecordListCardMetaStat(
                  label: 'Rarity',
                  value: item.rarity.label,
                ),
              ),
              RecordListCardMetaDivider(
                color: colors.outlineVariant.withValues(alpha: 0.42),
              ),
              Expanded(
                child: RecordListCardMetaStat(
                  label: 'Details',
                  value: item.detailsColumn,
                ),
              ),
            ],
          ),
        ),
        if (descText != null) ...[
          const SizedBox(height: 8),
          Text(
            descText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.25,
            ),
          ),
        ],
      ],
    );
  }
}
