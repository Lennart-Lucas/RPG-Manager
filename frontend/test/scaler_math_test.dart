import 'package:flutter_test/flutter_test.dart';

import 'package:rpg_manager/features/world/creatures/data/scaler_math.dart';

void main() {
  group('roundHalfUp', () {
    test('rounds .5 up', () {
      expect(roundHalfUp(23.1), 23);
      expect(roundHalfUp(17.25), 17);
      expect(roundHalfUp(1.5), 2);
      expect(roundHalfUp(4.5), 5);
    });
  });

  group('base formulas', () {
    test('PB and ability tiers at level 7', () {
      expect(proficiencyBonus(7), 3);
      expect(abilityModLow(7), -1);
      expect(abilityModMid(7), 1);
      expect(abilityModHigh(7), 4);
      expect(baseArmorClass(7), 13);
      expect(baseHitPoints(7), 65);
      expect(baseDamage(7), 21);
    });
  });

  group('§10 Level 7 Elite Controller', () {
    late ScalerComputedStats stats;

    setUp(() {
      stats = computeScalerStats(
        level: 7,
        rank: ScalerRank.elite,
        role: ScalerRole.controller,
      );
    });

    test('core combat numbers', () {
      expect(stats.proficiencyBonus, 3);
      expect(stats.ac, 16);
      expect(stats.hp, 130);
      expect(stats.dmg, 17);
      expect(stats.atk, 3);
      expect(stats.dc, 11);
      expect(stats.initiativeBonus, 5);
      expect(stats.trainedSaveCount, 3);
      expect(stats.threat, 2);
      expect(stats.cr, '4');
    });

    test('ability tiers after elite +1', () {
      expect(stats.abilityLow, 0);
      expect(stats.abilityMid, 2);
      expect(stats.abilityHigh, 5);
    });

    test('XP is CR XP × elite multiplier', () {
      expect(xpForChallengeRating('4'), 1100);
      expect(stats.xp, 2200);
    });
  });

  group('rounding stages', () {
    test('elite damage then controller', () {
      // Base 21 → ×1.1 = 23.1 → 23 → ×0.75 = 17.25 → 17
      final stats = computeScalerStats(
        level: 7,
        rank: ScalerRank.elite,
        role: ScalerRole.controller,
      );
      expect(stats.dmg, 17);
    });
  });
}
