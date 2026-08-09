import 'package:flutter/material.dart';

import '../../auth/state/auth_controller.dart';
import '../../catalog/ui/catalog_rich_text.dart';
import 'overview_sections.dart';

/// Renders [overviewSections] as Wikipedia-style labeled rows inside an
/// overview box. Each section becomes its own bordered block.
class OverviewSectionsView extends StatelessWidget {
  const OverviewSectionsView({
    super.key,
    required this.auth,
    required this.sections,
    this.padding = const EdgeInsets.fromLTRB(14, 0, 14, 14),
  });

  final AuthController auth;
  final List<OverviewSection> sections;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeOverviewSections(sections);
    if (normalized.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    Color lift(Color toward, double amount) =>
        Color.lerp(scheme.surface, toward, amount)!;

    final sectionHeaderBg = scheme.primaryContainer;
    final labelBg = scheme.surfaceContainer;
    final valueBg = lift(scheme.onSurface, 0.16);
    final borderColor = scheme.outline.withValues(alpha: 0.55);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var s = 0; s < normalized.length; s++) ...[
            if (s > 0) const SizedBox(height: 12),
            DecoratedBox(
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
                          normalized[s].name.toUpperCase(),
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                        ),
                      ),
                    ),
                    for (var i = 0; i < normalized[s].items.length; i++)
                      OverviewItemRow(
                        auth: auth,
                        item: normalized[s].items[i],
                        labelBg: labelBg,
                        valueBg: valueBg,
                        borderColor: borderColor,
                        showDivider: i < normalized[s].items.length - 1,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A single label/value overview row (shared with built-in Details merges).
class OverviewItemRow extends StatelessWidget {
  const OverviewItemRow({
    super.key,
    required this.auth,
    required this.item,
    required this.labelBg,
    required this.valueBg,
    required this.borderColor,
    this.showDivider = true,
  });

  final AuthController auth;
  final OverviewItem item;
  final Color labelBg;
  final Color valueBg;
  final Color borderColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final labelStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w500,
    );

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: ColoredBox(
                  color: labelBg,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.name.trim().isEmpty ? '—' : item.name,
                        style: labelStyle,
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
                flex: 7,
                child: ColoredBox(
                  color: valueBg,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: item.description.trim().isEmpty
                          ? Text('—', style: valueStyle)
                          : CatalogRichText(
                              auth: auth,
                              content: item.description,
                              baseStyle: valueStyle,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, thickness: 1, color: borderColor),
      ],
    );
  }
}
