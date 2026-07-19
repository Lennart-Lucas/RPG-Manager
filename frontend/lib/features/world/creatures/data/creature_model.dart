import 'package:rpg_manager/features/mechanics/features/data/feature_model.dart';

import 'scaler_math.dart';

enum AbilityKey { str, dex, con, int_, wis, cha }

extension AbilityKeyApi on AbilityKey {
  String get jsonKey => switch (this) {
        AbilityKey.str => 'str',
        AbilityKey.dex => 'dex',
        AbilityKey.con => 'con',
        AbilityKey.int_ => 'int',
        AbilityKey.wis => 'wis',
        AbilityKey.cha => 'cha',
      };

  String get label => switch (this) {
        AbilityKey.str => 'STR',
        AbilityKey.dex => 'DEX',
        AbilityKey.con => 'CON',
        AbilityKey.int_ => 'INT',
        AbilityKey.wis => 'WIS',
        AbilityKey.cha => 'CHA',
      };

  static AbilityKey? fromJson(String value) {
    return switch (value) {
      'str' => AbilityKey.str,
      'dex' => AbilityKey.dex,
      'con' => AbilityKey.con,
      'int' => AbilityKey.int_,
      'wis' => AbilityKey.wis,
      'cha' => AbilityKey.cha,
      _ => null,
    };
  }
}

class CreatureSpeeds {
  const CreatureSpeeds({
    this.walk = 30,
    this.fly,
    this.swim,
    this.climb,
    this.burrow,
  });

  final int walk;
  final int? fly;
  final int? swim;
  final int? climb;
  final int? burrow;

