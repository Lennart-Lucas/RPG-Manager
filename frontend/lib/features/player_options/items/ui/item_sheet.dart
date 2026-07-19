import 'package:flutter/material.dart';

import '../../../../core/ui/card_text_pagination.dart';
import '../../../../core/ui/mtg_card_layout.dart';
import '../../../../core/ui/mtg_card_rules_text_fit.dart';
import '../data/item_model.dart';

Color _darkerVariant(Color base, {double amount = 0.08}) {
  final hsl = HSLColor.fromColor(base);
  final adjusted = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(adjusted).toColor();
}

double _itemCardBandIconSize(double maxFontSize) =>
    (maxFontSize * 14 / kMtgCardRulesMaxFontSize).clamp(13.0, 19.0);

String _formatGpAmount(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  final len = s.length;
  for (var i = 0; i < len; i++) {
    if (i > 0 && (len - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

String suggestedGoldRangeForRarity(ItemRarity rarity) {
  switch (rarity) {
    case ItemRarity.common:
      return '${_formatGpAmount(50)} – ${_formatGpAmount(100)} gp';
    case ItemRarity.uncommon:
      return '${_formatGpAmount(101)} – ${_formatGpAmount(500)} gp';
    case ItemRarity.rare:
      return '${_formatGpAmount(501)} – ${_formatGpAmount(5000)} gp';
    case ItemRarity.veryRare:
      return '${_formatGpAmount(5001)} – ${_formatGpAmount(50000)} gp';
    case ItemRarity.legendary:
    case ItemRarity.artifact:
      return '${_formatGpAmount(50001)}+ gp';
  }
}

class ItemSheet extends StatelessWidget {
  final Item item;
  final EdgeInsetsGeometry padding;
  final String? descriptionOverride;
  final int? continuationIndex;
  final int? continuationTotal;
  final MtgCardRulesScaleController? rulesScaleController;
  final double maxFontSize;
  final double cardScale;

  const ItemSheet({
    required this.item,
    this.padding = EdgeInsets.zero,
    this.maxFontSize = kMtgCardRulesMaxFontSize,
    this.descriptionOverride,
    this.continuationIndex,
    this.continuationTotal,
    this.rulesScaleController,
    this.cardScale = 1.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final headerName = item.name.trim().isEmpty ? 'Item' : item.name.trim();
    final effectiveDescription = descriptionOverride ?? item.description;
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
                    _ItemHeaderBand(
                      name: headerName,
                      item: item,
                      colors: colors,
                      topRadius: radius,
                      maxFontSize: maxFontSize,
                      continuationIndex: continuationIndex,
                      continuationTotal: continuationTotal,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                                        item.itemType.listIcon,
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
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          _ItemFooterBand(
                            rarityLabel: item.rarity.label,
                            goldRangeText:
                                suggestedGoldRangeForRarity(item.rarity),
                            colors: colors,
                            bottomRadius: radius,
                            maxFontSize: maxFontSize,
                          ),
                        ],
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

List<ItemSheet> buildItemSheets(
  Item item, {
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  double maxFontSize = kMtgCardRulesMaxFontSize,
  double cardScale = 1.0,
}) {
  final pages = paginateCardBodyText(item.description);
  final sharedScaleController =
      pages.length > 1 ? MtgCardRulesScaleController() : null;
  if (pages.length <= 1) {
    return [
      ItemSheet(
        item: item,
        padding: padding,
        maxFontSize: maxFontSize,
        cardScale: cardScale,
      ),
    ];
  }
  return List<ItemSheet>.generate(pages.length, (i) {
    return ItemSheet(
      item: item,
      padding: padding,
      maxFontSize: maxFontSize,
      cardScale: cardScale,
      descriptionOverride: pages[i],
      continuationIndex: i + 1,
      continuationTotal: pages.length,
      rulesScaleController: sharedScaleController,
    );
  });
}

class _ItemHeaderBand extends StatelessWidget {
  final String name;
  final Item item;
  final ColorScheme colors;
  final double topRadius;
  final double maxFontSize;
  final int? continuationIndex;
  final int? continuationTotal;

  const _ItemHeaderBand({
    required this.name,
    required this.item,
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
            ? ' (Part $continuationIndex/$continuationTotal)'
            : '';
    final summaryStyle = TextStyle(
      color: colors.onPrimaryContainer,
      fontSize: summaryFontSize,
      fontWeight: FontWeight.w600,
      height: 1.0,
    );

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
                item.itemType.listIcon,
                size: (maxFontSize * 11 / kMtgCardRulesMaxFontSize).clamp(
                  10.0,
                  16.0,
                ),
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: _ItemSubheaderSummary(
                  item: item,
                  continuationText: continuationText,
                  baseStyle: summaryStyle,
                  summaryFontSize: summaryFontSize,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ItemSubheaderSummary extends StatelessWidget {
  final Item item;
  final String continuationText;
  final TextStyle baseStyle;
  final double summaryFontSize;

  const _ItemSubheaderSummary({
    required this.item,
    required this.continuationText,
    required this.baseStyle,
    required this.summaryFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[item.itemType.label];

    final showParen =
        (item.itemType == ItemType.armor || item.itemType == ItemType.weapon) &&
            item.typeReference.trim().isNotEmpty;
    if (showParen) {
      parts.add('(${item.typeReference.trim()})');
    }

    if (item.magic && item.requiresAttunement) {
      parts.add('Magic (Requires attunement)');
    } else if (item.magic) {
      parts.add('Magic');
    } else if (item.requiresAttunement) {
      parts.add('(Requires attunement)');
    }
    if (item.consumable) {
      parts.add('Consumable');
    }
    if (continuationText.isNotEmpty) {
      parts.add(continuationText.trim());
    }

    return Text(
      parts.join(' · '),
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      style: baseStyle,
      strutStyle: StrutStyle(
        fontSize: summaryFontSize,
        height: 1.0,
        leading: 0,
        fontWeight: FontWeight.w600,
        forceStrutHeight: true,
      ),
    );
  }
}

class _ItemFooterBand extends StatelessWidget {
  final String rarityLabel;
  final String goldRangeText;
  final ColorScheme colors;
  final double bottomRadius;
  final double maxFontSize;

  const _ItemFooterBand({
    required this.rarityLabel,
    required this.goldRangeText,
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
    final line = '$rarityLabel · $goldRangeText';
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
              Icons.monetization_on_outlined,
              size: _itemCardBandIconSize(maxFontSize),
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                line,
                maxLines: 4,
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
