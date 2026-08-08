import '../../../catalog/data/catalog_models.dart';
import '../../data/styled_mechanics_record.dart';

class ConditionCatalogEntry {
  const ConditionCatalogEntry({required this.item, required this.entry});

  final CatalogItem item;
  final StyledMechanicsRecord entry;

  String get key => '${item.id}';
}

class ConditionListEntry {
  const ConditionListEntry._({this.header, this.catalogEntry});

  const ConditionListEntry.header(String value) : this._(header: value);
  const ConditionListEntry.item(ConditionCatalogEntry value)
      : this._(catalogEntry: value);

  final String? header;
  final ConditionCatalogEntry? catalogEntry;
}

class ConditionRowEntry {
  const ConditionRowEntry._({this.header, this.entries = const []});

  const ConditionRowEntry.header(String value) : this._(header: value);
  const ConditionRowEntry.items(List<ConditionCatalogEntry> value)
      : this._(entries: value);

  final String? header;
  final List<ConditionCatalogEntry> entries;
}

class ConditionsDerivedViewData {
  const ConditionsDerivedViewData({
    required this.allEntries,
    required this.entries,
  });

  final List<ConditionCatalogEntry> allEntries;
  final List<ConditionListEntry> entries;
}

String alphabeticalConditionHeader(StyledMechanicsRecord record) {
  final name = record.name.trim();
  if (name.isEmpty) return '#';
  final first = name.substring(0, 1).toUpperCase();
  final isLetter = RegExp(r'^[A-Z]$').hasMatch(first);
  return isLetter ? first : '#';
}

bool conditionMatchesSearchQuery(
  StyledMechanicsRecord record,
  String rawQuery,
) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return true;
  return record.name.toLowerCase().contains(q) ||
      record.description.toLowerCase().contains(q);
}

List<ConditionListEntry> filterConditionListEntriesBySearch(
  List<ConditionListEntry> entries,
  String rawQuery,
) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return entries;

  final out = <ConditionListEntry>[];
  var i = 0;
  while (i < entries.length) {
    final e = entries[i];
    if (e.header != null) {
      final header = e.header!;
      i++;
      final group = <ConditionCatalogEntry>[];
      while (i < entries.length && entries[i].catalogEntry != null) {
        final entry = entries[i].catalogEntry!;
        if (conditionMatchesSearchQuery(entry.entry, rawQuery)) {
          group.add(entry);
        }
        i++;
      }
      if (group.isNotEmpty) {
        out.add(ConditionListEntry.header(header));
        for (final entry in group) {
          out.add(ConditionListEntry.item(entry));
        }
      }
    } else if (e.catalogEntry != null) {
      if (conditionMatchesSearchQuery(e.catalogEntry!.entry, rawQuery)) {
        out.add(ConditionListEntry.item(e.catalogEntry!));
      }
      i++;
    } else {
      i++;
    }
  }
  return out;
}

List<ConditionRowEntry> buildConditionRowEntries(
  List<ConditionListEntry> entries,
  int columns,
) {
  final result = <ConditionRowEntry>[];
  var buffer = <ConditionCatalogEntry>[];

  void flushBuffer() {
    if (buffer.isEmpty) return;
    result.add(
      ConditionRowEntry.items(List<ConditionCatalogEntry>.from(buffer)),
    );
    buffer.clear();
  }

  for (final entry in entries) {
    if (entry.header != null) {
      flushBuffer();
      result.add(ConditionRowEntry.header(entry.header!));
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

ConditionsDerivedViewData deriveConditionsViewData({
  required List<ConditionCatalogEntry> conditionEntries,
}) {
  final displayEntries = List<ConditionCatalogEntry>.from(
    conditionEntries,
    growable: false,
  )..sort(
      (a, b) =>
          a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase()),
    );

  final grouped = <String, List<ConditionCatalogEntry>>{};
  final orderedHeaders = <String>[];
  for (final entry in displayEntries) {
    final header = alphabeticalConditionHeader(entry.entry);
    if (!grouped.containsKey(header)) {
      orderedHeaders.add(header);
      grouped[header] = <ConditionCatalogEntry>[];
    }
    grouped[header]!.add(entry);
  }

  final listEntries = <ConditionListEntry>[];
  for (final header in orderedHeaders) {
    listEntries.add(ConditionListEntry.header(header));
    for (final entry in grouped[header]!) {
      listEntries.add(ConditionListEntry.item(entry));
    }
  }

  return ConditionsDerivedViewData(
    allEntries: conditionEntries,
    entries: listEntries,
  );
}
