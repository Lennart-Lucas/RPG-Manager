import 'package:flutter/material.dart';

import '../../../auth/state/auth_controller.dart';
import '../../../world/characters/ui/mtg_alignment_chips.dart';
import '../../../world/ui/catalog_overview_box.dart';
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

  static const double preferredWidth = CatalogOverviewBox.preferredWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color lift(Color toward, double amount) =>
        Color.lerp(scheme.surface, toward, amount)!;

    final sectionHeaderBg = scheme.primaryContainer;
    final labelBg = scheme.surfaceContainer;
    final valueBg = lift(scheme.onSurface, 0.16);
    final borderColor = scheme.outline.withValues(alpha: 0.55);
    final hasAlignment = record.mtgAlignment.isNotEmpty;
    final overviewSplit = splitOverviewDetailsSections(record.overviewSections);
    final mergedDetails = overviewSplit.detailsItems;
    final otherOverviewSections = overviewSplit.otherSections;
    final hasDetailsBlock = hasAlignment || mergedDetails.isNotEmpty;

    return CatalogOverviewBox(
      auth: auth,
      title: record.name,
      icon: racesPageIcon,
      aliases: record.aliases,
      imageUrl: record.imageUrl,
      leading: [
        if (hasDetailsBlock)
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
                    if (hasAlignment) ...[
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
                      if (mergedDetails.isNotEmpty)
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: borderColor,
                        ),
                    ],
                    for (var i = 0; i < mergedDetails.length; i++)
                      OverviewItemRow(
                        auth: auth,
                        item: mergedDetails[i],
                        labelBg: labelBg,
                        valueBg: valueBg,
                        borderColor: borderColor,
                        showDivider: i < mergedDetails.length - 1,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
      overviewSections: otherOverviewSections,
    );
  }
}
