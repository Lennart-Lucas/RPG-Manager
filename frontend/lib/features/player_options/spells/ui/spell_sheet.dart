import 'package:flutter/material.dart';

import '../../../../core/ui/card_text_pagination.dart';
import '../../../../core/ui/mtg_card_layout.dart';
import '../../../../core/ui/mtg_card_rules_text_fit.dart';
import '../data/spell_display.dart';
import '../data/spell_model.dart';

Color _lighterVariant(Color base, {double amount = 0.08}) {
  final hsl = HSLColor.fromColor(base);
  final adjusted = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(adjusted).toColor();
}

Color _darkerVariant(Color base, {double amount = 0.08}) {
  final hsl = HSLColor.fromColor(base);
  final adjusted = (hsl.lightness - amount).clamp(0.0, 1.0);
  return hsl.withLightness(adjusted).toColor();
}

double _spellCardBandIconSize(double maxFontSize) =>
    (maxFontSize * 14 / kMtgCardRulesMaxFontSize).clamp(13.0, 19.0);

/// MTG-sized presentation card for a [Spell].
class SpellSheet extends StatelessWidget {
  final Spell spell;
  final List<String> classNames;
  final List<String> tagNames;
  final EdgeInsetsGeometry padding;
  final double cardScale;
  final String? rulesContentOverride;
  final int? continuationIndex;
  final int? continuationTotal;
  final MtgCardRulesScaleController? rulesScaleController;
  final double maxFontSize;

  const SpellSheet({
    required this.spell,
    this.classNames = const [],
    this.tagNames = const [],
    this.padding = EdgeInsets.zero,
    this.cardScale = 1.0,
    this.maxFontSize = kMtgCardRulesMaxFontSize,
    this.rulesContentOverride,
    this.continuationIndex,
    this.continuationTotal,
    this.rulesScaleController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final headerName = spell.name.trim().isEmpty ? 'Spell' : spell.name.trim();
    final rulesContent = rulesContentOverride ?? spell.rulesContent;
    final hasRules = rulesContent.trim().isNotEmpty;
    final showMechanics = continuationIndex == null || continuationIndex == 1;
    final classesLine = classNames.isEmpty ? null : classNames.join(', ');
    final hasFooter = classesLine != null && classesLine.trim().isNotEmpty;

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
                    _SpellHeaderBand(
                      name: headerName,
                      spell: spell,
                      tagNames: tagNames,
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
                                borderRadius: hasFooter
                                    ? BorderRadius.zero
                                    : const BorderRadius.only(
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
                                      child: Opacity(
                                        opacity: kItemCardWatermarkIconAlpha,
                                        child: spell.school.buildIcon(
                                          size: size.shortestSide * 0.58,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      if (showMechanics)
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            8,
                                            8,
                                            8,
                                            0,
                                          ),
                                          child: _SpellMechanicsSection(
                                            spell: spell,
                                            colors: colors,
                                            maxFontSize: maxFontSize,
                                          ),
                                        ),
                                      if (hasRules)
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                              10,
                                              8,
                                              10,
                                              10,
                                            ),
                                            child: MtgCardRulesTextFit(
                                              content: rulesContent,
                                              onSurface: colors.onSurface,
                                              maxFontSize: maxFontSize,
                                              scaleController:
                                                  rulesScaleController,
                                            ),
                                          ),
                                        )
                                      else
                                        const Spacer(),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (hasFooter)
                            _SpellFooterBand(
                              classesText: classesLine.trim(),
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

List<SpellSheet> buildSpellSheets(
  Spell spell, {
  List<String> classNames = const [],
  List<String> tagNames = const [],
  EdgeInsetsGeometry padding = EdgeInsets.zero,
  double cardScale = 1.0,
  double maxFontSize = kMtgCardRulesMaxFontSize,
}) {
  final pages = paginateCardBodyText(spell.rulesContent);
  final sharedScaleController =
      pages.length > 1 ? MtgCardRulesScaleController() : null;
  if (pages.length <= 1) {
    return [
      SpellSheet(
        spell: spell,
        classNames: classNames,
        tagNames: tagNames,
        padding: padding,
        cardScale: cardScale,
        maxFontSize: maxFontSize,
      ),
    ];
  }
  return List<SpellSheet>.generate(pages.length, (i) {
    return SpellSheet(
      spell: spell,
      classNames: classNames,
      tagNames: tagNames,
      padding: padding,
      cardScale: cardScale,
      maxFontSize: maxFontSize,
      rulesContentOverride: pages[i],
      continuationIndex: i + 1,
      continuationTotal: pages.length,
      rulesScaleController: sharedScaleController,
    );
  });
}

class _SpellMechanicsSection extends StatelessWidget {
  final Spell spell;
  final ColorScheme colors;
  final double maxFontSize;

  const _SpellMechanicsSection({
    required this.spell,
    required this.colors,
    required this.maxFontSize,
  });

  @override
  Widget build(BuildContext context) {
    final emphasizedRowsColor = _lighterVariant(colors.surface, amount: 0.06);
    final emphasizedBlockColor = _lighterVariant(
      colors.surfaceContainerHigh,
      amount: 0.07,
    );
    final emphasizedRowValueColor = _lighterVariant(
      colors.surfaceContainerLowest,
      amount: 0.1,
    );
    final emphasizedDividerColor = _darkerVariant(
      emphasizedBlockColor,
      amount: 0.015,
    );

    final rows = <(String, String)>[
      ('Casting', spell.castingAndRangeLine),
      ('Duration', spell.durationCardDisplay),
      ('Components', spell.componentsCardLine),
    ];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: emphasizedRowsColor,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _SpellLabeledValueRow(
              label: rows[i].$1,
              value: rows[i].$2,
              colors: colors,
              maxFontSize: maxFontSize,
              labelBackgroundColor: emphasizedBlockColor,
              valueBackgroundColor: emphasizedRowValueColor,
            ),
            if (i != rows.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: emphasizedDividerColor,
              ),
          ],
        ],
      ),
    );
  }
}

