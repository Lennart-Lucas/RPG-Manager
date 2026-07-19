import 'package:flutter/material.dart';

/// Single-line compact chips; overflow shows a `+N` chip for hidden labels.
class OverflowChipRow extends StatelessWidget {
  const OverflowChipRow({
    required this.labels,
    required this.accentColor,
    this.labelStyle,
    this.emptyPlaceholderStyle,
    this.isEmptyPlaceholder = false,
    super.key,
  });

  final List<String> labels;
  final Color accentColor;
  final TextStyle? labelStyle;
  final TextStyle? emptyPlaceholderStyle;
  final bool isEmptyPlaceholder;

  static const double chipSpacing = 6;
  static const double labelPadH = 7;
  /// Approximate Chip chrome beyond the label text width.
  static const double chipChrome = 20;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final style = isEmptyPlaceholder
        ? (emptyPlaceholderStyle ??
            Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ) ??
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
        : (labelStyle ??
            Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w700,
                ) ??
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w700));

    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = fitLabels(
          labels,
          constraints.maxWidth,
          style,
          allowOverflowChip: !isEmptyPlaceholder,
        );
        return Row(
          children: [
            for (var i = 0; i < fit.visible.length; i++) ...[
              if (i > 0) const SizedBox(width: chipSpacing),
              if (i == fit.visible.length - 1 && fit.hiddenCount == 0)
                Flexible(
                  child: OverflowChip(
                    label: fit.visible[i],
                    accentColor: accentColor,
                    labelStyle: style,
                    isEmptyPlaceholder: isEmptyPlaceholder,
                  ),
                )
              else
                OverflowChip(
                  label: fit.visible[i],
                  accentColor: accentColor,
                  labelStyle: style,
                  isEmptyPlaceholder: isEmptyPlaceholder,
                ),
            ],
            if (fit.hiddenCount > 0) ...[
              const SizedBox(width: chipSpacing),
              OverflowChip(
                label: '+${fit.hiddenCount}',
                accentColor: accentColor,
                labelStyle: style,
                muted: true,
              ),
            ],
          ],
        );
      },
    );
  }

  static double measureChip(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + labelPadH * 2 + chipChrome;
  }

  static ({List<String> visible, int hiddenCount}) fitLabels(
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

    final overflowW = measureChip('+${names.length}', labelStyle);
    final fitted = <String>[];
    var used = 0.0;

    for (var i = 0; i < names.length; i++) {
      final chipW = measureChip(names[i], labelStyle);
      final spacing = fitted.isEmpty ? 0.0 : chipSpacing;
      final restAfterThis = names.length - i - 1;
      final reserveOverflow =
          restAfterThis > 0 ? overflowW + chipSpacing : 0.0;
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
}

class OverflowChip extends StatelessWidget {
  const OverflowChip({
    required this.label,
    required this.accentColor,
    required this.labelStyle,
    this.isEmptyPlaceholder = false,
    this.muted = false,
    super.key,
  });

  final String label;
  final Color accentColor;
  final TextStyle labelStyle;
  final bool isEmptyPlaceholder;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
      labelPadding: const EdgeInsets.symmetric(
        horizontal: OverflowChipRow.labelPadH,
      ),
      side: BorderSide(color: sideColor, width: 0.8),
      backgroundColor: bg,
      labelStyle: labelStyle.copyWith(color: fg),
      label: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
    );
  }
}
