import 'package:flutter/material.dart';

import '../data/item_list_derived_data.dart';
import 'item_list_item_card.dart';

class ItemListSectionHeader extends StatelessWidget {
  const ItemListSectionHeader({required this.text, super.key});

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

class ItemRecordListView extends StatelessWidget {
  const ItemRecordListView({
    required this.totalItems,
    required this.entries,
    required this.onItemPrimaryTap,
    this.onItemLongPress,
    this.selectedItemIds = const {},
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

  final int totalItems;
  final List<ItemListEntry> entries;
  final void Function(ItemCatalogEntry entry) onItemPrimaryTap;
  final void Function(ItemCatalogEntry entry)? onItemLongPress;
  final Set<String> selectedItemIds;
  final bool selectionEmphasis;
  final double bottomPadding;
  final double horizontalPadding;
  final double minItemWidth;
  final double maxItemWidth;
  final bool hasActiveSearch;
  final String? noMatchingFiltersMessage;
  final Future<void> Function()? onRefresh;

  String _emptyMessage() {
    if (totalItems == 0) {
      return 'No items yet.';
    }
    if (hasActiveSearch) {
      return 'No items match your search.';
    }
    return noMatchingFiltersMessage ?? 'No items match these filters.';
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
        final rowEntries = buildItemRowEntries(entries, desiredColumns);

        Widget rowAt(int index) {
          final rowEntry = rowEntries[index];
          if (rowEntry.header != null) {
            return ItemListSectionHeader(text: rowEntry.header!);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < rowEntry.entries.length; i++) ...[
                if (i > 0) const SizedBox(width: itemSpacing),
                Expanded(
                  child: ItemListItemCard(
                    item: rowEntry.entries[i].entry,
                    minWidth: minItemWidth,
                    maxWidth: maxItemWidth,
                    selected:
                        selectedItemIds.contains(rowEntry.entries[i].key),
                    selectionEmphasis: selectionEmphasis,
                    onTap: () => onItemPrimaryTap(rowEntry.entries[i]),
                    onLongPress: onItemLongPress == null
                        ? null
                        : () => onItemLongPress!(rowEntry.entries[i]),
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
