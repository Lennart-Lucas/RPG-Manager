import '../../../world/creatures/data/scaler_math.dart' show ScalerRank;
import 'feature_model.dart';

int baseEpForRarity(FeatureRarity rarity) => rarity.baseEffectPoints;

/// Available EP after modifiers (before spending on effects).
int availableEffectPoints({
  required FeatureRarity rarity,
  required FeatureActivation activation,
  required bool hasRequirement,
  required FeatureDeferral deferral,
}) {
  var ep = baseEpForRarity(rarity);
  if (hasRequirement) ep += 1;
  if (deferral.isActive) ep += 1;
  if (activation == FeatureActivation.free ||
      activation == FeatureActivation.bonus) {
    ep -= 1;
  }
  if (activation == FeatureActivation.reaction) ep -= 1;
  return ep;
}

int durationEpCost(FeatureEffectDuration duration) => switch (duration) {
      FeatureEffectDuration.concentration ||
      FeatureEffectDuration.ongoing ||
      FeatureEffectDuration.saveEnds =>
        1,
      _ => 0,
    };

({int hitPercent, int missPercent}) damagePercents({
  required int ep,
  required DamageDeliveryMode mode,
}) {
  final e = ep.clamp(1, 5);
  return switch (mode) {
    DamageDeliveryMode.aimedSingle || DamageDeliveryMode.aimedMulti => (
        hitPercent: 75 + e * 25,
        missPercent: 0,
      ),
    DamageDeliveryMode.area => (
        hitPercent: 50 + e * 25,
        missPercent: 25 + e * 25,
      ),
  };
}

int movementFeet({
  required int ep,
  required DamageDeliveryMode mode,
  required bool onHit,
}) {
  final e = ep.clamp(1, 5);
  return switch (mode) {
    DamageDeliveryMode.aimedSingle || DamageDeliveryMode.aimedMulti => e * 10,
    DamageDeliveryMode.area => onHit
        ? (e == 1
            ? 5
            : e == 2
                ? 10
                : e == 3
                    ? 20
                    : e == 4
                        ? 30
                        : 40)
        : (e <= 2
            ? 0
            : e == 3
                ? 10
                : e == 4
                    ? 20
                    : 30),
  };
}

int conditionRarityCost(FeatureRarity rarity) => switch (rarity) {
      FeatureRarity.common => 1,
      FeatureRarity.uncommon => 2,
      FeatureRarity.rare => 4,
    };

int terrainRarityCost(FeatureRarity rarity) => conditionRarityCost(rarity);
int resourceRarityCost(FeatureRarity rarity) => conditionRarityCost(rarity);
int empowerRarityCost(FeatureRarity rarity) => conditionRarityCost(rarity);

int computeEffectCost(FeatureEffect effect) {
  final durationExtra = durationEpCost(effect.duration);
  final p = effect.payload;
  switch (effect.type) {
    case FeatureEffectType.damage:
      final ep = (p['damageEp'] as num?)?.toInt() ?? 1;
      return ep.clamp(1, 5) + durationExtra;
    case FeatureEffectType.condition:
      final rarity = FeatureRarityApi.fromJson(p['conditionRarity'] as String?);
      var cost = conditionRarityCost(rarity);
      final extra = (p['extraConditions'] as num?)?.toInt() ?? 0;
      cost += extra;
      if (p['multiTarget'] == true) cost += 1;
      if (p['extraSave'] == true) cost -= 1;
      return (cost + durationExtra).clamp(0, 20);
    case FeatureEffectType.terrain:
      final rarity = FeatureRarityApi.fromJson(p['terrainRarity'] as String?);
      var cost = terrainRarityCost(rarity);
      cost += (p['extraModifiers'] as num?)?.toInt() ?? 0;
      return cost + durationExtra;
    case FeatureEffectType.resource:
      final rarity = FeatureRarityApi.fromJson(p['resourceRarity'] as String?);
      var cost = resourceRarityCost(rarity);
      cost += (p['extraResources'] as num?)?.toInt() ?? 0;
      if (p['multiTarget'] == true) cost += 1;
      if (p['extraSave'] == true) cost -= 1;
      return (cost + durationExtra).clamp(0, 20);
    case FeatureEffectType.movement:
      final ep = (p['movementEp'] as num?)?.toInt() ?? 1;
      return ep.clamp(1, 5) + durationExtra;
    case FeatureEffectType.empower:
      final rarity = FeatureRarityApi.fromJson(p['boonRarity'] as String?);
      var cost = empowerRarityCost(rarity);
      cost += (p['extraBoons'] as num?)?.toInt() ?? 0;
      if (p['multiTarget'] == true) cost += 1;
      return cost + durationExtra;
  }
}

