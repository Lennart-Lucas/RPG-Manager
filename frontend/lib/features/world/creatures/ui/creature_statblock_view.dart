import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:rpg_manager/features/world/creatures/data/creature_model.dart';
import 'package:rpg_manager/features/world/creatures/data/scaler_math.dart';

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

String _signed(int value) {
  if (value > 0) return '+$value';
  return '$value';
}

String _withCommas(int value) {
  final raw = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final fromEnd = raw.length - i;
    buffer.write(raw[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
}

class CreatureStatblockView extends StatelessWidget {
  const CreatureStatblockView({
    required this.creature,
    this.typeLabel,
    super.key,
  });

  final Creature creature;
  final String? typeLabel;

  String _speedLine(ScalerComputedStats formula) {
    final parts = <String>[];
    final walk = creature.speeds.walk + formula.speedWalkDelta;
    parts.add('$walk ft.');
    if (creature.speeds.fly != null) parts.add('fly ${creature.speeds.fly} ft.');
    if (creature.speeds.swim != null) {
      parts.add('swim ${creature.speeds.swim} ft.');
    }
    if (creature.speeds.climb != null) {
      parts.add('climb ${creature.speeds.climb} ft.');
    }
    if (creature.speeds.burrow != null) {
      parts.add('burrow ${creature.speeds.burrow} ft.');
    }
    return parts.join(', ');
  }

  String _savesText() {
    const saveKeys = ['str', 'dex', 'con', 'int', 'wis', 'cha'];
    const saveLabels = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];
    final trained =
        creature.trainedSavingThrows.map((s) => s.toLowerCase()).toSet();
    final scores = creature.abilityScores;
    final pb = creature.proficiencyBonus;
    return [
      for (var i = 0; i < saveKeys.length; i++)
        if (trained.contains(saveKeys[i]))
          '${saveLabels[i]} ${_signed(scores[AbilityKey.values[i]] + pb)}',
    ].join(', ');
  }

  Widget _rankIcon(String rankDisplay, {required Color color, double size = 24}) {
    final lower = rankDisplay.toLowerCase();
    if (lower.contains('paragon')) {
      return FaIcon(FontAwesomeIcons.crown, size: size * 0.85, color: color);
    }
    final IconData icon;
    if (lower.contains('elite')) {
      icon = Icons.workspace_premium_outlined;
    } else if (lower.contains('minion')) {
      icon = Icons.shield_outlined;
    } else {
      icon = Icons.shield_moon_outlined;
    }
    return Icon(icon, size: size, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final formula = creature.formula;
    final scores = creature.abilityScores;
    final headerName =
        creature.name.trim().isEmpty ? 'Creature' : creature.name.trim();
    final resolvedType = typeLabel ?? creature.creatureType;
    final typeLine = [
      creature.size,
      if (resolvedType.isNotEmpty) resolvedType,
    ].join(' ');
    final levelRankText = [
      'Level ${creature.level}',
      creature.rankDisplay,
    ].join(' ');
    final profileText =
        'PB ${_signed(creature.proficiencyBonus)}, CR ${creature.cr}, '
        'XP ${_withCommas(creature.xp)}';
    final saves = _savesText();
    final senses = creature.resolvedSenses().join(', ');
    final blockColor = _lighterVariant(scheme.surfaceContainerHigh, amount: 0.07);
    final rowsColor = _lighterVariant(scheme.surface, amount: 0.06);
    final rowValueColor =
        _lighterVariant(scheme.surfaceContainerLowest, amount: 0.1);
    final dividerColor = _darkerVariant(blockColor, amount: 0.015);
    final secondaryBand = _darkerVariant(scheme.primaryContainer, amount: 0.12);
    const bannerWidth = 64.0;
    const bannerMargin = 3.0;
    // Rectangle + downward semicircle; height clears the primary header band.
    const bannerHeight = 88.0;
    const bannerInset = 14.0;
    final headerTextTrailing = bannerInset + bannerWidth + 12;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      color: scheme.primaryContainer,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        14,
                        headerTextTrailing,
                        12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headerName.toUpperCase(),
                            style: TextStyle(
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w700,
                              fontSize: 26,
                              letterSpacing: 1.1,
                            ),
                          ),
                          if (typeLine.trim().isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              typeLine,
                              style: TextStyle(
                                color: scheme.onPrimaryContainer,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      color: secondaryBand,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Row(
                        children: [
                          _rankIcon(
                            creature.rankDisplay,
                            color: scheme.onPrimaryContainer,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Padding(
                              // Keep level/rank clear of the banner; profile stays flush right.
                              padding: EdgeInsets.only(
                                right: bannerInset + bannerWidth - 16,
                              ),
                              child: Text(
                                levelRankText,
                                style: TextStyle(
                                  color: scheme.onPrimaryContainer,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Text(
                            profileText,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: scheme.onPrimaryContainer
                                  .withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  right: bannerInset,
                  top: 0,
                  child: _StatblockHeaderBanner(
                    width: bannerWidth,
                    height: bannerHeight,
                    margin: bannerMargin,
                    fillColor: scheme.primary,
                    circleColor: scheme.primaryContainer,
                    icon: _rankIcon(
                      creature.rankDisplay,
                      color: scheme.onPrimaryContainer,
                      size: (bannerWidth / 2 - bannerMargin) * 2 * 0.55,
                    ),
                  ),
                ),
              ],
            ),
            Container(
              color: scheme.surfaceContainerLowest,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _RowsBlock(
                    scheme: scheme,
                    backgroundColor: rowsColor,
                    labelBackgroundColor: blockColor,
                    valueBackgroundColor: rowValueColor,
                    dividerColor: dividerColor,
                    rows: [
                      _LabeledRichRow(
                        label: 'Health',
                        scheme: scheme,
                        value: TextSpan(
                          style: textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurface,
                          ),
                          children: [
                            const TextSpan(
                              text: 'HP',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' ${creature.hp}'),
                            const TextSpan(text: '  '),
                            const TextSpan(
                              text: 'Bloodied',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' ${creature.bloodied}'),
                            const TextSpan(text: '  '),
                            const TextSpan(
                              text: 'Enraged',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' ${creature.enraged}'),
                          ],
                        ),
                      ),
                      _LabeledRichRow(
                        label: 'Defence',
                        scheme: scheme,
                        value: TextSpan(
                          style: textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurface,
                          ),
                          children: [
                            const TextSpan(
                              text: 'AC',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' ${creature.ac}'),
                            if (saves.isNotEmpty) ...[
                              const TextSpan(text: '.  '),
                              const TextSpan(
                                text: 'Saves ',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(text: saves),
                            ],
                          ],
                        ),
                      ),
                      _LabeledRichRow(
                        label: 'Offence',
                        scheme: scheme,
                        value: TextSpan(
                          style: textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurface,
                          ),
                          children: [
                            const TextSpan(
                              text: 'To hit',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' ${_signed(creature.atk)}'),
                            const TextSpan(text: '.  '),
                            const TextSpan(
                              text: 'DC',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' ${creature.dc}'),
                            const TextSpan(text: '.  '),
                            const TextSpan(
                              text: 'Hit:',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' ${creature.dmg} damage'),
                            if (creature.reach != null)
                              TextSpan(text: ', reach ${creature.reach} ft.'),
                            if (creature.range != null)
                              TextSpan(text: ', range ${creature.range} ft.'),
                            const TextSpan(text: '.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _AbilityStrip(
                    scheme: scheme,
                    cellBackgroundColor: blockColor,
                    abilities: [
                      ('STR', scores.str),
                      ('DEX', scores.dex),
                      ('CON', scores.con),
                      ('INT', scores.int_),
                      ('WIS', scores.wis),
                      ('CHA', scores.cha),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _RowsBlock(
                    scheme: scheme,
                    backgroundColor: rowsColor,
                    labelBackgroundColor: blockColor,
                    valueBackgroundColor: rowValueColor,
                    dividerColor: dividerColor,
                    rows: [
                      if (senses.isNotEmpty)
                        _LabeledValueRow(
                          label: 'Senses',
                          value: senses,
                          scheme: scheme,
                        ),
                      if (creature.skills.isNotEmpty)
                        _LabeledValueRow(
                          label: 'Skills',
                          value: creature.skills.join(', '),
                          scheme: scheme,
                        ),
                      if (creature.languages.isNotEmpty)
                        _LabeledValueRow(
                          label: 'Languages',
                          value: creature.languages.join(', '),
                          scheme: scheme,
                        ),
                      _LabeledRichRow(
                        label: 'Speed',
                        scheme: scheme,
                        value: TextSpan(
                          style: textTheme.bodyLarge?.copyWith(
                            color: scheme.onSurface,
                          ),
                          children: [
                            TextSpan(text: _speedLine(formula)),
                            const TextSpan(text: '.  '),
                            const TextSpan(
                              text: 'Initiative ',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: _signed(creature.initiativeBonus)),
                          ],
                        ),
                      ),
                      if (creature.vulnerabilities.isNotEmpty)
                        _LabeledValueRow(
                          label: 'Vulnerabilities',
                          value: creature.vulnerabilities.join(', '),
                          scheme: scheme,
                        ),
                      if (creature.resistances.isNotEmpty)
                        _LabeledValueRow(
                          label: 'Resistances',
                          value: creature.resistances.join(', '),
                          scheme: scheme,
                        ),
                      if (creature.immunities.isNotEmpty)
                        _LabeledValueRow(
                          label: 'Immunities',
                          value: creature.immunities.join(', '),
                          scheme: scheme,
                        ),
                      _LabeledValueRow(
                        label: 'Passive',
                        value: 'Perception ${creature.passivePerception}',
                        scheme: scheme,
                      ),
                    ],
                  ),
                  if (creature.features.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: blockColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Features',
                        style: textTheme.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final entry in creature.features)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.displayName,
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(entry.displayText, style: textTheme.bodyMedium),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowsBlock extends StatelessWidget {
  const _RowsBlock({
    required this.scheme,
    required this.rows,
    this.backgroundColor,
    this.labelBackgroundColor,
    this.valueBackgroundColor,
    this.dividerColor,
  });

  final ColorScheme scheme;
  final List<Widget> rows;
  final Color? backgroundColor;
  final Color? labelBackgroundColor;
  final Color? valueBackgroundColor;
  final Color? dividerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: backgroundColor ?? scheme.surface,
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _RowColors(
              labelBackground: labelBackgroundColor,
              valueBackground: valueBackgroundColor,
              child: rows[i],
            ),
            if (i != rows.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: dividerColor ?? scheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _RowColors extends InheritedWidget {
  const _RowColors({
    required this.labelBackground,
    required this.valueBackground,
    required super.child,
  });

  final Color? labelBackground;
  final Color? valueBackground;

  static _RowColors? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_RowColors>();
  }

  @override
  bool updateShouldNotify(_RowColors oldWidget) {
    return labelBackground != oldWidget.labelBackground ||
        valueBackground != oldWidget.valueBackground;
  }
}

class _LabeledValueRow extends StatelessWidget {
  const _LabeledValueRow({
    required this.label,
    required this.value,
    required this.scheme,
  });

  final String label;
  final String value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final colors = _RowColors.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 118,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: colors?.labelBackground ?? scheme.surfaceContainerHighest,
            alignment: Alignment.centerRight,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: scheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: colors?.valueBackground ?? scheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                value,
                style: TextStyle(fontSize: 15, color: scheme.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledRichRow extends StatelessWidget {
  const _LabeledRichRow({
    required this.label,
    required this.value,
    required this.scheme,
  });

  final String label;
  final InlineSpan value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final colors = _RowColors.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 118,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: colors?.labelBackground ?? scheme.surfaceContainerHighest,
            alignment: Alignment.centerRight,
            child: Text(
              label,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: scheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: colors?.valueBackground ?? scheme.surface,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text.rich(value),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbilityStrip extends StatelessWidget {
  const _AbilityStrip({
    required this.scheme,
    required this.abilities,
    this.cellBackgroundColor,
  });

  final ColorScheme scheme;
  final List<(String, int)> abilities;
  final Color? cellBackgroundColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < abilities.length; i++) ...[
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: cellBackgroundColor ?? scheme.surfaceContainerHigh,
              ),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Column(
                children: [
                  Text(
                    abilities[i].$1,
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${10 + (2 * abilities[i].$2)} (${_signed(abilities[i].$2)})',
                    style: TextStyle(fontSize: 15, color: scheme.onSurface),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (i != abilities.length - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

/// Pendant banner: rectangle from the top + downward semicircle (`c=` rotated 90°).
class _StatblockHeaderBanner extends StatelessWidget {
  const _StatblockHeaderBanner({
    required this.width,
    required this.height,
    required this.margin,
    required this.fillColor,
    required this.circleColor,
    required this.icon,
  });

  final double width;
  final double height;
  final double margin;
  final Color fillColor;
  final Color circleColor;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final outerRadius = width / 2;
    final circleRadius = outerRadius - margin;
    final circleDiameter = circleRadius * 2;
    // Semicircle center sits at the bottom of the rectangular stem.
    final circleCenterY = height - outerRadius;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BannerShapePainter(color: fillColor),
            ),
          ),
          Positioned(
            left: margin,
            top: circleCenterY - circleRadius,
            width: circleDiameter,
            height: circleDiameter,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: circleColor,
                shape: BoxShape.circle,
              ),
              child: Center(child: icon),
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerShapePainter extends CustomPainter {
  const _BannerShapePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final radius = size.width / 2;
    final rectBottom = size.height - radius;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, rectBottom)
      ..arcTo(
        Rect.fromCircle(
          center: Offset(radius, rectBottom),
          radius: radius,
        ),
        0,
        math.pi,
        false,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BannerShapePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
