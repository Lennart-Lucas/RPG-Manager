import 'package:flutter/material.dart';

import '../data/spell_list_derived_data.dart';
import 'spell_list_item_card.dart';

class SpellListSectionHeader extends StatelessWidget {
  const SpellListSectionHeader({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Responsive spell card grid.
class SpellRecordListView extends StatelessWidget {
  const SpellRecordListView({
    required this.totalSpells,
    required this.entries,
    required this.classNamesBySpellKey,
    required this.tagEntriesBySpellKey,
    required this.onSpellPrimaryTap,
    this.onSpellLongPress,
    this.selectedSpellIds = const {},
    this.selectionEmphasis = false,
    this.bottomPadding = 88,
    this.horizontalPadding = 10,
    this.minItemWidth = 280,
    this.maxItemWidth = 1060,
    this.hasActiveSearch = false,
    this.noMatchingFiltersMessage,
    this.onRefresh,
    super.key,
  });

  final int totalSpells;
  final List<SpellListEntry> entries;
  final Map<String, List<String>> classNamesBySpellKey;
  final Map<String, List<({String id, String name})>> tagEntriesBySpellKey;
  final void Function(SpellCatalogEntry entry) onSpellPrimaryTap;
  final void Function(SpellCatalogEntry entry)? onSpellLongPress;
  final Set<String> selectedSpellIds;
  final bool selectionEmphasis;
  final double bottomPadding;
  final double horizontalPadding;
  final double minItemWidth;
  final double maxItemWidth;
  final bool hasActiveSearch;
  final String? noMatchingFiltersMessage;
  final Future<void> Function()? onRefresh;

  String _emptyMessage() {
    if (totalSpells == 0) {
      return 'No spells yet.';
    }
    if (hasActiveSearch) {
      return 'No spells match your search.';
    }
    return noMatchingFiltersMessage ?? 'No spells match these filters.';
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      final empty = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _emptyMessage(),
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
      if (onRefresh == null) return empty;
      return RefreshIndicator(
        onRefresh: onRefresh!,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.3),
            empty,
          ],
        ),
      );
    }

    const itemSpacing = 10.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - (horizontalPadding * 2);
        final desiredColumns =
            ((availableWidth + itemSpacing) / (minItemWidth + itemSpacing))
                .floor()
                .clamp(1, 3);
        final rowEntries = buildSpellRowEntries(entries, desiredColumns);

        Widget rowAt(int index) {
          final rowEntry = rowEntries[index];
          if (rowEntry.header != null) {
            return SpellListSectionHeader(text: rowEntry.header!);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < rowEntry.entries.length; i++) ...[
                if (i > 0) const SizedBox(width: itemSpacing),
                Expanded(
                  child: SpellListItemCard(
                    spell: rowEntry.entries[i].spell,
                    classNames: classNamesBySpellKey[rowEntry.entries[i].key] ??
                        const <String>[],
                    tagEntries:
                        tagEntriesBySpellKey[rowEntry.entries[i].key] ??
                            const <({String id, String name})>[],
                    minWidth: minItemWidth,
                    maxWidth: maxItemWidth,
                    selected:
                        selectedSpellIds.contains(rowEntry.entries[i].key),
                    selectionEmphasis: selectionEmphasis,
                    onTap: () => onSpellPrimaryTap(rowEntry.entries[i]),
                    onLongPress: onSpellLongPress == null
                        ? null
                        : () => onSpellLongPress!(rowEntry.entries[i]),
                  ),
                ),
              ],
              for (var i = rowEntry.entries.length; i < desiredColumns; i++) ...[
                const SizedBox(width: itemSpacing),
                const Expanded(child: SizedBox.shrink()),
              ],
            ],
          );
        }

        final list = CustomScrollView(
          physics: onRefresh == null
              ? null
              : const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                bottomPadding,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => rowAt(index),
                  childCount: rowEntries.length,
                ),
              ),
            ),
          ],
        );

        if (onRefresh == null) return list;
        return RefreshIndicator(onRefresh: onRefresh!, child: list);
      },
    );
  }
}
