import 'package:rpg_manager/features/world/creatures/data/creature_model.dart';

class CreatureCombatSnapshot {
  const CreatureCombatSnapshot({
    required this.proficiencyBonus,
    required this.armorClass,
    required this.hitPoints,
    required this.initiativeBonus,
    required this.attackBonus,
    required this.attackDc,
    required this.attackDamage,
    required this.trainedSavingThrows,
    required this.abilityLow,
    required this.abilityMid,
    required this.abilityHigh,
    required this.threatValue,
    required this.speedModifier,
    required this.grantedSkill,
    required this.attributeModifiers,
    required this.trainedAttributes,
    required this.specialFeatures,
    required this.otherFeaturesGuidance,
  });

  final int proficiencyBonus;
  final int armorClass;
  final int hitPoints;
  final int initiativeBonus;
  final int attackBonus;
  final int attackDc;
  final int attackDamage;
  final int trainedSavingThrows;
  final int abilityLow;
  final int abilityMid;
  final int abilityHigh;
  final num threatValue;
  final int speedModifier;
  final String? grantedSkill;
  final Map<String, int> attributeModifiers;
  final Set<String> trainedAttributes;
  final List<String> specialFeatures;
  final String otherFeaturesGuidance;
}

CreatureCombatSnapshot computeCreatureCombatSnapshot(Creature creature) {
  final formula = creature.formula;
  final scores = creature.abilityScores;
  final attributeModifiers = {
    for (final key in AbilityKey.values) key.label: scores[key],
  };
  final trainedAttributes = {
    for (final save in creature.trainedSavingThrows)
      save.trim().toUpperCase(),
  };

  return CreatureCombatSnapshot(
    proficiencyBonus: creature.proficiencyBonus,
    armorClass: creature.ac,
    hitPoints: creature.hp,
    initiativeBonus: creature.initiativeBonus,
    attackBonus: creature.atk,
    attackDc: creature.dc,
    attackDamage: creature.dmg,
    trainedSavingThrows: formula.trainedSaveCount,
    abilityLow: formula.abilityLow,
    abilityMid: formula.abilityMid,
    abilityHigh: formula.abilityHigh,
    threatValue: creature.threat,
    speedModifier: formula.speedWalkDelta,
    grantedSkill: formula.grantedSkill,
    attributeModifiers: attributeModifiers,
    trainedAttributes: trainedAttributes,
    specialFeatures: [
      for (final entry in creature.features) entry.displayName,
    ],
    otherFeaturesGuidance:
        'Recommended ${formula.featureBudgetMin}–${formula.featureBudgetMax} custom features',
  );
}
