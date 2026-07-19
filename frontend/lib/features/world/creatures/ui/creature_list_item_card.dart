import 'package:flutter/material.dart';

import 'package:rpg_manager/core/ui/record_list_card.dart';
import 'package:rpg_manager/features/world/creatures/data/creature_model.dart';
import 'package:rpg_manager/features/world/creatures/data/scaler_math.dart';
import 'package:rpg_manager/features/world/world_icons.dart';

class CreatureListItemCard extends StatelessWidget {
  const CreatureListItemCard({
    required this.creature,
    required this.onTap,
    this.onLongPress,
    this.typeLabel,
    this.minWidth = 280,
    this.maxWidth = 1060,
    super.key,
  });

  final Creature creature;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final String? typeLabel;
  final double minWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final heading =
        creature.name.trim().isEmpty ? 'Creature' : creature.name.trim();
    final roleLabel = creature.role?.label ?? 'No role';
    final subtitle = 'Level ${creature.level} · ${creature.rankDisplay} · $roleLabel';
    final infoBlockColor = Color.alphaBlend(
      colors.shadow.withValues(alpha: 0.42),
      colors.surfaceContainerLow,
    );

    final leading = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: colors.primaryContainer.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(
        creaturesPageIcon,
        size: 22,
        color: colors.onPrimaryContainer,
      ),
    );

    return RecordListCard(
      leading: leading,
      title: heading,
      subtitle: subtitle,
      trailing: Icon(
        Icons.chevron_right,
        color: colors.onSurfaceVariant,
      ),
      onTap: onTap,
      onLongPress: onLongPress,
      minWidth: minWidth,
      maxWidth: maxWidth,
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
                  label: 'CR',
                  value: creature.cr,
                ),
              ),
              RecordListCardMetaDivider(
                color: colors.outlineVariant.withValues(alpha: 0.42),
              ),
              Expanded(
                child: RecordListCardMetaStat(
                  label: 'XP',
                  value: '${creature.xp}',
                ),
              ),
              RecordListCardMetaDivider(
                color: colors.outlineVariant.withValues(alpha: 0.42),
              ),
              Expanded(
                child: RecordListCardMetaStat(
                  label: 'HP',
                  value: '${creature.hp}',
                ),
              ),
            ],
          ),
        ),
        if ((typeLabel ?? creature.creatureType).isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            typeLabel ?? creature.creatureType,
            maxLines: 1,
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
