import 'package:flutter/material.dart';

import '../../../catalog/data/catalog_models.dart';
import '../data/spell_display.dart';
import '../data/spell_list_filters.dart';
import '../data/spell_model.dart';

/// Sort mode for grouped spell lists.
enum SpellsSortMode {
  alphabetical(Icons.sort_by_alpha_outlined, 'Alphabetical'),
  byLevel(Icons.stacked_bar_chart_outlined, 'By level');

  const SpellsSortMode(this.icon, this.label);

  final IconData icon;
  final String label;
}

/// A catalog spell row with its parsed payload.
class SpellCatalogEntry {
  const SpellCatalogEntry({required this.item, required this.spell});

  final CatalogItem item;
  final Spell spell;

  String get key => '${item.id}';
}

/// One row in the grouped spell list: either a section header or a spell.
class SpellListEntry {
  const SpellListEntry._({this.header, this.entry});

  const SpellListEntry.header(String value) : this._(header: value);
  const SpellListEntry.spell(SpellCatalogEntry value) : this._(entry: value);

  final String? header;
  final SpellCatalogEntry? entry;
}

/// Spell cards grouped into a horizontal row for the responsive grid.
class SpellRowEntry {
  const SpellRowEntry._({this.header, this.entries = const []});

  const SpellRowEntry.header(String value) : this._(header: value);
  const SpellRowEntry.spells(List<SpellCatalogEntry> value)
      : this._(entries: value);

  final String? header;
  final List<SpellCatalogEntry> entries;
}

class SpellsDerivedViewData {
  const SpellsDerivedViewData({
    required this.allEntries,
    required this.classNamesById,
    required this.spellTagNamesById,
    required this.damageTypeNamesById,
    required this.conditionNamesById,
    required this.classNamesBySpellKey,
    required this.tagEntriesBySpellKey,
    required this.entries,
  });

  final List<SpellCatalogEntry> allEntries;
  final Map<String, String> classNamesById;
  final Map<String, String> spellTagNamesById;
  final Map<String, String> damageTypeNamesById;
  final Map<String, String> conditionNamesById;
  final Map<String, List<String>> classNamesBySpellKey;
  final Map<String, List<({String id, String name})>> tagEntriesBySpellKey;
  final List<SpellListEntry> entries;
}

String alphabeticalHeader(Spell spell) {
  final name = spell.name.trim();
  if (name.isEmpty) return '#';
  final first = name.substring(0, 1).toUpperCase();
  final isLetter = RegExp(r'^[A-Z]$').hasMatch(first);
  return isLetter ? first : '#';
}

String levelHeader(int level) {
  if (level == 0) return 'Cantrips';
  return spellLevelDisplayName(level);
}

List<SpellCatalogEntry> sortSpellEntries(
  List<SpellCatalogEntry> entries,
  SpellsSortMode mode,
) {
  final sorted = List<SpellCatalogEntry>.from(entries, growable: false);
  sorted.sort((a, b) {
    switch (mode) {
      case SpellsSortMode.alphabetical:
        return a.spell.name.toLowerCase().compareTo(b.spell.name.toLowerCase());
      case SpellsSortMode.byLevel:
        final levelCompare = a.spell.level.compareTo(b.spell.level);
        if (levelCompare != 0) return levelCompare;
        return a.spell.name.toLowerCase().compareTo(b.spell.name.toLowerCase());
    }
  });
  return sorted;
}

bool spellMatchesSearchQuery(Spell spell, String rawQuery) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return true;
  return spell.name.toLowerCase().contains(q) ||
      spell.description.toLowerCase().contains(q);
}

List<SpellListEntry> filterSpellListEntriesBySearch(
  List<SpellListEntry> entries,
  String rawQuery,
) {
  final q = rawQuery.trim().toLowerCase();
  if (q.isEmpty) return entries;

  final out = <SpellListEntry>[];
  var i = 0;
  while (i < entries.length) {
    final e = entries[i];
    if (e.header != null) {
      final header = e.header!;
      i++;
      final group = <SpellCatalogEntry>[];
      while (i < entries.length && entries[i].entry != null) {
        final s = entries[i].entry!;
        if (spellMatchesSearchQuery(s.spell, rawQuery)) group.add(s);
        i++;
      }
      if (group.isNotEmpty) {
        out.add(SpellListEntry.header(header));
        for (final s in group) {
          out.add(SpellListEntry.spell(s));
        }
      }
    } else if (e.entry != null) {
      if (spellMatchesSearchQuery(e.entry!.spell, rawQuery)) {
        out.add(SpellListEntry.spell(e.entry!));
      }
      i++;
    } else {
      i++;
    }
  }
  return out;
}

