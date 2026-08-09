import 'package:flutter/material.dart';

import '../../../../core/ui/catalog_image_slot.dart';
import '../../../auth/state/auth_controller.dart';
import '../../ui/overview_sections.dart';
import '../../ui/overview_sections_view.dart';
import '../../world_icons.dart';
import '../data/character_model.dart';
import 'mtg_alignment_chips.dart';

/// Wikipedia-style overview / infobox for a character.
class CharacterOverviewBox extends StatelessWidget {
  const CharacterOverviewBox({
    super.key,
    required this.auth,
    required this.record,
    this.raceName,
    this.onRaceTap,
  });

  final AuthController auth;
  final CharacterRecord record;
  final String? raceName;
  final VoidCallback? onRaceTap;

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
      if (record.mtgAlignment.isNotEmpty)
        _OverviewRow.alignment(colors: record.mtgAlignment),
      if (raceName != null && raceName!.trim().isNotEmpty)
        onRaceTap != null
            ? _OverviewRow.link(
                label: 'Race',
                value: raceName!,
                onTap: onRaceTap!,
              )
            : _OverviewRow.text(label: 'Race', value: raceName!),
      if (record.playerName.trim().isNotEmpty)
        _OverviewRow.text(label: 'Player', value: record.playerName.trim()),
    ];
    final overviewSplit = splitOverviewDetailsSections(record.overviewSections);
    final mergedDetails = overviewSplit.detailsItems;
    final otherOverviewSections = overviewSplit.otherSections;
    final hasDetailsBlock =
        detailRows.isNotEmpty || mergedDetails.isNotEmpty;

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
                      charactersPageIcon,
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
                      charactersPageIcon,
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

class _OverviewRow {
  const _OverviewRow._({
    required this.label,
    this.value,
    this.onTap,
    this.alignmentColors,
  });

  const _OverviewRow.text({
    required String label,
    required String value,
  }) : this._(label: label, value: value);

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
  final VoidCallback? onTap;
  final List<MtgColor>? alignmentColors;

  bool get isLink => onTap != null;
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
    required this.row,
    required this.labelBg,
    required this.valueBg,
    required this.borderColor,
    this.showDivider = true,
  });

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
