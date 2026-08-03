import 'package:flutter/material.dart';

import '../../../../core/ui/simple_card_rich_text.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../world_icons.dart';
import '../data/organisation_model.dart';

/// Wikipedia-style overview / infobox for an organisation.
class OrganisationOverviewBox extends StatelessWidget {
  const OrganisationOverviewBox({
    super.key,
    required this.record,
    this.seat,
    this.parentBody,
    required this.onSeatTap,
    required this.onParentTap,
    this.onWikiLinkTap,
  });

  final OrganisationRecord record;
  final CatalogItem? seat;
  final CatalogItem? parentBody;
  final ValueChanged<CatalogItem> onSeatTap;
  final ValueChanged<CatalogItem> onParentTap;
  final void Function(String kind, String name)? onWikiLinkTap;

  static const double preferredWidth = 300;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color lift(Color toward, double amount) =>
        Color.lerp(scheme.surface, toward, amount)!;

    final panelBg = lift(scheme.onSurface, 0.07);
    final sectionHeaderBg = scheme.primaryContainer;
    final labelBg = scheme.surfaceContainer;
    final valueBg = lift(scheme.onSurface, 0.16);
    final borderColor = scheme.outline.withValues(alpha: 0.55);

    final detailRows = <_OverviewRow>[
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
                      organisationsPageIcon,
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
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        organisationsPageIcon,
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
            ),
            if (detailRows.isNotEmpty)
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
                            row: detailRows[i],
                            labelBg: labelBg,
                            valueBg: valueBg,
                            borderColor: borderColor,
                            showDivider: i < detailRows.length - 1,
                            onWikiLinkTap: onWikiLinkTap,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OverviewRow {
  const _OverviewRow._({
    required this.label,
    this.value,
    this.markdown,
    this.onTap,
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

  final String label;
  final String? value;
  final String? markdown;
  final VoidCallback? onTap;

  bool get isLink => onTap != null;
  bool get isMarkdown => markdown != null;
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
    required this.row,
    required this.labelBg,
    required this.valueBg,
    required this.borderColor,
    this.showDivider = true,
    this.onWikiLinkTap,
  });

  final _OverviewRow row;
  final Color labelBg;
  final Color valueBg;
  final Color borderColor;
  final bool showDivider;
  final void Function(String kind, String name)? onWikiLinkTap;

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
                        alignment: Alignment.centerLeft,
                        child: row.isMarkdown
                            ? SimpleCardRichText(
                                content: row.markdown!,
                                baseStyle: valueStyle,
                                onWikiLinkTap: onWikiLinkTap,
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
