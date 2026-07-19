/// Giffyglyph Monster Maker scaler formulas (Part 1).
library;

enum ScalerRank { minion, grunt, elite, paragon }

enum ScalerRole {
  controller,
  defender,
  lurker,
  skirmisher,
  striker,
  supporter,
}

/// Round half away from zero toward +∞ for non-negative combat stats
/// (0.5 → 1). Matches “nearest whole number; 0.5 rounds up”.
int roundHalfUp(num value) {
  if (value >= 0) {
    return (value + 0.5).floor();
  }
  return (value - 0.5).ceil();
}

int proficiencyBonus(int level) => 1 + ((level + 3) ~/ 4);

int abilityModLow(int level) => (level ~/ 12) - 1;

int abilityModMid(int level) => 1 + (level ~/ 8);

int abilityModHigh(int level) {
  if (level < 8) return 3 + (level ~/ 4);
  return 5 + ((level - 8) ~/ 8);
}

int baseArmorClass(int level) => 12 + (level ~/ 4);

int baseHitPoints(int level) => 16 + (level * 7);

int baseDamage(int level) => level * 3;

class ScalerComputedStats {
  const ScalerComputedStats({
    required this.level,
    required this.rank,
    required this.threat,
    required this.role,
    required this.proficiencyBonus,
    required this.abilityLow,
    required this.abilityMid,
    required this.abilityHigh,
    required this.ac,
    required this.hp,
    required this.bloodied,
    required this.enraged,
    required this.atk,
    required this.dc,
    required this.dmg,
    required this.initiativeBonus,
    required this.trainedSaveCount,
    required this.speedWalkDelta,
    required this.grantedSkill,
    required this.cr,
    required this.xp,
    required this.featureBudgetMin,
    required this.featureBudgetMax,
  });

  final int level;
  final ScalerRank rank;
  final num threat;
  final ScalerRole? role;
  final int proficiencyBonus;
  final int abilityLow;
  final int abilityMid;
  final int abilityHigh;
  final int ac;
  final int hp;
  final int bloodied;
  final int enraged;
  final int atk;
  final int dc;
  final int dmg;
  final int initiativeBonus;
  final int trainedSaveCount;
  /// Feet delta applied to walking speed from role (−5 / +5 / 0).
  final int speedWalkDelta;
  final String? grantedSkill;
  final String cr;
  final int xp;
  final int featureBudgetMin;
  final int featureBudgetMax;
}

({int min, int max}) featureBudget(ScalerRank rank) => switch (rank) {
      ScalerRank.minion => (min: 1, max: 5),
      ScalerRank.grunt => (min: 3, max: 8),
      ScalerRank.elite => (min: 5, max: 11),
      ScalerRank.paragon => (min: 7, max: 14),
    };

num effectiveThreat(ScalerRank rank, {num? paragonThreat}) => switch (rank) {
      ScalerRank.minion => 0.25,
      ScalerRank.grunt => 1,
      ScalerRank.elite => 2,
      ScalerRank.paragon => paragonThreat ?? 4,
    };

