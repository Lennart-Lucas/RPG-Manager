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

Color _headerFill(Color accent, ColorScheme colors) {
  return Color.alphaBlend(
    accent.withValues(alpha: 0.55),
    colors.surfaceContainerHigh,
  );
}

Color _onHeader(Color fill, ColorScheme colors) {
  final luminance = fill.computeLuminance();
  return luminance > 0.45 ? colors.onSurface : colors.onPrimary;
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
    final headerBg = _headerFill(accent, colors);
    final onHeader = _onHeader(headerBg, colors);
    final secondaryBand = _darkerVariant(headerBg, amount: 0.10);

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
                      headerBg: headerBg,
                      secondaryBand: secondaryBand,
                      onHeader: onHeader,
                      topRadius: radius,
                      maxFontSize: maxFontSize,
                      continuationIndex: continuationIndex,
                      continuationTotal: continuationTotal,
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: colors.surfaceContainerLowest,
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
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    _ConditionFooterBand(
                      icon: icon,
                      footerBg: secondaryBand,
                      onFooter: onHeader,
                      bottomRadius: radius,
                      maxFontSize: maxFontSize,
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
    );
  });
}

class _ConditionHeaderBand extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color headerBg;
  final Color secondaryBand;
  final Color onHeader;
  final double topRadius;
  final double maxFontSize;
  final int? continuationIndex;
  final int? continuationTotal;

  const _ConditionHeaderBand({
    required this.name,
    required this.icon,
    required this.headerBg,
    required this.secondaryBand,
    required this.onHeader,
    required this.topRadius,
    required this.maxFontSize,
    this.continuationIndex,
    this.continuationTotal,
  });

  @override
  Widget build(BuildContext context) {
    final summaryFontSize = maxFontSize;
    final titleFontSize = maxFontSize * kMtgCardTitleToRulesMaxFontScale;
    final continuationText =
        continuationIndex != null && continuationTotal != null
            ? 'Part $continuationIndex/$continuationTotal'
            : '';
    final subheaderText =
        continuationText.isEmpty ? 'Condition' : 'Condition · $continuationText';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: headerBg,
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
              color: onHeader,
              fontWeight: FontWeight.w700,
              fontSize: titleFontSize,
              letterSpacing: 0.75,
              height: 1.05,
            ),
          ),
        ),
        Container(
          color: secondaryBand,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              catalogAppearanceIconWidget(
                icon,
                size: (maxFontSize * 11 / kMtgCardRulesMaxFontSize).clamp(
                  10.0,
                  16.0,
                ),
                color: onHeader,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  subheaderText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onHeader,
                    fontSize: summaryFontSize,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                  strutStyle: StrutStyle(
                    fontSize: summaryFontSize,
                    height: 1.0,
                    leading: 0,
                    fontWeight: FontWeight.w600,
                    forceStrutHeight: true,
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

class _ConditionFooterBand extends StatelessWidget {
  final IconData icon;
  final Color footerBg;
  final Color onFooter;
  final double bottomRadius;
  final double maxFontSize;

  const _ConditionFooterBand({
    required this.icon,
    required this.footerBg,
    required this.onFooter,
    required this.bottomRadius,
    required this.maxFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final footerFontSize = maxFontSize;
    return Material(
      color: footerBg,
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(bottomRadius),
        bottomRight: Radius.circular(bottomRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            catalogAppearanceIconWidget(
              icon,
              size: _conditionCardBandIconSize(maxFontSize),
              color: onFooter,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Condition',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onFooter,
                  fontSize: footerFontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                strutStyle: StrutStyle(
                  fontSize: footerFontSize,
                  height: 1.2,
                  leading: 0,
                  fontWeight: FontWeight.w600,
                  forceStrutHeight: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
