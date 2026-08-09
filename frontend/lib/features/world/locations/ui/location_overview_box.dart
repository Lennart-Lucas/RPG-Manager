import 'package:flutter/material.dart';

import '../../../../core/ui/catalog_image_slot.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../ui/overview_sections.dart';
import '../../ui/overview_sections_view.dart';
import '../../world_icons.dart';
import '../data/location_model.dart';

class LocationAncestorRow {
  const LocationAncestorRow({
    required this.typeLabel,
    required this.item,
  });

  final String typeLabel;
  final CatalogItem item;
}

/// Wikipedia-style overview / infobox for a location.
class LocationOverviewBox extends StatelessWidget {
  const LocationOverviewBox({
    super.key,
    required this.auth,
    required this.record,
    required this.ancestors,
    required this.onAncestorTap,
  });

  final AuthController auth;
  final LocationRecord record;
  final List<LocationAncestorRow> ancestors;
  final ValueChanged<CatalogItem> onAncestorTap;

  static const double preferredWidth = 300;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasLocationSection = ancestors.isNotEmpty;
    final overviewSplit = splitOverviewDetailsSections(record.overviewSections);
    final mergedDetails = overviewSplit.detailsItems;
    final otherOverviewSections = overviewSplit.otherSections;

    Color lift(Color toward, double amount) =>
        Color.lerp(scheme.surface, toward, amount)!;

    final panelBg = lift(scheme.onSurface, 0.07);
    final sectionHeaderBg = scheme.primaryContainer;
    final labelBg = scheme.surfaceContainer;
    final valueBg = lift(scheme.onSurface, 0.16);
    final borderColor = scheme.outline.withValues(alpha: 0.55);

    return Material(
      color: panelBg,
      elevation: 1,
      shadowColor: scheme.shadow.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    child: Icon(
                      Icons.place_outlined,
                      color: scheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.name,
                          style: textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (record.aliases.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            record.aliases.join(', '),
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: borderColor),
            Padding(
              padding: const EdgeInsets.all(14),
              child: CatalogImageSlot(
                imageUrl: record.imageUrl,
                borderColor: borderColor,
                placeholder: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      atlasPageIcon,
                      size: 40,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Image placeholder',
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      record.name,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
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
                      if (hasLocationSection) ...[
                        _SectionHeader(
                          title: 'Location',
                          background: sectionHeaderBg,
                          foreground: scheme.onPrimaryContainer,
                        ),
                        for (var i = 0; i < ancestors.length; i++)
                          _InfoRow(
                            label: ancestors[i].typeLabel,
                            value: ancestors[i].item.name,
                            labelBg: labelBg,
                            valueBg: valueBg,
                            borderColor: borderColor,
                            link: true,
                            showDivider: true,
                            onTap: () => onAncestorTap(ancestors[i].item),
                          ),
                      ],
                      _SectionHeader(
                        title: 'Details',
                        background: sectionHeaderBg,
                        foreground: scheme.onPrimaryContainer,
                      ),
                      _InfoRow(
                        label: 'Type',
                        value: record.type.label,
                        labelBg: labelBg,
                        valueBg: valueBg,
                        borderColor: borderColor,
                        showDivider: mergedDetails.isNotEmpty,
                      ),
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
            if (otherOverviewSections.isNotEmpty)
              OverviewSectionsView(
                auth: auth,
                sections: otherOverviewSections,
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.background,
    required this.foreground,
  });

  final String title;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.labelBg,
    required this.valueBg,
    required this.borderColor,
    this.link = false,
    this.showDivider = true,
    this.onTap,
  });

  final String label;
  final String value;
  final Color labelBg;
  final Color valueBg;
  final Color borderColor;
  final bool link;
  final bool showDivider;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final labelStyle = textTheme.bodyMedium?.copyWith(
      color: scheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = textTheme.bodyMedium?.copyWith(
      color: link ? scheme.primary : scheme.onSurface,
      fontWeight: link ? FontWeight.w600 : FontWeight.w500,
      decoration: link ? TextDecoration.underline : TextDecoration.none,
      decorationColor: link ? scheme.primary : null,
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
                      child: Text(label, style: labelStyle),
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
                child: Material(
                  color: valueBg,
                  child: InkWell(
                    onTap: link ? onTap : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(value, style: valueStyle),
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
