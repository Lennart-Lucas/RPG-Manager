import 'package:flutter/material.dart';

import '../../../catalog/data/catalog_models.dart';
import 'feat_list_filters.dart';
import 'feat_model.dart';

enum FeatsSortMode {
  alphabetical(Icons.sort_by_alpha_outlined, 'Alphabetical');

  const FeatsSortMode(this.icon, this.label);

  final IconData icon;
  final String label;
}

class FeatCatalogEntry {
  const FeatCatalogEntry({required this.item, required this.entry});

  final CatalogItem item;
  final FeatRecord entry;

  String get key => '${item.id}';
}

class FeatListEntry {
  const FeatListEntry._({this.header, this.catalogEntry});

  const FeatListEntry.header(String value) : this._(header: value);
  const FeatListEntry.item(FeatCatalogEntry value)
      : this._(catalogEntry: value);

  final String? header;
  final FeatCatalogEntry? catalogEntry;
}

class FeatRowEntry {
  const FeatRowEntry._({this.header, this.entries = const []});

  const FeatRowEntry.header(String value) : this._(header: value);
  const FeatRowEntry.items(List<FeatCatalogEntry> value)
      : this._(entries: value);

  final String? header;
  final List<FeatCatalogEntry> entries;
}

class FeatsDerivedViewData {
  const FeatsDerivedViewData({
    required this.allEntries,
    required this.entries,
  });

  final List<FeatCatalogEntry> allEntries;
  final List<FeatListEntry> entries;
}

String alphabeticalFeatHeader(FeatRecord feat) {
  final name = feat.name.trim();
  if (name.isEmpty) return '#';
  final first = name.substring(0, 1).toUpperCase();
  final isLetter = RegExp(r'^[A-Z]$').hasMatch(first);
  return isLetter ? first : '#';
}

List<FeatCatalogEntry> sortFeatEntries(
  List<FeatCatalogEntry> entries,
  FeatsSortMode mode,
) {
  final sorted = List<FeatCatalogEntry>.from(entries, growable: false);
  sorted.sort((a, b) {
    return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
  });
  return sorted;
}

bool featMatchesSearchQuery(FeatRecord feat, String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return true;
  return feat.name.toLowerCase().contains(q) ||
      feat.requirement.toLowerCase().contains(q) ||
      feat.description.toLowerCase().contains(q);
}

List<FeatListEntry> filterFeatListEntriesBySearch(
  List<FeatListEntry> entries,
  String rawQuery,
) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return entries;

  final out = <FeatListEntry>[];
  var i = 0;
  while (i < entries.length) {
    final e = entries[i];
    if (e.header != null) {
      final header = e.header!;
      i++;
      final group = <FeatCatalogEntry>[];
      while (i < entries.length && entries[i].catalogEntry != null) {
        final entry = entries[i].catalogEntry!;
        if (featMatchesSearchQuery(entry.entry, rawQuery)) group.add(entry);
        i++;
      }
      if (group.isNotEmpty) {
        out.add(FeatListEntry.header(header));
        for (final entry in group) {
          out.add(FeatListEntry.item(entry));
        }
      }
    } else if (e.catalogEntry != null) {
      if (featMatchesSearchQuery(e.catalogEntry!.entry, rawQuery)) {
        out.add(FeatListEntry.item(e.catalogEntry!));
      }
      i++;
    } else {
      i++;
    }
  }
  return out;
}

List<FeatRowEntry> buildFeatRowEntries(
  List<FeatListEntry> entries,
  int columns,
) {
  final result = <FeatRowEntry>[];
  var buffer = <FeatCatalogEntry>[];

  void flushBuffer() {
    if (buffer.isEmpty) return;
    result.add(FeatRowEntry.items(List<FeatCatalogEntry>.from(buffer)));
    buffer.clear();
  }

  for (final entry in entries) {
    if (entry.header != null) {
      flushBuffer();
      result.add(FeatRowEntry.header(entry.header!));
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

FeatsDerivedViewData deriveFeatsViewData({
  required List<FeatCatalogEntry> featEntries,
  required FeatsListFilter filter,
  required FeatsSortMode sortMode,
}) {
  final filtered = filter.hasAny
      ? featEntries
          .where((entry) => filter.matchesFeat(entry.entry))
          .toList(growable: false)
      : List<FeatCatalogEntry>.from(featEntries, growable: false);

  final displayEntries = sortFeatEntries(filtered, sortMode);

  final grouped = <String, List<FeatCatalogEntry>>{};
  final orderedHeaders = <String>[];
  for (final entry in displayEntries) {
    final header = alphabeticalFeatHeader(entry.entry);
    if (!grouped.containsKey(header)) {
      orderedHeaders.add(header);
      grouped[header] = <FeatCatalogEntry>[];
    }
    grouped[header]!.add(entry);
  }

  final listEntries = <FeatListEntry>[];
  for (final header in orderedHeaders) {
    listEntries.add(FeatListEntry.header(header));
    for (final entry in grouped[header]!) {
      listEntries.add(FeatListEntry.item(entry));
    }
  }

  return FeatsDerivedViewData(
    allEntries: featEntries,
    entries: listEntries,
  );
}
