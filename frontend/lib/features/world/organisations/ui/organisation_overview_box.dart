import 'package:flutter/material.dart';

import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/ui/catalog_rich_text.dart';
import '../../characters/data/character_model.dart';
import '../../characters/ui/mtg_alignment_chips.dart';
import '../../ui/catalog_overview_box.dart';
import '../../ui/overview_sections.dart';
import '../../ui/overview_sections_view.dart';
import '../../world_icons.dart';
import '../data/organisation_model.dart';

/// Wikipedia-style overview / infobox for an organisation.
class OrganisationOverviewBox extends StatelessWidget {
  const OrganisationOverviewBox({
    super.key,
    required this.auth,
    required this.record,
    this.seat,
    this.parentBody,
    required this.onSeatTap,
    required this.onParentTap,
  });

  final AuthController auth;
  final OrganisationRecord record;
  final CatalogItem? seat;
  final CatalogItem? parentBody;
  final ValueChanged<CatalogItem> onSeatTap;
  final ValueChanged<CatalogItem> onParentTap;

  static const double preferredWidth = CatalogOverviewBox.preferredWidth;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color lift(Color toward, double amount) =>
        Color.lerp(scheme.surface, toward, amount)!;

    final sectionHeaderBg = scheme.primaryContainer;
    final labelBg = scheme.surfaceContainer;
    final valueBg = lift(scheme.onSurface, 0.16);
    final borderColor = scheme.outline.withValues(alpha: 0.55);

    final detailRows = <_OverviewRow>[
      if (record.mtgAlignment.isNotEmpty)
        _OverviewRow.alignment(colors: record.mtgAlignment),
      if (record.type.trim().isNotEmpty)
        _OverviewRow.markdown(label: 'Type', markdown: record.type),
      if (record.founding.trim().isNotEmpty)
        _OverviewRow.markdown(label: 'Founding', markdown: record.founding),
      if (record.motto.trim().isNotEmpty)
        _OverviewRow.markdown(label: 'Motto', markdown: record.motto),
      if (seat != null)
        _OverviewRow.link(
          label: 'Seat',
          value: seat!.name,
          onTap: () => onSeatTap(seat!),
        ),
      if (parentBody != null)
        _OverviewRow.link(
          label: 'Parent body',
          value: parentBody!.name,
          onTap: () => onParentTap(parentBody!),
        ),
    ];
    final overviewSplit = splitOverviewDetailsSections(record.overviewSections);
    final mergedDetails = overviewSplit.detailsItems;
    final otherOverviewSections = overviewSplit.otherSections;
    final hasDetailsBlock =
        detailRows.isNotEmpty || mergedDetails.isNotEmpty;

    return CatalogOverviewBox(
      auth: auth,
      title: record.name,
      icon: organisationsPageIcon,
      aliases: record.aliases,
      imageUrl: record.imageUrl,
      leading: [
        if (hasDetailsBlock)
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
                    _SectionHeader(
                      title: 'Details',
                      background: sectionHeaderBg,
                      foreground: scheme.onPrimaryContainer,
                    ),
                    for (var i = 0; i < detailRows.length; i++)
                      _InfoRow(
                        auth: auth,
                        row: detailRows[i],
                        labelBg: labelBg,
                        valueBg: valueBg,
                        borderColor: borderColor,
                        showDivider: i < detailRows.length - 1 ||
                            mergedDetails.isNotEmpty,
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

class _OverviewRow {
  const _OverviewRow._({
    required this.label,
    this.value,
    this.markdown,
    this.onTap,
    this.alignmentColors,
  });

  const _OverviewRow.markdown({
    required String label,
    required String markdown,
  }) : this._(label: label, markdown: markdown);

  const _OverviewRow.link({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) : this._(label: label, value: value, onTap: onTap);

  const _OverviewRow.alignment({
    required List<MtgColor> colors,
  }) : this._(label: 'Alignment', alignmentColors: colors);

  final String label;
  final String? value;
  final String? markdown;
  final VoidCallback? onTap;
  final List<MtgColor>? alignmentColors;

  bool get isLink => onTap != null;
  bool get isMarkdown => markdown != null;
  bool get isAlignment => alignmentColors != null;
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
    required this.auth,
    required this.row,
    required this.labelBg,
    required this.valueBg,
    required this.borderColor,
    this.showDivider = true,
  });

  final AuthController auth;
  final _OverviewRow row;
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
      color: row.isLink ? scheme.primary : scheme.onSurface,
      fontWeight: row.isLink ? FontWeight.w600 : FontWeight.w500,
      decoration: row.isLink ? TextDecoration.underline : TextDecoration.none,
      decorationColor: row.isLink ? scheme.primary : null,
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
                      child: Text(row.label, style: labelStyle),
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
                    onTap: row.isLink ? row.onTap : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Align(
                        alignment: row.isAlignment
                            ? Alignment.center
                            : Alignment.centerLeft,
                        child: row.isAlignment
                            ? MtgAlignmentChips(
                                colors: row.alignmentColors!,
                                size: 26,
                                wrapAlignment: WrapAlignment.center,
                              )
                            : row.isMarkdown
                                ? CatalogRichText(
                                    auth: auth,
                                    content: row.markdown!,
                                    baseStyle: valueStyle,
                                  )
                                : Text(row.value ?? '', style: valueStyle),
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
