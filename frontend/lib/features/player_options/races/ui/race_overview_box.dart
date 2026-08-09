import 'package:flutter/material.dart';

import '../../../../core/ui/catalog_image_slot.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../world/characters/ui/mtg_alignment_chips.dart';
import '../../../world/ui/overview_sections.dart';
import '../../../world/ui/overview_sections_view.dart';
import '../../player_options_icons.dart';
import '../data/race_model.dart';

/// Wikipedia-style overview / infobox for a race.
class RaceOverviewBox extends StatelessWidget {
  const RaceOverviewBox({
    super.key,
    required this.auth,
    required this.record,
  });

  final AuthController auth;
  final RaceRecord record;

  static const double preferredWidth = 300;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color lift(Color toward, double amount) =>
        Color.lerp(scheme.surface, toward, amount)!;

    final panelBg = lift(scheme.onSurface, 0.07);
    final sectionHeaderBg = scheme.primaryContainer;
    final labelBg = scheme.surfaceContainer;
    final valueBg = lift(scheme.onSurface, 0.16);
    final borderColor = scheme.outline.withValues(alpha: 0.55);
    final hasAlignment = record.mtgAlignment.isNotEmpty;
    final hasOverviewSections =
        overviewSectionsNonEmpty(record.overviewSections);

    return Material(
      color: panelBg,
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      racesPageIcon,
                      color: scheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.name,
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (record.aliases.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            record.aliases.join(', '),
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.all(14),
              child: CatalogImageSlot(
                imageUrl: record.imageUrl,
                borderColor: borderColor,
                placeholder: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      racesPageIcon,
                      size: 40,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Image placeholder',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.name,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            if (hasAlignment)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ColoredBox(
                          color: sectionHeaderBg,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            child: Text(
                              'DETAILS',
                              style: textTheme.labelLarge?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ColoredBox(
                                color: labelBg,
                                child: SizedBox(
                                  width: 96,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      'Alignment',
                                      style: textTheme.labelLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              VerticalDivider(
                                width: 1,
                                thickness: 1,
                                color: borderColor,
                              ),
                              Expanded(
                                child: ColoredBox(
                                  color: valueBg,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 10,
                                    ),
                                    child: Center(
                                      child: MtgAlignmentChips(
                                        colors: record.mtgAlignment,
                                        size: 26,
                                        wrapAlignment: WrapAlignment.center,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (hasOverviewSections)
              OverviewSectionsView(
                auth: auth,
                sections: record.overviewSections,
              ),
          ],
        ),
      ),
    );
  }
}
