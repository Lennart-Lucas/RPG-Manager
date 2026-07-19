import '../../../../core/markdown/wiki_link.dart';
import '../../../../core/ui/multi_picklist_sheet.dart';
import 'spell_display.dart';
import 'spell_model.dart';

List<PicklistOption> schoolPicklistOptions() {
  final schools = List<SpellSchool>.from(SpellSchool.values)
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return [
    for (final s in schools) PicklistOption(id: s.name, label: s.label),
  ];
}

List<PicklistOption> levelPicklistOptions() {
  return [
    for (var level = 0; level <= 9; level++)
      PicklistOption(
        id: '$level',
        label: spellLevelDisplayName(level),
      ),
  ];
}

List<PicklistOption> castingTypePicklistOptions() {
  const options = [
    ('action', 'Action'),
    ('bonus_action', 'Bonus Action'),
    ('reaction', 'Reaction'),
    ('minute', 'Minute(s)'),
    ('hour', 'Hour(s)'),
  ];
  return [
    for (final o in options) PicklistOption(id: o.$1, label: o.$2),
  ];
}

List<PicklistOption> catalogPicklistOptions(
  Iterable<({String id, String name})> items,
) {
  final sorted = items.toList()
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return [
    for (final item in sorted)
      PicklistOption(
        id: item.id,
        label: item.name.trim().isEmpty ? item.id : item.name,
      ),
  ];
}

enum SpellsConcentrationFilter { any, withoutConcentration, withConcentration }

typedef SpellReferenceScope = ({List<WikiLink> links, String searchTextLower});

/// Filters for the Spells list.
class SpellsListFilter {
  const SpellsListFilter({
    this.selectedSchoolCodes = const {},
    this.selectedLevelCodes = const {},
    this.selectedTagIds = const {},
    this.selectedClassIds = const {},
    this.selectedDamageTypeIds = const {},
    this.selectedConditionIds = const {},
    this.selectedCastingTypeCodes = const {},
    this.concentrationFilter = SpellsConcentrationFilter.any,
  });

  final Set<String> selectedSchoolCodes;
  final Set<String> selectedLevelCodes;
  final Set<String> selectedTagIds;
  final Set<String> selectedClassIds;
  final Set<String> selectedDamageTypeIds;
  final Set<String> selectedConditionIds;
  final Set<String> selectedCastingTypeCodes;
  final SpellsConcentrationFilter concentrationFilter;

  static const SpellsListFilter empty = SpellsListFilter();

  bool get hasAny =>
      selectedSchoolCodes.isNotEmpty ||
      selectedLevelCodes.isNotEmpty ||
      selectedTagIds.isNotEmpty ||
      selectedClassIds.isNotEmpty ||
      selectedDamageTypeIds.isNotEmpty ||
      selectedConditionIds.isNotEmpty ||
      selectedCastingTypeCodes.isNotEmpty ||
      concentrationFilter != SpellsConcentrationFilter.any;

  SpellsListFilter copyWith({
    Set<String>? selectedSchoolCodes,
    Set<String>? selectedLevelCodes,
    Set<String>? selectedTagIds,
    Set<String>? selectedClassIds,
    Set<String>? selectedDamageTypeIds,
    Set<String>? selectedConditionIds,
    Set<String>? selectedCastingTypeCodes,
    SpellsConcentrationFilter? concentrationFilter,
  }) {
    return SpellsListFilter(
      selectedSchoolCodes: selectedSchoolCodes ?? this.selectedSchoolCodes,
      selectedLevelCodes: selectedLevelCodes ?? this.selectedLevelCodes,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      selectedClassIds: selectedClassIds ?? this.selectedClassIds,
      selectedDamageTypeIds:
          selectedDamageTypeIds ?? this.selectedDamageTypeIds,
      selectedConditionIds: selectedConditionIds ?? this.selectedConditionIds,
      selectedCastingTypeCodes:
          selectedCastingTypeCodes ?? this.selectedCastingTypeCodes,
      concentrationFilter: concentrationFilter ?? this.concentrationFilter,
    );
  }