ScalerComputedStats computeScalerStats({
  required int level,
  required ScalerRank rank,
  ScalerRole? role,
  num? paragonThreat,
}) {
  final lvl = level.clamp(0, 30);
  final pb = proficiencyBonus(lvl);
  final threat = effectiveThreat(rank, paragonThreat: paragonThreat);

  // --- Base (grunt) ---
  var abilityLow = abilityModLow(lvl);
  var abilityMid = abilityModMid(lvl);
  var abilityHigh = abilityModHigh(lvl);
  var ac = baseArmorClass(lvl);
  num hp = baseHitPoints(lvl);
  final atk = pb;
  final dc = 8 + pb;
  num dmg = baseDamage(lvl);
  num initiative = 0;
  var tst = 2;

  // --- Rank ---
  switch (rank) {
    case ScalerRank.minion:
      hp = roundHalfUp(hp * 0.2);
      dmg = roundHalfUp(dmg * 0.75);
      tst = 1;
    case ScalerRank.grunt:
      hp = roundHalfUp(hp);
      dmg = roundHalfUp(dmg);
    case ScalerRank.elite:
      abilityLow += 1;
      abilityMid += 1;
      abilityHigh += 1;
      initiative = roundHalfUp(initiative + pb / 2);
      ac += 1;
      hp = roundHalfUp(hp * 2);
      dmg = roundHalfUp(dmg * 1.1);
      tst = 3;
    case ScalerRank.paragon:
      abilityLow += 2;
      abilityMid += 2;
      abilityHigh += 2;
      initiative = roundHalfUp(initiative + pb);
      ac += 2;
      hp = roundHalfUp(hp * threat);
      dmg = roundHalfUp(dmg * 1.2);
      tst = 3;
  }

  // --- Role ---
  var speedDelta = 0;
  String? grantedSkill;
  if (role != null) {
    switch (role) {
      case ScalerRole.controller:
        initiative = roundHalfUp(initiative + pb);
        ac += 2;
        dmg = roundHalfUp(dmg * 0.75);
      case ScalerRole.defender:
        speedDelta = -5;
        ac += 4;
        hp = roundHalfUp(hp * 0.75);
        tst += 1;
        dmg = roundHalfUp(dmg * 0.75);
      case ScalerRole.lurker:
        ac -= 4;
        hp = roundHalfUp(hp * 0.75);
        tst -= 1;
        dmg = roundHalfUp(dmg * 1.25);
        grantedSkill = 'Stealth';
      case ScalerRole.skirmisher:
        speedDelta = 5;
        ac -= 2;
        hp = roundHalfUp(hp * 0.75);
        grantedSkill = 'Perception';
      case ScalerRole.striker:
        break;
      case ScalerRole.supporter:
        initiative = roundHalfUp(initiative + pb);
        hp = roundHalfUp(hp * 1.25);
        dmg = roundHalfUp(dmg * 0.75);
    }
  }

  final hpInt = roundHalfUp(hp);
  final dmgInt = roundHalfUp(dmg);
  final initInt = roundHalfUp(initiative);

  final cr = challengeRatingLabel(lvl, rank);
  final baseXp = xpForChallengeRating(cr);
  final xp = roundHalfUp(baseXp * _xpMultiplier(rank, threat));

  final budget = featureBudget(rank);

  return ScalerComputedStats(
    level: lvl,
    rank: rank,
    threat: threat,
    role: role,
    proficiencyBonus: pb,
    abilityLow: abilityLow,
    abilityMid: abilityMid,
    abilityHigh: abilityHigh,
    ac: ac,
    hp: hpInt,
    bloodied: hpInt ~/ 2,
    enraged: hpInt ~/ 4,
    atk: atk,
    dc: dc,
    dmg: dmgInt,
    initiativeBonus: initInt,
    trainedSaveCount: tst.clamp(0, 6),
    speedWalkDelta: speedDelta,
    grantedSkill: grantedSkill,
    cr: cr,
    xp: xp,
    featureBudgetMin: budget.min,
    featureBudgetMax: budget.max,
  );
}

num _xpMultiplier(ScalerRank rank, num threat) => switch (rank) {
      ScalerRank.minion => 0.25,
      ScalerRank.grunt => 1,
      ScalerRank.elite => 2,
      ScalerRank.paragon => threat,
    };

/// CR strings for levels 0–30 (Paragon column is T4 baseline from the source).
String challengeRatingLabel(int level, ScalerRank rank) {
  final lvl = level.clamp(0, 30);
  final row = _crTable[lvl];
  return switch (rank) {
    ScalerRank.minion => row.$1,
    ScalerRank.grunt => row.$2,
    ScalerRank.elite => row.$3,
    ScalerRank.paragon => row.$4,
  };
}

