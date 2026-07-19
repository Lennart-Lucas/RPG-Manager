import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_manager/features/mechanics/features/data/feature_ep.dart';
import 'package:rpg_manager/features/mechanics/features/data/feature_model.dart';
import 'package:rpg_manager/features/mechanics/features/data/feature_text.dart';
import 'package:rpg_manager/features/world/creatures/data/scaler_math.dart';

void main() {
  group('availableEffectPoints', () {
    test('uncommon action base is 3', () {
      expect(
        availableEffectPoints(
          rarity: FeatureRarity.uncommon,
          activation: FeatureActivation.action,
          hasRequirement: false,
          deferral: const FeatureDeferral(),
        ),
        3,
      );
    });

    test('bonus action costs −1 EP', () {
      expect(
        availableEffectPoints(
          rarity: FeatureRarity.uncommon,
          activation: FeatureActivation.bonus,
          hasRequirement: false,
          deferral: const FeatureDeferral(),
        ),
        2,
      );
    });
  });

  group('Stink Pot EP spend', () {
    test('1 damage + 1 poisoned + save ends = 3', () {
      final damage = FeatureEffect(
        type: FeatureEffectType.damage,
        cost: 1,
        payload: {
          'damageEp': 1,
          'delivery': 'area',
          'damageTypes': ['poison'],
        },
      );
      final condition = const FeatureEffect(
        type: FeatureEffectType.condition,
        cost: 1,
        duration: FeatureEffectDuration.saveEnds,
        payload: {
          'condition': 'Poisoned',
          'conditionRarity': 'common',
        },
      );
      expect(computeEffectCost(damage), 1);
      expect(computeEffectCost(condition), 2); // 1 + save ends
      // Rebalance example: 1 EP damage area + 1 EP common condition + 1 EP save ends
      // = damage 1 + condition(1+1) = 3
      expect(computeEffectCost(damage) + computeEffectCost(condition), 3);

      final feature = MonsterFeature(
        name: 'Stink Pot',
        category: FeatureCategory.attack,
        rarity: FeatureRarity.uncommon,
        activationTime: FeatureActivation.action,
        defence: FeatureDefence.con,
        range: const FeatureRange(
          category: FeatureRangeCategory.area,
          template: 'circle',
          distance: '15 ft. radius within 60 ft.',
        ),
        targets: const FeatureTargets(
          quantity: FeatureTargetQuantity.all,
          category: FeatureTargetCategory.creature,
        ),
        limitation: const FeatureLimitation(
          type: FeatureLimitationType.charges,
          value: '1',
          recoveryTrigger: 'collect new ammunition',
        ),
        effects: [damage, condition],
        effectPoints: 3,
      );
      final v = validateFeatureEp(feature);
      expect(v.available, 3);
      expect(v.spent, 3);
      expect(v.ok, isTrue);
    });
  });

  group('limitation defaults', () {
    test('grunt uncommon charges = 1', () {
      final lim = defaultLimitationForRank(
        rarity: FeatureRarity.uncommon,
        rank: ScalerRank.grunt,
        threat: 1,
      );
      expect(lim.type, FeatureLimitationType.charges);
      expect(lim.value, '1');
    });
  });

  group('generateFeatureText', () {
    test('includes save and damage percent', () {
      final feature = MonsterFeature(
        name: 'Stink Pot',
        category: FeatureCategory.attack,
        rarity: FeatureRarity.uncommon,
        defence: FeatureDefence.con,
        range: const FeatureRange(
          category: FeatureRangeCategory.area,
          template: 'circle',
          distance: '15 ft.',
        ),
        effects: [
          FeatureEffect(
            type: FeatureEffectType.damage,
            cost: 1,
            payload: {
              'damageEp': 1,
              'delivery': 'area',
              'damageTypes': ['poison'],
            },
          ),
        ],
      );
      final text = generateFeatureText(feature);
      expect(text.toLowerCase(), contains('con'));
      expect(text, contains('75%'));
    });
  });
}
