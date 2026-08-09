import 'package:flutter/material.dart';

import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../ui/catalog_overview_box.dart';
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

  static const double preferredWidth = CatalogOverviewBox.preferredWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLocationSection = ancestors.isNotEmpty;
    final overviewSplit = splitOverviewDetailsSections(record.overviewSections);
    final mergedDetails = overviewSplit.detailsItems;
    final otherOverviewSections = overviewSplit.otherSections;

    Color lift(Color toward, double amount) =>
        Color.lerp(scheme.surface, toward, amount)!;

    final sectionHeaderBg = scheme.primaryContainer;
    final labelBg = scheme.surfaceContainer;
    final valueBg = lift(scheme.onSurface, 0.16);
    final borderColor = scheme.outline.withValues(alpha: 0.55);

    return CatalogOverviewBox(
      auth: auth,
      title: record.name,
      icon: atlasPageIcon,
      aliases: record.aliases,
      imageUrl: record.imageUrl,
      leading: [
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
      ],
      overviewSections: otherOverviewSections,
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
