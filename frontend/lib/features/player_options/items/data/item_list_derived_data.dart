import 'package:flutter/material.dart';

import '../../../catalog/data/catalog_models.dart';
import 'item_list_filters.dart';
import 'item_model.dart';

enum ItemsSortMode {
  alphabetical(Icons.sort_by_alpha_outlined, 'Alphabetical'),
  byType(Icons.category_outlined, 'By type'),
  byRarity(Icons.diamond_outlined, 'By rarity');

  const ItemsSortMode(this.icon, this.label);

  final IconData icon;
  final String label;
}

class ItemCatalogEntry {
  const ItemCatalogEntry({required this.item, required this.entry});

  final CatalogItem item;
  final Item entry;

  String get key => '${item.id}';
}

class ItemListEntry {
  const ItemListEntry._({this.header, this.catalogEntry});

  const ItemListEntry.header(String value) : this._(header: value);
  const ItemListEntry.item(ItemCatalogEntry value)
      : this._(catalogEntry: value);

  final String? header;
  final ItemCatalogEntry? catalogEntry;
}

class ItemRowEntry {
  const ItemRowEntry._({this.header, this.entries = const []});

  const ItemRowEntry.header(String value) : this._(header: value);
  const ItemRowEntry.items(List<ItemCatalogEntry> value)
      : this._(entries: value);

  final String? header;
  final List<ItemCatalogEntry> entries;
}

class ItemsDerivedViewData {
  const ItemsDerivedViewData({
    required this.allEntries,
    required this.entries,
  });

  final List<ItemCatalogEntry> allEntries;
  final List<ItemListEntry> entries;
}

String alphabeticalHeader(Item item) {
  final name = item.name.trim();
  if (name.isEmpty) return '#';
  final first = name.substring(0, 1).toUpperCase();
  final isLetter = RegExp(r'^[A-Z]$').hasMatch(first);
  return isLetter ? first : '#';
}

String typeHeader(ItemType type) => type.label;

String rarityHeader(ItemRarity rarity) => rarity.label;

List<ItemCatalogEntry> sortItemEntries(
  List<ItemCatalogEntry> entries,
  ItemsSortMode mode,
) {
  final sorted = List<ItemCatalogEntry>.from(entries, growable: false);
  sorted.sort((a, b) {
    switch (mode) {
      case ItemsSortMode.alphabetical:
        return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
      case ItemsSortMode.byType:
        final typeCompare =
            a.entry.itemType.label.compareTo(b.entry.itemType.label);
        if (typeCompare != 0) return typeCompare;
        return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
      case ItemsSortMode.byRarity:
        final rarityCompare = _raritySortIndex(a.entry.rarity)
            .compareTo(_raritySortIndex(b.entry.rarity));
        if (rarityCompare != 0) return rarityCompare;
        return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
    }
  });
  return sorted;
}

int _raritySortIndex(ItemRarity rarity) {
  return switch (rarity) {
    ItemRarity.common => 0,
    ItemRarity.uncommon => 1,
    ItemRarity.rare => 2,
    ItemRarity.veryRare => 3,
    ItemRarity.legendary => 4,
    ItemRarity.artifact => 5,
  };
}

bool itemMatchesSearchQuery(Item item, String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return true;
  return item.name.toLowerCase().contains(q) ||
      item.description.toLowerCase().contains(q);
}

List<ItemListEntry> filterItemListEntriesBySearch(
  List<ItemListEntry> entries,
  String rawQuery,
) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return entries;

  final out = <ItemListEntry>[];
  var i = 0;
  while (i < entries.length) {
    final e = entries[i];
    if (e.header != null) {
      final header = e.header!;
      i++;
      final group = <ItemCatalogEntry>[];
      while (i < entries.length && entries[i].catalogEntry != null) {
        final entry = entries[i].catalogEntry!;
        if (itemMatchesSearchQuery(entry.entry, rawQuery)) group.add(entry);
        i++;
      }
      if (group.isNotEmpty) {
        out.add(ItemListEntry.header(header));
        for (final entry in group) {
          out.add(ItemListEntry.item(entry));
        }
      }
    } else if (e.catalogEntry != null) {
      if (itemMatchesSearchQuery(e.catalogEntry!.entry, rawQuery)) {
        out.add(ItemListEntry.item(e.catalogEntry!));
      }
      i++;
    } else {
      i++;
    }
  }
  return out;
}

List<ItemRowEntry> buildItemRowEntries(
  List<ItemListEntry> entries,
  int columns,
) {
  final result = <ItemRowEntry>[];
  var buffer = <ItemCatalogEntry>[];

  void flushBuffer() {
    if (buffer.isEmpty) return;
    result.add(ItemRowEntry.items(List<ItemCatalogEntry>.from(buffer)));
    buffer.clear();
  }

  for (final entry in entries) {
    if (entry.header != null) {
      flushBuffer();
      result.add(ItemRowEntry.header(entry.header!));
      continue;
    }
    buffer.add(entry.catalogEntry!);
    if (buffer.length == columns) {
      flushBuffer();
    }
  }
  flushBuffer();
  return result;
}

ItemsDerivedViewData deriveItemsViewData({
  required List<ItemCatalogEntry> itemEntries,
  required ItemsListFilter filter,
  required ItemsSortMode sortMode,
}) {
  final filtered = filter.hasAny
      ? itemEntries
          .where((entry) => filter.matchesItem(entry.entry))
          .toList(growable: false)
      : List<ItemCatalogEntry>.from(itemEntries, growable: false);

  final displayEntries = sortItemEntries(filtered, sortMode);

  final grouped = <String, List<ItemCatalogEntry>>{};
  final orderedHeaders = <String>[];
  for (final entry in displayEntries) {
    final header = switch (sortMode) {
      ItemsSortMode.alphabetical => alphabeticalHeader(entry.entry),
      ItemsSortMode.byType => typeHeader(entry.entry.itemType),
      ItemsSortMode.byRarity => rarityHeader(entry.entry.rarity),
    };
    if (!grouped.containsKey(header)) {
      orderedHeaders.add(header);
      grouped[header] = <ItemCatalogEntry>[];
    }
    grouped[header]!.add(entry);
  }

  final listEntries = <ItemListEntry>[];
  for (final header in orderedHeaders) {
    listEntries.add(ItemListEntry.header(header));
    for (final entry in grouped[header]!) {
      listEntries.add(ItemListEntry.item(entry));
    }
  }

  return ItemsDerivedViewData(
    allEntries: itemEntries,
    entries: listEntries,
  );
}
