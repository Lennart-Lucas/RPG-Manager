import '../../../catalog/data/catalog_models.dart';
import 'item_property_model.dart';

class ItemPropertyCatalogEntry {
  const ItemPropertyCatalogEntry({required this.item, required this.entry});

  final CatalogItem item;
  final ItemPropertyRecord entry;

  String get key => '${item.id}';
}

class ItemPropertyListEntry {
  const ItemPropertyListEntry._({this.header, this.catalogEntry});

  const ItemPropertyListEntry.header(String value) : this._(header: value);
  const ItemPropertyListEntry.item(ItemPropertyCatalogEntry value)
      : this._(catalogEntry: value);

  final String? header;
  final ItemPropertyCatalogEntry? catalogEntry;
}

class ItemPropertyRowEntry {
  const ItemPropertyRowEntry._({this.header, this.entries = const []});

  const ItemPropertyRowEntry.header(String value) : this._(header: value);
  const ItemPropertyRowEntry.items(List<ItemPropertyCatalogEntry> value)
      : this._(entries: value);

  final String? header;
  final List<ItemPropertyCatalogEntry> entries;
}

class ItemPropertiesDerivedViewData {
  const ItemPropertiesDerivedViewData({
    required this.allEntries,
    required this.entries,
  });

  final List<ItemPropertyCatalogEntry> allEntries;
  final List<ItemPropertyListEntry> entries;
}

String alphabeticalItemPropertyHeader(ItemPropertyRecord property) {
  final name = property.name.trim();
  if (name.isEmpty) return '#';
  final first = name.substring(0, 1).toUpperCase();
  final isLetter = RegExp(r'^[A-Z]$').hasMatch(first);
  return isLetter ? first : '#';
}

bool itemPropertyMatchesSearchQuery(
  ItemPropertyRecord property,
  String rawQuery,
) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return true;
  return property.name.toLowerCase().contains(q) ||
      property.description.toLowerCase().contains(q);
}

List<ItemPropertyListEntry> filterItemPropertyListEntriesBySearch(
  List<ItemPropertyListEntry> entries,
  String rawQuery,
) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return entries;

  final out = <ItemPropertyListEntry>[];
  var i = 0;
  while (i < entries.length) {
    final e = entries[i];
    if (e.header != null) {
      final header = e.header!;
      i++;
      final group = <ItemPropertyCatalogEntry>[];
      while (i < entries.length && entries[i].catalogEntry != null) {
        final entry = entries[i].catalogEntry!;
        if (itemPropertyMatchesSearchQuery(entry.entry, rawQuery)) {
          group.add(entry);
        }
        i++;
      }
      if (group.isNotEmpty) {
        out.add(ItemPropertyListEntry.header(header));
        for (final entry in group) {
          out.add(ItemPropertyListEntry.item(entry));
        }
      }
    } else if (e.catalogEntry != null) {
      if (itemPropertyMatchesSearchQuery(e.catalogEntry!.entry, rawQuery)) {
        out.add(ItemPropertyListEntry.item(e.catalogEntry!));
      }
      i++;
    } else {
      i++;
    }
  }
  return out;
}

List<ItemPropertyRowEntry> buildItemPropertyRowEntries(
  List<ItemPropertyListEntry> entries,
  int columns,
) {
  final result = <ItemPropertyRowEntry>[];
  var buffer = <ItemPropertyCatalogEntry>[];

  void flushBuffer() {
    if (buffer.isEmpty) return;
    result.add(
      ItemPropertyRowEntry.items(List<ItemPropertyCatalogEntry>.from(buffer)),
    );
    buffer.clear();
  }

  for (final entry in entries) {
    if (entry.header != null) {
      flushBuffer();
      result.add(ItemPropertyRowEntry.header(entry.header!));
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

ItemPropertiesDerivedViewData deriveItemPropertiesViewData({
  required List<ItemPropertyCatalogEntry> propertyEntries,
}) {
  final displayEntries = List<ItemPropertyCatalogEntry>.from(
    propertyEntries,
    growable: false,
  )..sort(
      (a, b) =>
          a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase()),
    );

  final grouped = <String, List<ItemPropertyCatalogEntry>>{};
  final orderedHeaders = <String>[];
  for (final entry in displayEntries) {
    final header = alphabeticalItemPropertyHeader(entry.entry);
    if (!grouped.containsKey(header)) {
      orderedHeaders.add(header);
      grouped[header] = <ItemPropertyCatalogEntry>[];
    }
    grouped[header]!.add(entry);
  }

  final listEntries = <ItemPropertyListEntry>[];
  for (final header in orderedHeaders) {
    listEntries.add(ItemPropertyListEntry.header(header));
    for (final entry in grouped[header]!) {
      listEntries.add(ItemPropertyListEntry.item(entry));
    }
  }

  return ItemPropertiesDerivedViewData(
    allEntries: propertyEntries,
    entries: listEntries,
  );
}