  factory CreatureSpeeds.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CreatureSpeeds();
    return CreatureSpeeds(
      walk: (json['walk'] as num?)?.toInt() ?? 30,
      fly: (json['fly'] as num?)?.toInt(),
      swim: (json['swim'] as num?)?.toInt(),
      climb: (json['climb'] as num?)?.toInt(),
      burrow: (json['burrow'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'walk': walk,
        if (fly != null) 'fly': fly,
        if (swim != null) 'swim': swim,
        if (climb != null) 'climb': climb,
        if (burrow != null) 'burrow': burrow,
      };

  CreatureSpeeds copyWith({
    int? walk,
    int? fly,
    int? swim,
    int? climb,
    int? burrow,
    bool clearFly = false,
    bool clearSwim = false,
    bool clearClimb = false,
    bool clearBurrow = false,
  }) {
    return CreatureSpeeds(
      walk: walk ?? this.walk,
      fly: clearFly ? null : (fly ?? this.fly),
      swim: clearSwim ? null : (swim ?? this.swim),
      climb: clearClimb ? null : (climb ?? this.climb),
      burrow: clearBurrow ? null : (burrow ?? this.burrow),
    );
  }
}

class CreatureAbilityScores {
  const CreatureAbilityScores({
    this.str = 0,
    this.dex = 0,
    this.con = 0,
    this.int_ = 0,
    this.wis = 0,
    this.cha = 0,
  });

  final int str;
  final int dex;
  final int con;
  final int int_;
  final int wis;
  final int cha;

  int operator [](AbilityKey key) => switch (key) {
        AbilityKey.str => str,
        AbilityKey.dex => dex,
        AbilityKey.con => con,
        AbilityKey.int_ => int_,
        AbilityKey.wis => wis,
        AbilityKey.cha => cha,
      };

  CreatureAbilityScores withAbility(AbilityKey key, int value) {
    return switch (key) {
      AbilityKey.str => copyWith(str: value),
      AbilityKey.dex => copyWith(dex: value),
      AbilityKey.con => copyWith(con: value),
      AbilityKey.int_ => copyWith(int_: value),
      AbilityKey.wis => copyWith(wis: value),
      AbilityKey.cha => copyWith(cha: value),
    };
  }

  factory CreatureAbilityScores.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CreatureAbilityScores();
    return CreatureAbilityScores(
      str: (json['str'] as num?)?.toInt() ?? 0,
      dex: (json['dex'] as num?)?.toInt() ?? 0,
      con: (json['con'] as num?)?.toInt() ?? 0,
      int_: (json['int'] as num?)?.toInt() ?? 0,
      wis: (json['wis'] as num?)?.toInt() ?? 0,
      cha: (json['cha'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'str': str,
        'dex': dex,
        'con': con,
        'int': int_,
        'wis': wis,
        'cha': cha,
      };

  CreatureAbilityScores copyWith({
    int? str,
    int? dex,
    int? con,
    int? int_,
    int? wis,
    int? cha,
  }) {
    return CreatureAbilityScores(
      str: str ?? this.str,
      dex: dex ?? this.dex,
      con: con ?? this.con,
      int_: int_ ?? this.int_,
      wis: wis ?? this.wis,
      cha: cha ?? this.cha,
    );
  }
}

/// Manual “tailor the fit” overrides for computed fields.
class CreatureOverrides {
  const CreatureOverrides({
    this.ac,
    this.hp,
    this.atk,
    this.dc,
    this.dmg,
    this.initiativeBonus,
    this.cr,
    this.xp,
    this.proficiencyBonus,
  });

  final int? ac;
  final int? hp;
  final int? atk;
  final int? dc;
  final int? dmg;
  final int? initiativeBonus;
  final String? cr;
  final int? xp;
  final int? proficiencyBonus;

  factory CreatureOverrides.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CreatureOverrides();
    return CreatureOverrides(
      ac: (json['ac'] as num?)?.toInt(),
      hp: (json['hp'] as num?)?.toInt(),
      atk: (json['atk'] as num?)?.toInt(),
      dc: (json['dc'] as num?)?.toInt(),
      dmg: (json['dmg'] as num?)?.toInt(),
      initiativeBonus: (json['initiativeBonus'] as num?)?.toInt(),
      cr: json['cr'] as String?,
      xp: (json['xp'] as num?)?.toInt(),
      proficiencyBonus: (json['proficiencyBonus'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (ac != null) 'ac': ac,
        if (hp != null) 'hp': hp,
        if (atk != null) 'atk': atk,
        if (dc != null) 'dc': dc,
        if (dmg != null) 'dmg': dmg,
        if (initiativeBonus != null) 'initiativeBonus': initiativeBonus,
        if (cr != null) 'cr': cr,
        if (xp != null) 'xp': xp,
        if (proficiencyBonus != null) 'proficiencyBonus': proficiencyBonus,
      };

  bool get isEmpty =>
      ac == null &&
      hp == null &&
      atk == null &&
      dc == null &&
      dmg == null &&
      initiativeBonus == null &&
      cr == null &&
      xp == null &&
      proficiencyBonus == null;

  CreatureOverrides copyWith({
    int? ac,
    int? hp,
    int? atk,
    int? dc,
    int? dmg,
    int? initiativeBonus,
    String? cr,
    int? xp,
    int? proficiencyBonus,
    bool clearAc = false,
    bool clearHp = false,
    bool clearAtk = false,
    bool clearDc = false,
    bool clearDmg = false,
    bool clearInitiativeBonus = false,
    bool clearCr = false,
    bool clearXp = false,
    bool clearProficiencyBonus = false,
  }) {
    return CreatureOverrides(
      ac: clearAc ? null : (ac ?? this.ac),
      hp: clearHp ? null : (hp ?? this.hp),
      atk: clearAtk ? null : (atk ?? this.atk),
      dc: clearDc ? null : (dc ?? this.dc),
      dmg: clearDmg ? null : (dmg ?? this.dmg),
      initiativeBonus: clearInitiativeBonus
          ? null
          : (initiativeBonus ?? this.initiativeBonus),
      cr: clearCr ? null : (cr ?? this.cr),
      xp: clearXp ? null : (xp ?? this.xp),
      proficiencyBonus: clearProficiencyBonus
          ? null
          : (proficiencyBonus ?? this.proficiencyBonus),
    );
  }
}

class Creature {
  const Creature({
    required this.id,
    required this.name,
    this.size = 'Medium',
    this.creatureType = '',
    this.level = 1,
    this.rank = ScalerRank.grunt,
    this.threat = 1,
    this.role,
    this.roleSubtype,
    this.abilityScores = const CreatureAbilityScores(),
    this.trainedSavingThrows = const [],
    this.reach,
    this.range,
    this.speeds = const CreatureSpeeds(),
    this.senses = const [],
    this.passivePerception = 10,
    this.skills = const [],
    this.vulnerabilities = const [],
    this.resistances = const [],
    this.immunities = const [],
    this.languages = const [],
    this.items = const [],
    this.trigger,
    this.countermeasures = const [],
    this.features = const [],
    this.overrides = const CreatureOverrides(),
    this.damageThreshold,
  });

  final String id;
  final String name;
  final String size;
  final String creatureType;
  final int level;
  final ScalerRank rank;
  final num threat;
  final ScalerRole? role;
  final String? roleSubtype;
  final CreatureAbilityScores abilityScores;
  final List<String> trainedSavingThrows;
  final int? reach;
  final int? range;
  final CreatureSpeeds speeds;
  final List<String> senses;
  final int passivePerception;
  final List<String> skills;
  final List<String> vulnerabilities;
  final List<String> resistances;
  final List<String> immunities;
  final List<String> languages;
  final List<String> items;
  final String? trigger;
  final List<String> countermeasures;
  final List<CreatureFeatureEntry> features;
  final CreatureOverrides overrides;
  final int? damageThreshold;

  ScalerComputedStats get formula => computeScalerStats(
        level: level,
        rank: rank,
        role: role,
        paragonThreat: rank == ScalerRank.paragon ? threat : null,
      );

  int get proficiencyBonus =>
      overrides.proficiencyBonus ?? formula.proficiencyBonus;
  int get ac => overrides.ac ?? formula.ac;
  int get hp => overrides.hp ?? formula.hp;
  int get bloodied => hp ~/ 2;
  int get enraged => hp ~/ 4;
  int get atk => overrides.atk ?? formula.atk;
  int get dc => overrides.dc ?? formula.dc;
  int get dmg => overrides.dmg ?? formula.dmg;
  int get initiativeBonus =>
      overrides.initiativeBonus ?? formula.initiativeBonus;
  String get cr => overrides.cr ?? formula.cr;
  int get xp => overrides.xp ?? formula.xp;

  String get rankDisplay {
    if (rank == ScalerRank.paragon) {
      final t = threat % 1 == 0 ? threat.toInt().toString() : '$threat';
      return 'Paragon T$t';
    }
    return rank.label;
  }

  static String slugify(String name) {
    final slug = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'creature' : slug;
  }

  factory Creature.fromJson(Map<String, dynamic> json) {
    final rank = ScalerRankLabel.fromJson(
      json['rank'] as String? ?? 'grunt',
    );
    return Creature(
      id: json['id'] as String? ?? slugify(json['name'] as String? ?? ''),
      name: json['name'] as String? ?? '',
      size: json['size'] as String? ?? 'Medium',
      creatureType: json['creatureType'] as String? ?? '',
      level: (json['level'] as num?)?.toInt() ?? 1,
      rank: rank,
      threat: (json['threat'] as num?) ??
          effectiveThreat(rank, paragonThreat: 4),
      role: ScalerRoleLabel.fromJson(json['role'] as String?),
      roleSubtype: json['roleSubtype'] as String?,
      abilityScores: CreatureAbilityScores.fromJson(
        json['abilityScores'] as Map<String, dynamic>?,
      ),
      trainedSavingThrows: _stringList(json['trainedSavingThrows']),
      reach: (json['reach'] as num?)?.toInt(),
      range: (json['range'] as num?)?.toInt(),
      speeds: CreatureSpeeds.fromJson(json['speeds'] as Map<String, dynamic>?),
      senses: _stringList(json['senses']),
      passivePerception: (json['passivePerception'] as num?)?.toInt() ?? 10,
      skills: _stringList(json['skills']),
      vulnerabilities: _stringList(json['vulnerabilities']),
      resistances: _stringList(json['resistances']),
      immunities: _stringList(json['immunities']),
      languages: _stringList(json['languages']),
      items: _stringList(json['items']),
      trigger: json['trigger'] as String?,
      countermeasures: _stringList(json['countermeasures']),
      features: [
        for (final f in (json['features'] as List?) ?? const [])
          if (f is Map<String, dynamic>) CreatureFeatureEntry.fromJson(f),
      ],
      overrides: CreatureOverrides.fromJson(
        json['overrides'] as Map<String, dynamic>?,
      ),
      damageThreshold: (json['damageThreshold'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    final f = formula;
    return {
      'id': id,
      'name': name,
      'size': size,
      'creatureType': creatureType,
      'level': level,
      'rank': rank.toJson(),
      'threat': threat,
      'role': role?.toJson(),
      'roleSubtype': roleSubtype,
      'abilityScores': abilityScores.toJson(),
      'proficiencyBonus': proficiencyBonus,
      'ac': ac,
      'trainedSavingThrows': trainedSavingThrows,
      'hp': hp,
      'bloodied': bloodied,
      'damageThreshold': damageThreshold,
      'atk': atk,
      'dc': dc,
      'dmg': dmg,
      'reach': reach,
      'range': range,
      'speeds': speeds.toJson(),
      'initiativeBonus': initiativeBonus,
      'senses': senses,
      'passivePerception': passivePerception,
      'skills': skills,
      'vulnerabilities': vulnerabilities,
      'resistances': resistances,
      'immunities': immunities,
      'languages': languages,
      'items': items,
      'trigger': trigger,
      'countermeasures': countermeasures,
      'cr': cr,
      'xp': xp,
      'features': [for (final feat in features) feat.toJson()],
      if (!overrides.isEmpty) 'overrides': overrides.toJson(),
      // Snapshot of formula tiers for consumers / debugging.
      'abilityTiers': {
        'low': f.abilityLow,
        'mid': f.abilityMid,
        'high': f.abilityHigh,
      },
    };
  }

  Creature copyWith({
    String? id,
    String? name,
    String? size,
    String? creatureType,
    int? level,
    ScalerRank? rank,
    num? threat,
    ScalerRole? role,
    bool clearRole = false,
    String? roleSubtype,
    bool clearRoleSubtype = false,
    CreatureAbilityScores? abilityScores,
    List<String>? trainedSavingThrows,
    int? reach,
    bool clearReach = false,
    int? range,
    bool clearRange = false,
    CreatureSpeeds? speeds,
    List<String>? senses,
    int? passivePerception,
    List<String>? skills,
    List<String>? vulnerabilities,
    List<String>? resistances,
    List<String>? immunities,
    List<String>? languages,
    List<String>? items,
    String? trigger,
    bool clearTrigger = false,
    List<String>? countermeasures,
    List<CreatureFeatureEntry>? features,
    CreatureOverrides? overrides,
    int? damageThreshold,
    bool clearDamageThreshold = false,
  }) {
    return Creature(
      id: id ?? this.id,
      name: name ?? this.name,
      size: size ?? this.size,
      creatureType: creatureType ?? this.creatureType,
      level: level ?? this.level,
      rank: rank ?? this.rank,
      threat: threat ?? this.threat,
      role: clearRole ? null : (role ?? this.role),
      roleSubtype:
          clearRoleSubtype ? null : (roleSubtype ?? this.roleSubtype),
      abilityScores: abilityScores ?? this.abilityScores,
      trainedSavingThrows: trainedSavingThrows ?? this.trainedSavingThrows,
      reach: clearReach ? null : (reach ?? this.reach),
      range: clearRange ? null : (range ?? this.range),
      speeds: speeds ?? this.speeds,
      senses: senses ?? this.senses,
      passivePerception: passivePerception ?? this.passivePerception,
      skills: skills ?? this.skills,
      vulnerabilities: vulnerabilities ?? this.vulnerabilities,
      resistances: resistances ?? this.resistances,
      immunities: immunities ?? this.immunities,
      languages: languages ?? this.languages,
      items: items ?? this.items,
      trigger: clearTrigger ? null : (trigger ?? this.trigger),
      countermeasures: countermeasures ?? this.countermeasures,
      features: features ?? this.features,
      overrides: overrides ?? this.overrides,
      damageThreshold: clearDamageThreshold
          ? null
          : (damageThreshold ?? this.damageThreshold),
    );
  }
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item != null) '$item',
  ];
}

/// Auto-injected rank/role features (replace matching [autoKey] entries).
List<CreatureFeatureEntry> mergeAutoFeatures({
  required List<CreatureFeatureEntry> existing,
  required ScalerRank rank,
  required int level,
  required num threat,
  ScalerRole? role,
}) {
  final kept = existing.where((f) => !f.isAuto).toList();
  final auto = <CreatureFeatureEntry>[
    ...rankAutoFeatures(rank: rank, level: level, threat: threat),
    if (role != null) roleAutoFeature(role),
  ];
  return [...auto, ...kept];
}

List<CreatureFeatureEntry> rankAutoFeatures({
  required ScalerRank rank,
  required int level,
  required num threat,
}) {
  switch (rank) {
    case ScalerRank.minion:
      return [
        CreatureFeatureEntry.local(
          const MonsterFeature(
            name: 'Elusive',
            category: FeatureCategory.trait,
            rarity: FeatureRarity.common,
            autoKey: 'elusive',
            text:
                'Takes no damage from a missed attack, even one that would normally deal damage on a miss or failed save.',
            textOverride: true,
          ),
        ),
      ];
    case ScalerRank.grunt:
      return const [];
    case ScalerRank.elite:
      return [
        CreatureFeatureEntry.local(
          MonsterFeature(
            name: 'Paragon Power',
            category: FeatureCategory.trait,
            rarity: FeatureRarity.uncommon,
            autoKey: 'paragon_power',
            text:
                '1/round: at the end of another creature\'s turn, spend 1 paragon power to Act (regain reaction, take an action, may spend remaining movement) or Resist (reroll a failed save vs. an ongoing effect; may spend HP = ${2 * level} for advantage on the reroll).',
            textOverride: true,
          ),
        ),
      ];
    case ScalerRank.paragon:
      final powers = (threat - 1).clamp(1, 20);
      final defenceUses = (threat / 2);
      final defenceLabel = defenceUses % 1 == 0
          ? defenceUses.toInt().toString()
          : defenceUses.toString();
      return [
        CreatureFeatureEntry.local(
          MonsterFeature(
            name: 'Paragon Power',
            category: FeatureCategory.trait,
            rarity: FeatureRarity.rare,
            autoKey: 'paragon_power',
            text:
                '$powers/round: at the end of another creature\'s turn, spend 1 paragon power to Act or Resist (see Elite Paragon Power; Resist may spend HP = ${2 * level} for advantage).',
            textOverride: true,
          ),
        ),
        CreatureFeatureEntry.local(
          MonsterFeature(
            name: 'Paragon Defence',
            category: FeatureCategory.trait,
            rarity: FeatureRarity.rare,
            autoKey: 'paragon_defence',
            text:
                'When about to fail a saving throw, may instead succeed by spending HP = ${2 * level}. Usable $defenceLabel times per long rest (default: floor(target player count / 2)).',
            textOverride: true,
          ),
        ),
      ];
  }
}

CreatureFeatureEntry roleAutoFeature(ScalerRole role) {
  return switch (role) {
    ScalerRole.controller => CreatureFeatureEntry.local(
        const MonsterFeature(
          name: 'Focused',
          category: FeatureCategory.trait,
          rarity: FeatureRarity.common,
          autoKey: 'role_feature',
          text: 'Advantage on Concentration saving throws.',
          textOverride: true,
        ),
      ),
    ScalerRole.defender => CreatureFeatureEntry.local(
        const MonsterFeature(
          name: 'Opportunist',
          category: FeatureCategory.trait,
          rarity: FeatureRarity.common,
          autoKey: 'role_feature',
          text: 'Advantage on opportunity attacks.',
          textOverride: true,
        ),
      ),
    ScalerRole.lurker => CreatureFeatureEntry.local(
        const MonsterFeature(
          name: 'Sneaky',
          category: FeatureCategory.attack,
          rarity: FeatureRarity.common,
          activationTime: FeatureActivation.bonus,
          autoKey: 'role_feature',
          text: 'Bonus Action: take the Hide action.',
          textOverride: true,
        ),
      ),
    ScalerRole.skirmisher => CreatureFeatureEntry.local(
        const MonsterFeature(
          name: 'Evasive',
          category: FeatureCategory.attack,
          rarity: FeatureRarity.common,
          activationTime: FeatureActivation.bonus,
          autoKey: 'role_feature',
          text: 'Bonus Action: take the Disengage action.',
          textOverride: true,
        ),
      ),
    ScalerRole.striker => CreatureFeatureEntry.local(
        const MonsterFeature(
          name: 'Brutal',
          category: FeatureCategory.trait,
          rarity: FeatureRarity.common,
          autoKey: 'role_feature',
          text: '1/turn: score a critical hit on a roll of 19–20.',
          textOverride: true,
        ),
      ),
    ScalerRole.supporter => CreatureFeatureEntry.local(
        const MonsterFeature(
          name: 'Supportive',
          category: FeatureCategory.attack,
          rarity: FeatureRarity.common,
          activationTime: FeatureActivation.bonus,
          autoKey: 'role_feature',
          text: 'Bonus Action: take the Help action.',
          textOverride: true,
        ),
      ),
  };
}

/// Default ability assignment: two high, two mid, two low in STR…CHA order.
CreatureAbilityScores defaultAbilityAssignment(ScalerComputedStats stats) {
  return CreatureAbilityScores(
    str: stats.abilityHigh,
    dex: stats.abilityHigh,
    con: stats.abilityMid,
    int_: stats.abilityMid,
    wis: stats.abilityLow,
    cha: stats.abilityLow,
  );
}
