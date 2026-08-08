import 'package:flutter/material.dart';

import '../../../../core/ui/card_text_pagination.dart';
import '../../../../core/ui/mtg_card_layout.dart';
import '../../../../core/ui/mtg_card_rules_text_fit.dart';
import '../../mechanics_icons.dart';
import '../data/item_property_model.dart';

Color _darkerVariant(Color base, {double amount = 0.08}) {
  final hsl = HSLColor.fromColor(base);
  final adjusted = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(adjusted).toColor();
}

double _itemPropertyCardBandIconSize(double maxFontSize) =>
    (maxFontSize * 14 / kMtgCardRulesMaxFontSize).clamp(13.0, 19.0);

/// MTG-sized presentation card for an [ItemPropertyRecord].
class ItemPropertySheet extends StatelessWidget {
  final ItemPropertyRecord property;
  final EdgeInsetsGeometry padding;
  final String? descriptionOverride;
  final int? continuationIndex;
  final int? continuationTotal;
  final MtgCardRulesScaleController? rulesScaleController;
  final double maxFontSize;
  final double cardScale;
  final void Function(String kind, String id)? onWikiLinkTap;

  const ItemPropertySheet({
    required this.property,
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
        property.name.trim().isEmpty ? 'Item property' : property.name.trim();
    final effectiveDescription = descriptionOverride ?? property.description;
    final hasDescription = effectiveDescription.trim().isNotEmpty;

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
                    _ItemPropertyHeaderBand(
                      name: headerName,
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
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            IgnorePointer(
                              child: Center(
                                child: Icon(
                                  itemPropertiesPageIcon,
                                  size: size.shortestSide * 0.58,
                                  color: colors.primary.withValues(
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
                    _ItemPropertyFooterBand(
                      colors: colors,
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

List<ItemPropertySheet> buildItemPropertySheets(
  ItemPropertyRecord property, {
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  double maxFontSize = kMtgCardRulesMaxFontSize,
  double cardScale = 1.0,
  void Function(String kind, String id)? onWikiLinkTap,
}) {
  final pages = paginateCardBodyText(property.description);
  final sharedScaleController =
      pages.length > 1 ? MtgCardRulesScaleController() : null;
  if (pages.length <= 1) {
    return [
      ItemPropertySheet(
        property: property,
        padding: padding,
        maxFontSize: maxFontSize,
        cardScale: cardScale,
        onWikiLinkTap: onWikiLinkTap,
      ),
    ];
  }
  return List<ItemPropertySheet>.generate(pages.length, (i) {
    return ItemPropertySheet(
      property: property,
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

class _ItemPropertyHeaderBand extends StatelessWidget {
  final String name;
  final ColorScheme colors;
  final double topRadius;
  final double maxFontSize;
  final int? continuationIndex;
  final int? continuationTotal;

  const _ItemPropertyHeaderBand({
    required this.name,
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
            ? 'Part $continuationIndex/$continuationTotal'
            : '';
    final summaryStyle = TextStyle(
      color: colors.onPrimaryContainer,
      fontSize: summaryFontSize,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );
    final subheaderText =
        continuationText.isEmpty ? 'Item property' : continuationText;

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
              Icon(
                itemPropertiesPageIcon,
                size: (maxFontSize * 11 / kMtgCardRulesMaxFontSize).clamp(
                  10.0,
                  16.0,
                ),
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  subheaderText,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: summaryStyle,
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

class _ItemPropertyFooterBand extends StatelessWidget {
  final ColorScheme colors;
  final double bottomRadius;
  final double maxFontSize;

  const _ItemPropertyFooterBand({
    required this.colors,
    required this.bottomRadius,
    required this.maxFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final footerColor = _darkerVariant(
      colors.primaryContainer,
      amount: 0.12,
    );
    final footerFontSize = maxFontSize;
    return Material(
      color: footerColor,
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
            Icon(
              itemPropertiesPageIcon,
              size: _itemPropertyCardBandIconSize(maxFontSize),
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                'Item property',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onPrimaryContainer,
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