List<SpellRowEntry> buildSpellRowEntries(
  List<SpellListEntry> entries,
  int columns,
) {
  final result = <SpellRowEntry>[];
  var buffer = <SpellCatalogEntry>[];

  void flushBuffer() {
    if (buffer.isEmpty) return;
    result.add(SpellRowEntry.spells(List<SpellCatalogEntry>.from(buffer)));
    buffer.clear();
  }

  for (final entry in entries) {
    if (entry.header != null) {
      flushBuffer();
      result.add(SpellRowEntry.header(entry.header!));
      continue;
    }
    buffer.add(entry.entry!);
    if (buffer.length == columns) {
      flushBuffer();
    }
  }
  flushBuffer();
  return result;
}

SpellsDerivedViewData deriveSpellsViewData({
  required List<SpellCatalogEntry> spellEntries,
  required List<CatalogItem> casterClasses,
  required List<CatalogItem> spellTags,
  required List<CatalogItem> damageTypes,
  required List<CatalogItem> conditions,
  required SpellsListFilter filter,
  required SpellsSortMode sortMode,
}) {
  final classNamesById = {
    for (final c in casterClasses)
      '${c.id}': c.name.trim().isEmpty ? '${c.id}' : c.name,
  };
  final spellTagNamesById = {
    for (final t in spellTags)
      '${t.id}': t.name.trim().isEmpty ? '${t.id}' : t.name,
  };
  final damageTypeNamesById = {
    for (final d in damageTypes)
      '${d.id}': d.name.trim().isEmpty ? '${d.id}' : d.name,
  };
  final conditionNamesById = {
    for (final c in conditions)
      '${c.id}': c.name.trim().isEmpty ? '${c.id}' : c.name,
  };

  final classNamesBySpellKey = <String, List<String>>{};
  final tagEntriesBySpellKey =
      <String, List<({String id, String name})>>{};
  for (final entry in spellEntries) {
    final spell = entry.spell;
    final classNames = spell.classIds
        .map((id) => classNamesById['$id'])
        .whereType<String>()
        .toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    classNamesBySpellKey[entry.key] = classNames;

    final tagEntries = <({String id, String name})>[];
    for (final id in spell.tagIds) {
      final name = spellTagNamesById['$id'];
      if (name != null) {
        tagEntries.add((id: '$id', name: name));
      }
    }
    tagEntries.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    tagEntriesBySpellKey[entry.key] = tagEntries;
  }

  final damageTypePatterns = filter.selectedDamageTypeIds.isEmpty
      ? const <String, RegExp>{}
      : buildReferencedNamePatterns(
          selectedIds: filter.selectedDamageTypeIds,
          namesById: damageTypeNamesById,
        );
  final conditionPatterns = filter.selectedConditionIds.isEmpty
      ? const <String, RegExp>{}
      : buildReferencedNamePatterns(
          selectedIds: filter.selectedConditionIds,
          namesById: conditionNamesById,
        );
  final referenceScopeCache = <String, SpellReferenceScope>{};

  final filtered = filter.hasAny
      ? spellEntries
          .where((entry) {
            final scope = referenceScopeCache.putIfAbsent(
              entry.key,
              () => buildSpellReferenceScope(entry.spell),
            );
            return filter.matchesSpell(
              entry.spell,
              damageTypeNamesById: damageTypeNamesById,
              conditionNamesById: conditionNamesById,
              referenceScope: scope,
              damageTypeNamePatternsById: damageTypePatterns,
              conditionNamePatternsById: conditionPatterns,
            );
          })
          .toList(growable: false)
      : List<SpellCatalogEntry>.from(spellEntries, growable: false);

  final displayEntries = sortSpellEntries(filtered, sortMode);

  final grouped = <String, List<SpellCatalogEntry>>{};
  final orderedHeaders = <String>[];
  for (final entry in displayEntries) {
    final header = switch (sortMode) {
      SpellsSortMode.alphabetical => alphabeticalHeader(entry.spell),
      SpellsSortMode.byLevel => levelHeader(entry.spell.level),
    };
    if (!grouped.containsKey(header)) {
      orderedHeaders.add(header);
      grouped[header] = <SpellCatalogEntry>[];
    }
    grouped[header]!.add(entry);
  }

  final listEntries = <SpellListEntry>[];
  for (final header in orderedHeaders) {
    listEntries.add(SpellListEntry.header(header));
    for (final entry in grouped[header]!) {
      listEntries.add(SpellListEntry.spell(entry));
    }
  }

  return SpellsDerivedViewData(
    allEntries: spellEntries,
    classNamesById: classNamesById,
    spellTagNamesById: spellTagNamesById,
    damageTypeNamesById: damageTypeNamesById,
    conditionNamesById: conditionNamesById,
    classNamesBySpellKey: classNamesBySpellKey,
    tagEntriesBySpellKey: tagEntriesBySpellKey,
    entries: listEntries,
  );
}