  bool matchesSpell(
    Spell spell, {
    Map<String, String>? damageTypeNamesById,
    Map<String, String>? conditionNamesById,
    SpellReferenceScope? referenceScope,
    Map<String, RegExp>? damageTypeNamePatternsById,
    Map<String, RegExp>? conditionNamePatternsById,
  }) {
    if (selectedSchoolCodes.isNotEmpty) {
      if (!selectedSchoolCodes.contains(spell.school.name)) {
        return false;
      }
    }
    if (selectedLevelCodes.isNotEmpty) {
      if (!selectedLevelCodes.contains('${spell.level}')) {
        return false;
      }
    }
    if (selectedTagIds.isNotEmpty) {
      final matchesAnyTag = spell.tagIds.any(
        (id) => selectedTagIds.contains('$id'),
      );
      if (!matchesAnyTag) return false;
    }
    if (selectedClassIds.isNotEmpty) {
      final matchesAnyClass = spell.classIds.any(
        (id) => selectedClassIds.contains('$id'),
      );
      if (!matchesAnyClass) return false;
    }
    final referenced = referenceScope ?? buildSpellReferenceScope(spell);
    if (selectedDamageTypeIds.isNotEmpty) {
      final matchesAnyDamageType = _matchesReferencedRecordSet(
        selectedIds: selectedDamageTypeIds,
        kindApiValues: const {'damage_types', 'damage_type'},
        links: referenced.links,
        searchTextLower: referenced.searchTextLower,
        namesById: damageTypeNamesById ?? const {},
        namePatternsById: damageTypeNamePatternsById,
      );
      if (!matchesAnyDamageType) return false;
    }
    if (selectedConditionIds.isNotEmpty) {
      final matchesAnyCondition = _matchesReferencedRecordSet(
        selectedIds: selectedConditionIds,
        kindApiValues: const {'conditions', 'condition'},
        links: referenced.links,
        searchTextLower: referenced.searchTextLower,
        namesById: conditionNamesById ?? const {},
        namePatternsById: conditionNamePatternsById,
      );
      if (!matchesAnyCondition) return false;
    }
    if (selectedCastingTypeCodes.isNotEmpty) {
      if (!selectedCastingTypeCodes.contains(spell.castingTypeCode)) {
        return false;
      }
    }
    switch (concentrationFilter) {
      case SpellsConcentrationFilter.any:
        break;
      case SpellsConcentrationFilter.withoutConcentration:
        if (spell.isConcentration) return false;
      case SpellsConcentrationFilter.withConcentration:
        if (!spell.isConcentration) return false;
    }
    return true;
  }
}

SpellReferenceScope buildSpellReferenceScope(Spell spell) {
  final text = [
    spell.description,
    spell.higherLevels?.description ?? '',
    spell.components.materialDescription ?? '',
    spell.castingTime.reactionTrigger ?? '',
  ].where((part) => part.trim().isNotEmpty).join('\n');
  return (
    links: parseWikiLinks(text),
    searchTextLower: text.toLowerCase(),
  );
}

bool _matchesReferencedRecordSet({
  required Set<String> selectedIds,
  required Set<String> kindApiValues,
  required List<WikiLink> links,
  required String searchTextLower,
  required Map<String, String> namesById,
  Map<String, RegExp>? namePatternsById,
}) {
  for (final link in links) {
    final kind = link.kind.toLowerCase();
    if (!kindApiValues.contains(kind)) continue;
    for (final id in selectedIds) {
      final name = namesById[id];
      if (name == null) continue;
      if (link.name.toLowerCase() == name.toLowerCase()) return true;
    }
  }
  for (final id in selectedIds) {
    final pattern =
        namePatternsById?[id] ?? _buildNameBoundaryPattern(namesById[id]);
    if (pattern == null) continue;
    if (pattern.hasMatch(searchTextLower)) return true;
  }
  return false;
}

Map<String, RegExp> buildReferencedNamePatterns({
  required Set<String> selectedIds,
  required Map<String, String> namesById,
}) {
  final patterns = <String, RegExp>{};
  for (final id in selectedIds) {
    final pattern = _buildNameBoundaryPattern(namesById[id]);
    if (pattern == null) continue;
    patterns[id] = pattern;
  }
  return patterns;
}

RegExp? _buildNameBoundaryPattern(String? rawName) {
  if (rawName == null) return null;
  final normalizedName = rawName.trim().toLowerCase();
  if (normalizedName.isEmpty) return null;
  return RegExp(
    '(?:^|[^a-z0-9])${RegExp.escape(normalizedName)}(?:\$|[^a-z0-9])',
    caseSensitive: false,
  );
}

String spellListFilterSignature(SpellsListFilter filter) {
  String setSig(Set<String> values) {
    if (values.isEmpty) return '';
    final sorted = values.toList(growable: false)..sort();
    return sorted.join('|');
  }

  return [
    setSig(filter.selectedSchoolCodes),
    setSig(filter.selectedLevelCodes),
    setSig(filter.selectedTagIds),
    setSig(filter.selectedClassIds),
    setSig(filter.selectedDamageTypeIds),
    setSig(filter.selectedConditionIds),
    setSig(filter.selectedCastingTypeCodes),
    filter.concentrationFilter.name,
  ].join('::');
}
