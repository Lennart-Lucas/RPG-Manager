import 'package:flutter/material.dart';

import '../../../../core/ui/card_text_pagination.dart';
import '../../../../core/ui/mtg_card_layout.dart';
import '../../../../core/ui/mtg_card_rules_text_fit.dart';
import '../../../catalog/ui/catalog_appearance.dart';
import '../../data/styled_mechanics_record.dart';
import '../../mechanics_icons.dart';

Color _darkerVariant(Color base, {double amount = 0.08}) {
  final hsl = HSLColor.fromColor(base);
  final adjusted = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(adjusted).toColor();
}

double _conditionCardBandIconSize(double maxFontSize) =>
    (maxFontSize * 14 / kMtgCardRulesMaxFontSize).clamp(13.0, 19.0);

/// MTG-sized presentation card for a condition.
class ConditionSheet extends StatelessWidget {
  final StyledMechanicsRecord record;
  final IconData fallbackIcon;
  final EdgeInsetsGeometry padding;
  final String? descriptionOverride;
  final int? continuationIndex;
  final int? continuationTotal;
  final MtgCardRulesScaleController? rulesScaleController;
  final double maxFontSize;
  final double cardScale;
  final void Function(String kind, String id)? onWikiLinkTap;
  final Future<String?> Function(String kind, String id)? resolveWikiLinkLabel;

  const ConditionSheet({
    required this.record,
    this.fallbackIcon = conditionsPageIcon,
    this.padding = EdgeInsets.zero,
    this.maxFontSize = kMtgCardRulesMaxFontSize,
    this.descriptionOverride,
    this.continuationIndex,
    this.continuationTotal,
    this.rulesScaleController,
    this.cardScale = 1.0,
    this.onWikiLinkTap,
    this.resolveWikiLinkLabel,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final headerName =
        record.name.trim().isEmpty ? 'Condition' : record.name.trim();
    final effectiveDescription = descriptionOverride ?? record.description;
    final hasDescription = effectiveDescription.trim().isNotEmpty;
    final accent = record.resolvedColor(fallback: colors.primary);
    final icon = record.resolvedIcon(fallback: fallbackIcon);

    const radius = 14.0;

    return Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final baseSize = computeMtgCardLogicalSize(context, constraints);
          final size = Size(
            baseSize.width * cardScale,
            baseSize.height * cardScale,
          );
          return Align(
            alignment: Alignment.topCenter,
            widthFactor: 1.0,
            heightFactor: 1.0,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ConditionHeaderBand(
                      name: headerName,
                      icon: icon,
                      colors: colors,
                      topRadius: radius,
                      maxFontSize: maxFontSize,
                      continuationIndex: continuationIndex,
                      continuationTotal: continuationTotal,
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLowest,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(radius),
                            bottomRight: Radius.circular(radius),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            IgnorePointer(
                              child: Center(
                                child: catalogAppearanceIconWidget(
                                  icon,
                                  size: size.shortestSide * 0.58,
                                  color: accent.withValues(
                                    alpha: kItemCardWatermarkIconAlpha,
                                  ),
                                ),
                              ),
                            ),
                            if (hasDescription)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  8,
                                  10,
                                  10,
                                ),
                                child: MtgCardRulesTextFit(
                                  content: effectiveDescription,
                                  onSurface: colors.onSurface,
                                  maxFontSize: maxFontSize,
                                  scaleController: rulesScaleController,
                                  onWikiLinkTap: onWikiLinkTap,
                                  resolveWikiLinkLabel: resolveWikiLinkLabel,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

List<ConditionSheet> buildConditionSheets(
  StyledMechanicsRecord record, {
  IconData fallbackIcon = conditionsPageIcon,
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  double maxFontSize = kMtgCardRulesMaxFontSize,
  double cardScale = 1.0,
  void Function(String kind, String id)? onWikiLinkTap,
  Future<String?> Function(String kind, String id)? resolveWikiLinkLabel,
}) {
  final pages = paginateCardBodyText(record.description);
  final sharedScaleController =
      pages.length > 1 ? MtgCardRulesScaleController() : null;
  if (pages.length <= 1) {
    return [
      ConditionSheet(
        record: record,
        fallbackIcon: fallbackIcon,
        padding: padding,
        maxFontSize: maxFontSize,
        cardScale: cardScale,
        onWikiLinkTap: onWikiLinkTap,
        resolveWikiLinkLabel: resolveWikiLinkLabel,
      ),
    ];
  }
  return List<ConditionSheet>.generate(pages.length, (i) {
    return ConditionSheet(
      record: record,
      fallbackIcon: fallbackIcon,
      padding: padding,
      maxFontSize: maxFontSize,
      cardScale: cardScale,
      descriptionOverride: pages[i],
      continuationIndex: i + 1,
      continuationTotal: pages.length,
      rulesScaleController: sharedScaleController,
      onWikiLinkTap: onWikiLinkTap,
      resolveWikiLinkLabel: resolveWikiLinkLabel,
    );
  });
}

class _ConditionHeaderBand extends StatelessWidget {
  final String name;
  final IconData icon;
  final ColorScheme colors;
  final double topRadius;
  final double maxFontSize;
  final int? continuationIndex;
  final int? continuationTotal;

  const _ConditionHeaderBand({
    required this.name,
    required this.icon,
    required this.colors,
    required this.topRadius,
    required this.maxFontSize,
    this.continuationIndex,
    this.continuationTotal,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryBandColor = _darkerVariant(
      colors.primaryContainer,
      amount: 0.12,
    );
    final summaryFontSize = maxFontSize;
    final titleFontSize = maxFontSize * kMtgCardTitleToRulesMaxFontScale;
    final continuationText =
        continuationIndex != null && continuationTotal != null
            ? ' · Part $continuationIndex/$continuationTotal'
            : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(topRadius),
              topRight: Radius.circular(topRadius),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 5),
          child: Text(
            name.toUpperCase(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              fontSize: titleFontSize,
              letterSpacing: 0.75,
              height: 1.05,
            ),
          ),
        ),
        Container(
          color: secondaryBandColor,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              catalogAppearanceIconWidget(
                icon,
                size: _conditionCardBandIconSize(maxFontSize),
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Condition$continuationText',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onPrimaryContainer,
                    fontSize: summaryFontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