int totalEffectsCost(Iterable<FeatureEffect> effects) =>
    effects.fold(0, (sum, e) => sum + computeEffectCost(e));

class FeatureEpValidation {
  const FeatureEpValidation({
    required this.available,
    required this.spent,
    required this.ok,
    this.message,
  });

  final int available;
  final int spent;
  final bool ok;
  final String? message;
}

FeatureEpValidation validateFeatureEp(MonsterFeature feature) {
  final available = availableEffectPoints(
    rarity: feature.rarity,
    activation: feature.activationTime,
    hasRequirement: feature.hasRequirement,
    deferral: feature.deferral,
  );
  if (feature.category != FeatureCategory.trait) {
    if (feature.effects.isEmpty) {
      return FeatureEpValidation(
        available: available,
        spent: 0,
        ok: false,
        message: 'Add 1–3 effects',
      );
    }
    if (feature.effects.length > 3) {
      return FeatureEpValidation(
        available: available,
        spent: totalEffectsCost(feature.effects),
        ok: false,
        message: 'At most 3 effects',
      );
    }
  }
  final spent = totalEffectsCost(feature.effects);
  if (spent > available) {
    return FeatureEpValidation(
      available: available,
      spent: spent,
      ok: false,
      message: 'Spent $spent EP but only $available available',
    );
  }
  return FeatureEpValidation(available: available, spent: spent, ok: true);
}

FeatureLimitation defaultLimitationForRank({
  required FeatureRarity rarity,
  required ScalerRank rank,
  required num threat,
  FeatureLimitationType? prefer,
}) {
  if (rarity == FeatureRarity.common) {
    return const FeatureLimitation();
  }
  if (rarity == FeatureRarity.rare) {
    return const FeatureLimitation(
      type: FeatureLimitationType.recoveryEvent,
      value: 'long rest',
      recoveryTrigger: 'long rest',
    );
  }
  final type = prefer ?? FeatureLimitationType.charges;
  switch (type) {
    case FeatureLimitationType.charges:
      final charges = switch (rank) {
        ScalerRank.minion || ScalerRank.grunt => 1,
        ScalerRank.elite => 2,
        ScalerRank.paragon => threat.round().clamp(1, 12),
      };
      return FeatureLimitation(
        type: FeatureLimitationType.charges,
        value: '$charges',
        recoveryTrigger: 'short rest',
      );
    case FeatureLimitationType.recharge:
      final range = switch (rank) {
        ScalerRank.minion => '6',
        ScalerRank.grunt => '5-6',
        ScalerRank.elite || ScalerRank.paragon => '4-6',
      };
      return FeatureLimitation(
        type: FeatureLimitationType.recharge,
        value: range,
      );
    case FeatureLimitationType.cooldown:
      final turns = switch (rank) {
        ScalerRank.minion => 4,
        ScalerRank.grunt => 3,
        ScalerRank.elite || ScalerRank.paragon => 2,
      };
      return FeatureLimitation(
        type: FeatureLimitationType.cooldown,
        value: '$turns',
      );
    default:
      return const FeatureLimitation();
  }
}

int limitedTargetMaxForLevel(int level) {
  if (level >= 17) return 4;
  if (level >= 11) return 3;
  if (level >= 5) return 2;
  return 2;
}

String distanceTierForRarity(FeatureRarity rarity, List<String> options) {
  if (options.isEmpty) return '';
  return switch (rarity) {
    FeatureRarity.common => options.first,
    FeatureRarity.uncommon =>
      options.length > 1 ? options[1] : options.first,
    FeatureRarity.rare => options.last,
  };
}