// (minion, grunt, elite, paragonT4)
const List<(String, String, String, String)> _crTable = [
  ('0', '1/8', '1/4', '1/2'), // 0
  ('0', '1/4', '1/2', '1'), // 1
  ('1/8', '1/2', '1', '2'), // 2
  ('1/8', '1/2', '1', '3'), // 3
  ('1/4', '1', '2', '4'), // 4
  ('1/2', '2', '3', '5'), // 5
  ('1/2', '2', '4', '6'), // 6
  ('1/2', '3', '4', '7'), // 7
  ('1', '3', '5', '8'), // 8
  ('1', '4', '6', '9'), // 9
  ('1', '4', '7', '10'), // 10
  ('2', '5', '8', '11'), // 11
  ('2', '5', '8', '12'), // 12
  ('2', '6', '9', '13'), // 13
  ('2', '6', '10', '14'), // 14
  ('3', '7', '11', '15'), // 15
  ('3', '7', '11', '16'), // 16
  ('3', '8', '12', '17'), // 17
  ('3', '8', '13', '18'), // 18
  ('4', '9', '13', '19'), // 19
  ('4', '10', '14', '20'), // 20
  ('5', '11', '15', '21'), // 21
  ('5', '12', '16', '22'), // 22
  ('6', '13', '17', '23'), // 23
  ('7', '15', '19', '24'), // 24
  ('8', '17', '21', '25'), // 25
  ('9', '18', '22', '26'), // 26
  ('10', '19', '23', '27'), // 27
  ('10', '19', '23', '28'), // 28
  ('11', '20', '24', '29'), // 29
  ('12', '21', '25', '30'), // 30
];

/// Standard D&D 5e CR → XP.
int xpForChallengeRating(String cr) {
  const table = <String, int>{
    '0': 10,
    '1/8': 25,
    '1/4': 50,
    '1/2': 100,
    '1': 200,
    '2': 450,
    '3': 700,
    '4': 1100,
    '5': 1800,
    '6': 2300,
    '7': 2900,
    '8': 3900,
    '9': 5000,
    '10': 5900,
    '11': 7200,
    '12': 8400,
    '13': 10000,
    '14': 11500,
    '15': 13000,
    '16': 15000,
    '17': 18000,
    '18': 20000,
    '19': 22000,
    '20': 25000,
    '21': 33000,
    '22': 41000,
    '23': 50000,
    '24': 62000,
    '25': 75000,
    '26': 90000,
    '27': 105000,
    '28': 120000,
    '29': 135000,
    '30': 155000,
  };
  return table[cr] ?? 0;
}

extension ScalerRankLabel on ScalerRank {
  String get label => switch (this) {
        ScalerRank.minion => 'Minion',
        ScalerRank.grunt => 'Grunt',
        ScalerRank.elite => 'Elite',
        ScalerRank.paragon => 'Paragon',
      };

  String toJson() => name;

  static ScalerRank fromJson(String value) => ScalerRank.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ScalerRank.grunt,
      );
}

extension ScalerRoleLabel on ScalerRole {
  String get label => switch (this) {
        ScalerRole.controller => 'Controller',
        ScalerRole.defender => 'Defender',
        ScalerRole.lurker => 'Lurker',
        ScalerRole.skirmisher => 'Skirmisher',
        ScalerRole.striker => 'Striker',
        ScalerRole.supporter => 'Supporter',
      };

  List<String> get subtypes => switch (this) {
        ScalerRole.controller => const ['Hexer', 'Shaper', 'Tactician'],
        ScalerRole.defender => const ['Bulwark', 'Guardian', 'Sentinel'],
        ScalerRole.lurker => const ['Assassin', 'Exploiter', 'Sneak'],
        ScalerRole.skirmisher => const ['Spotter', 'Evader', 'Traveller'],
        ScalerRole.striker => const ['Butcher', 'Deadeye', 'Havoc'],
        ScalerRole.supporter => const ['Booster', 'Leader', 'Mender'],
      };

  String toJson() => name;

  static ScalerRole? fromJson(String? value) {
    if (value == null || value.isEmpty || value == 'none') return null;
    for (final role in ScalerRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }
}
