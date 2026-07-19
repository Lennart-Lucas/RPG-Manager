import 'package:flutter/material.dart';

/// Shared shell for catalog list rows: constrained width, Material 3 card,
/// ink well, optional selection highlight.
class RecordListCard extends StatelessWidget {
  const RecordListCard({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.children,
    required this.onTap,
    this.trailing,
    this.onLongPress,
    this.minWidth = 280,
    this.maxWidth = 1060,
    this.selected = false,
    this.selectionEmphasis = false,
    super.key,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final double minWidth;
  final double maxWidth;
  final bool selected;
  final bool selectionEmphasis;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final subtleBorderColor = colors.outline.withValues(alpha: 0.6);
    final cardBackground = selected
        ? (selectionEmphasis
            ? Color.alphaBlend(
                colors.primaryContainer.withValues(alpha: 0.72),
                colors.surfaceContainerHigh,
              )
            : Color.alphaBlend(
                colors.secondaryContainer.withValues(alpha: 0.40),
                colors.surfaceContainerHigh,
              ))
        : colors.surfaceContainerLow;
    final selectedBorderColor = selected
        ? (selectionEmphasis
            ? colors.primary.withValues(alpha: 0.92)
            : colors.secondary.withValues(alpha: 0.85))
        : subtleBorderColor;
    final selectedBorderWidth = selected
        ? (selectionEmphasis ? 2.0 : 1.3)
        : 1.15;

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        clipBehavior: Clip.antiAlias,
        elevation: 0.8,
        color: cardBackground,
        shadowColor: colors.shadow.withValues(alpha: 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selectedBorderColor,
            width: selectedBorderWidth,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: colors.primary.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Single labeled column in a list-card meta strip (Casting, Duration, …).
class RecordListCardMetaStat extends StatelessWidget {
  const RecordListCardMetaStat({
    required this.label,
    required this.value,
    super.key,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            color: colors.primary,
            letterSpacing: 0.55,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            color: colors.onSurface,
            height: 1.28,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class RecordListCardMetaDivider extends StatelessWidget {
  const RecordListCardMetaDivider({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        '|',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
              height: 1.15,
            ),
      ),
    );
  }
}

/// Title + single-line compact chips; overflow shows a `+N` chip.
class RecordListCardChipGroup extends StatelessWidget {
  const RecordListCardChipGroup({
    required this.title,
    required this.labels,
    required this.emptyLabel,
    required this.accentColor,
    required this.textTheme,
    required this.colors,
    super.key,
  });

  final String title;
  final List<String> labels;
  final String? emptyLabel;
  final Color accentColor;
  final TextTheme textTheme;
  final ColorScheme colors;

  static const double _chipSpacing = 6;
  static const double _labelPadH = 7;
  /// Approximate Chip chrome beyond the label text width.
  static const double _chipChrome = 20;

  @override
  Widget build(BuildContext context) {
    final isEmpty = labels.isEmpty;
    final displayNames = isEmpty
        ? (emptyLabel == null ? const <String>[] : <String>[emptyLabel!])
        : labels;
    final labelStyle = textTheme.bodySmall?.copyWith(
          color: isEmpty ? colors.onSurfaceVariant : accentColor,
          fontWeight: FontWeight.w700,
        ) ??
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w700);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        if (displayNames.isEmpty)
          const SizedBox.shrink()
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final fit = _fitLabels(
                displayNames,
                constraints.maxWidth,
                labelStyle,
                allowOverflowChip: !isEmpty,
              );
              return Row(
                children: [
                  for (var i = 0; i < fit.visible.length; i++) ...[
                    if (i > 0) const SizedBox(width: _chipSpacing),
                    if (i == fit.visible.length - 1 && fit.hiddenCount == 0)
                      Flexible(
                        child: _chip(
                          label: fit.visible[i],
                          isEmptyPlaceholder: isEmpty,
                          labelStyle: labelStyle,
                        ),
                      )
                    else
                      _chip(
                        label: fit.visible[i],
                        isEmptyPlaceholder: isEmpty,
                        labelStyle: labelStyle,
                      ),
                  ],
                  if (fit.hiddenCount > 0) ...[
                    const SizedBox(width: _chipSpacing),
                    _chip(
                      label: '+${fit.hiddenCount}',
                      isEmptyPlaceholder: false,
                      labelStyle: labelStyle,
                      muted: true,
                    ),
                  ],
                ],
              );
            },
          ),
      ],
    );
  }

  double _measureChip(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + _labelPadH * 2 + _chipChrome;
  }

  ({List<String> visible, int hiddenCount}) _fitLabels(
    List<String> names,
    double maxWidth,
    TextStyle labelStyle, {
    required bool allowOverflowChip,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return (visible: names, hiddenCount: 0);
    }
    if (names.length == 1 || !allowOverflowChip) {
      return (visible: names, hiddenCount: 0);
    }

    final overflowW = _measureChip('+${names.length}', labelStyle);
    final fitted = <String>[];
    var used = 0.0;

    for (var i = 0; i < names.length; i++) {
      final chipW = _measureChip(names[i], labelStyle);
      final spacing = fitted.isEmpty ? 0.0 : _chipSpacing;
      final restAfterThis = names.length - i - 1;
      final reserveOverflow =
          restAfterThis > 0 ? overflowW + _chipSpacing : 0.0;
      if (used + spacing + chipW + reserveOverflow <= maxWidth + 0.5) {
        fitted.add(names[i]);
        used += spacing + chipW;
        continue;
      }
      break;
    }

    if (fitted.isEmpty) {
      return (visible: [names.first], hiddenCount: names.length - 1);
    }
    final hidden = names.length - fitted.length;
    return (visible: fitted, hiddenCount: hidden);
  }

  Widget _chip({
    required String label,
    required bool isEmptyPlaceholder,
    required TextStyle labelStyle,
    bool muted = false,
  }) {
    final sideColor = isEmptyPlaceholder
        ? colors.outlineVariant.withValues(alpha: 0.45)
        : accentColor.withValues(alpha: muted ? 0.28 : 0.38);
    final bg = isEmptyPlaceholder
        ? colors.surfaceContainerHigh.withValues(alpha: 0.68)
        : muted
            ? colors.surfaceContainerHighest.withValues(alpha: 0.9)
            : accentColor == colors.primary
                ? colors.primaryContainer.withValues(alpha: 0.42)
                : colors.tertiaryContainer.withValues(alpha: 0.42);
    final fg = isEmptyPlaceholder
        ? colors.onSurfaceVariant
        : muted
            ? colors.onSurfaceVariant
            : accentColor;

    return Chip(
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(
        horizontal: -2,
        vertical: -2,
      ),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: _labelPadH),
      side: BorderSide(color: sideColor, width: 0.8),
      backgroundColor: bg,
      labelStyle: labelStyle.copyWith(color: fg),
      label: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
    );
  }
}
