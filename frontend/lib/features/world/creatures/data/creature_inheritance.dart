import 'package:rpg_manager/features/mechanics/features/data/feature_model.dart';
import 'package:rpg_manager/features/world/creature_types/data/creature_type_model.dart';
import 'package:rpg_manager/features/world/creatures/data/creature_model.dart';
import 'package:rpg_manager/features/world/data/labeled_amount.dart';

String _normalize(String value) => value.trim().toLowerCase();

List<int> _mergeIntIds(List<int> existing, List<int> incoming) {
  final seen = existing.toSet();
  final merged = [...existing];
  for (final id in incoming) {
    if (seen.add(id)) merged.add(id);
  }
  return merged;
}

List<String> _mergeStrings(List<String> existing, List<String> incoming) {
  final seen = {for (final value in existing) _normalize(value)};
  final merged = [...existing];
  for (final value in incoming) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) continue;
    final key = _normalize(trimmed);
    if (!seen.add(key)) continue;
    merged.add(trimmed);
  }
  return merged;
}

List<LabeledAmount> _mergeLabeledAmounts(
  List<LabeledAmount> existing,
  List<LabeledAmount> incoming,
) {
  final seen = {
    for (final value in existing)
      '${_normalize(value.label)}|${value.amount}',
  };
  final merged = [...existing];
  for (final value in incoming) {
    final key = '${_normalize(value.label)}|${value.amount}';
    if (!seen.add(key)) continue;
    merged.add(value);
  }
  return merged;
}


List<CreatureFeatureEntry> _traitsToFeatureEntries(
  List<CreatureTypeTrait> traits,
) {
  return [
    for (final trait in traits)
      if (trait.featureCatalogItemId != null)
        CreatureFeatureEntry.catalog(
          catalogItemId: trait.featureCatalogItemId!,
          snapshotName: trait.name,
          snapshotText: trait.description,
        )
      else if (trait.name.trim().isNotEmpty || trait.description.trim().isNotEmpty)
        CreatureFeatureEntry.local(
          MonsterFeature(
            name: trait.name.trim().isEmpty ? 'Trait' : trait.name.trim(),
            category: FeatureCategory.trait,
            rarity: FeatureRarity.common,
            text: trait.description,
            budgetSlot: FeatureBudgetSlot.ancestral,
          ),
        ),
  ];
}

List<CreatureFeatureEntry> _mergeInheritedFeatures({
  required List<CreatureFeatureEntry> existing,
  required List<CreatureFeatureEntry> incoming,
}) {
  final seen = <String>{};
  for (final entry in existing) {
    if (entry.isAuto) continue;
    seen.add(
      '${_normalize(entry.displayName)}|${_normalize(entry.displayText)}|'
      '${entry.catalogItemId ?? ''}',
    );
  }
  final merged = [...existing];
  for (final entry in incoming) {
    final key =
        '${_normalize(entry.displayName)}|${_normalize(entry.displayText)}|'
        '${entry.catalogItemId ?? ''}';
    if (!seen.add(key)) continue;
    merged.add(entry);
  }
  return merged;
}

/// Merges creature type defaults into [creature] without removing user extras.
Creature mergeCreatureTypeInheritance({
  required Creature creature,
  required Map<int, CreatureType> typesById,
  int? creatureTypeId,
  int? creatureSubtypeId,
}) {
  final typeId = creatureSubtypeId ?? creatureTypeId;
  if (typeId == null) return creature;

  final primary = typesById[typeId];
  if (primary == null) return creature;

  final chain = creatureTypeAncestry(type: primary, byId: typesById);
  final mergedMovement = <LabeledAmount>[];
  final mergedSenses = <LabeledAmount>[];
  var languageIds = creature.languageIds;
  var customLanguages = creature.customLanguages;
  var skillIds = creature.skillIds;
  var customSkills = creature.customSkills;
  var vulnerabilityIds = creature.damageVulnerabilityIds;
  var customVulnerabilities = creature.customDamageVulnerabilities;
  var resistanceIds = creature.damageResistanceIds;
  var customResistances = creature.customDamageResistances;
  var immunityIds = creature.damageImmunityIds;
  var customImmunities = creature.customDamageImmunities;
  var conditionImmunityIds = creature.conditionImmunityIds;
  final inheritedTraits = <CreatureFeatureEntry>[];

  for (final type in chain) {
    mergedMovement.addAll(type.movement);
    mergedSenses.addAll(type.senses);
    languageIds = _mergeIntIds(languageIds, type.languageIds);
    customLanguages = _mergeStrings(customLanguages, type.customLanguages);
    skillIds = _mergeIntIds(skillIds, type.skillIds);
    vulnerabilityIds = _mergeIntIds(vulnerabilityIds, type.damageVulnerabilityIds);
    customVulnerabilities =
        _mergeStrings(customVulnerabilities, type.customDamageVulnerabilities);
    resistanceIds = _mergeIntIds(resistanceIds, type.damageResistanceIds);
    customResistances =
        _mergeStrings(customResistances, type.customDamageResistances);
    immunityIds = _mergeIntIds(immunityIds, type.damageImmunityIds);
    customImmunities =
        _mergeStrings(customImmunities, type.customDamageImmunities);
    conditionImmunityIds =
        _mergeIntIds(conditionImmunityIds, type.conditionImmunityIds);
    inheritedTraits.addAll(_traitsToFeatureEntries(type.traits));
  }

  final typeName = typesById[creatureTypeId]?.name ?? '';
  final subtypeName = creatureSubtypeId != null
      ? typesById[creatureSubtypeId]?.name ?? ''
      : '';
  final displayType = subtypeName.isNotEmpty
      ? (typeName.isNotEmpty ? '$typeName ($subtypeName)' : subtypeName)
      : typeName;

  var next = creature.copyWith(
    creatureTypeId: creatureTypeId,
    creatureSubtypeId: creatureSubtypeId,
    creatureType: displayType.isNotEmpty ? displayType : creature.creatureType,
    size: primary.size ?? creature.size,
    sensesLabeled: _mergeLabeledAmounts(creature.sensesLabeled, mergedSenses),
    languageIds: languageIds,
    customLanguages: customLanguages,
    skillIds: skillIds,
    customSkills: customSkills,
    damageVulnerabilityIds: vulnerabilityIds,
    customDamageVulnerabilities: customVulnerabilities,
    damageResistanceIds: resistanceIds,
    customDamageResistances: customResistances,
    damageImmunityIds: immunityIds,
    customDamageImmunities: customImmunities,
    conditionImmunityIds: conditionImmunityIds,
    speeds: syncSpeedsFromMovement(
      speeds: creature.speeds,
      movement: mergedMovement,
    ),
    features: _mergeInheritedFeatures(
      existing: creature.features,
      incoming: inheritedTraits,
    ),
  );

  next = next.copyWith(
    senses: next.resolvedSenses(),
  );
  return next;
}