class _SpellLabeledValueRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colors;
  final double maxFontSize;
  final Color? labelBackgroundColor;
  final Color? valueBackgroundColor;

  const _SpellLabeledValueRow({
    required this.label,
    required this.value,
    required this.colors,
    required this.maxFontSize,
    this.labelBackgroundColor,
    this.valueBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final lb = labelBackgroundColor ?? colors.surfaceContainerHighest;
    final vb = valueBackgroundColor ?? colors.surface;
    final labelFontSize = (maxFontSize * 0.92).clamp(10.5, 14.0);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 38,
            child: Container(
              color: lb,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              alignment: Alignment.centerRight,
              child: Text(
                label,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: colors.primary,
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 62,
            child: Container(
              color: vb,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: maxFontSize,
                  color: colors.onSurface,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpellFooterBand extends StatelessWidget {
  final String classesText;
  final ColorScheme colors;
  final double bottomRadius;
  final double maxFontSize;

  const _SpellFooterBand({
    required this.classesText,
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
              Icons.groups_outlined,
              size: _spellCardBandIconSize(maxFontSize),
              color: colors.onPrimaryContainer,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                classesText,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onPrimaryContainer,
                  fontSize: footerFontSize,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpellHeaderBand extends StatelessWidget {
  final String name;
  final Spell spell;
  final List<String> tagNames;
  final ColorScheme colors;
  final double topRadius;
  final double maxFontSize;
  final int? continuationIndex;
  final int? continuationTotal;

  const _SpellHeaderBand({
    required this.name,
    required this.spell,
    required this.tagNames,
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
    final tagsText = tagNames.isEmpty ? null : tagNames.join(', ');
    final summaryText =
        '${spell.levelDisplayName} · ${spell.school.label}'
        '${tagsText == null ? '' : ' · $tagsText'}'
        '$continuationText';

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
                Icons.auto_stories_outlined,
                size: _spellCardBandIconSize(maxFontSize),
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  summaryText,
                  maxLines: 2,
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
