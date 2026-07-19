import 'package:rpg_manager/features/world/creatures/data/creature_model.dart';
import 'package:rpg_manager/features/world/creatures/data/scaler_math.dart';

const abilityAssignmentSlots = [
  'high_1',
  'high_2',
  'medium_1',
  'medium_2',
  'low_1',
  'low_2',
];

const defaultAbilityAssignments = {
  AbilityKey.str: 'high_1',
  AbilityKey.dex: 'high_2',
  AbilityKey.con: 'medium_1',
  AbilityKey.int_: 'medium_2',
  AbilityKey.wis: 'low_1',
  AbilityKey.cha: 'low_2',
};

Map<AbilityKey, String> abilityAssignmentsFromScores({
  required CreatureAbilityScores scores,
  required ScalerComputedStats formula,
}) {
  final used = <String>{};
  final assignments = <AbilityKey, String>{};

  String pickSlot(int score) {
    if (score == -5) return 'low_2';
    if (score == formula.abilityHigh) {
      if (!used.contains('high_1')) return 'high_1';
      return 'high_2';
    }
    if (score == formula.abilityMid) {
      if (!used.contains('medium_1')) return 'medium_1';
      return 'medium_2';
    }
    if (score == formula.abilityLow) {
      if (!used.contains('low_1')) return 'low_1';
      return 'low_2';
    }
    for (final slot in abilityAssignmentSlots) {
      if (!used.contains(slot)) return slot;
    }
    return 'medium_1';
  }

  for (final key in AbilityKey.values) {
    final slot = pickSlot(scores[key]);
    assignments[key] = slot;
    used.add(slot);
  }
  return assignments;
}

Map<String, int> slotModifiersForFormula(ScalerComputedStats formula) {
  return {
    'low_1': formula.abilityLow,
    'low_2': formula.abilityLow,
    'medium_1': formula.abilityMid,
    'medium_2': formula.abilityMid,
    'high_1': formula.abilityHigh,
    'high_2': formula.abilityHigh,
  };
}

CreatureAbilityScores abilityScoresFromAssignments({
  required Map<AbilityKey, String> assignments,
  required Map<String, int> slotModifiers,
}) {
  var scores = const CreatureAbilityScores();
  for (final key in AbilityKey.values) {
    final slot = assignments[key] ?? defaultAbilityAssignments[key]!;
    scores = scores.withAbility(key, slotModifiers[slot] ?? 0);
  }
  return scores;
}

Set<AbilityKey> trainedAbilityKeysFromSaves(List<String> saves) {
  return {
    for (final save in saves)
      if (AbilityKeyApi.fromJson(save.toLowerCase()) case final key?) key,
  };
}

List<String> trainedSavesFromAbilityKeys(Set<AbilityKey> keys) {
  return [for (final key in keys) key.jsonKey];
}

void swapAbilityAssignments(
  Map<AbilityKey, String> assignments,
  AbilityKey first,
  AbilityKey second,
) {
  final temp = assignments[first];
  assignments[first] = assignments[second]!;
  assignments[second] = temp!;
}
