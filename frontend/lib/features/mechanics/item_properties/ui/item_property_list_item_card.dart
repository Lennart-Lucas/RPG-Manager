import 'package:flutter/material.dart';

import '../../../../core/ui/record_list_card.dart';
import '../../mechanics_icons.dart';
import '../data/item_property_display.dart';
import '../data/item_property_model.dart';

class ItemPropertyListItemCard extends StatelessWidget {
  const ItemPropertyListItemCard({
    required this.property,
    required this.onTap,
    this.onLongPress,
    this.minWidth = 280,
    this.maxWidth = 1060,
    this.selected = false,
    this.selectionEmphasis = false,
    super.key,
  });

  final ItemPropertyRecord property;
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
    final heading =
        property.name.trim().isEmpty ? 'Item property' : property.name.trim();
    final descPreview = property.descriptionPreview;
    final descText = descPreview.isEmpty ? null : descPreview;

    final leading = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        itemPropertiesPageIcon,
        size: 22,
        color: colors.onPrimaryContainer,
      ),
    );

    return RecordListCard(
      leading: leading,
      title: heading,
      subtitle: 'Item property',
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
