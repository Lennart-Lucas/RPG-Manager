// D&D 5e spell data model. Hand-written fromJson/toJson (no codegen).

import 'package:flutter/material.dart';

enum SpellSchool {
  abjuration,
  conjuration,
  divination,
  enchantment,
  evocation,
  illusion,
  necromancy,
  transmutation;

  String get label => name[0].toUpperCase() + name.substring(1);

  IconData get icon => switch (this) {
        SpellSchool.abjuration => Icons.shield_outlined,
        SpellSchool.conjuration => Icons.auto_awesome_outlined,
        SpellSchool.divination => Icons.visibility_outlined,
        SpellSchool.enchantment => Icons.favorite_outline,
        SpellSchool.evocation => Icons.local_fire_department_outlined,
        SpellSchool.illusion => Icons.blur_on_outlined,
        SpellSchool.necromancy => Icons.sick_outlined,
        SpellSchool.transmutation => Icons.change_circle_outlined,
      };

  static SpellSchool fromJson(String value) => SpellSchool.values.firstWhere(
        (e) => e.name == value.toLowerCase(),
        orElse: () => throw ArgumentError('Unknown school: $value'),
      );

  String toJson() => name;

  /// Prefer this for UI; necromancy uses a skull glyph (no Material skull icon).
  Widget buildIcon({double size = 20, Color? color}) {
    if (this == SpellSchool.necromancy) {
      return Text(
        '☠',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: size,
          height: 1,
          color: color,
        ),
      );
    }
    return Icon(icon, size: size, color: color);
  }
}

enum SpellAttackType {
  none,
  melee,
  ranged;

  String get label => switch (this) {
        SpellAttackType.none => 'None',
        SpellAttackType.melee => 'Melee',
        SpellAttackType.ranged => 'Ranged',
      };
}

enum SavingThrowAbility {
  none,
  strength,
  dexterity,
  constitution,
  intelligence,
  wisdom,
  charisma;

  String get label => switch (this) {
        SavingThrowAbility.none => 'None',
        SavingThrowAbility.strength => 'Strength',
        SavingThrowAbility.dexterity => 'Dexterity',
        SavingThrowAbility.constitution => 'Constitution',
        SavingThrowAbility.intelligence => 'Intelligence',
        SavingThrowAbility.wisdom => 'Wisdom',
        SavingThrowAbility.charisma => 'Charisma',
      };
}

enum DurationType {
  instantaneous,
  oneRound,
  oneMinute,
  tenMinutes,
  oneHour,
  eightHours,
  twentyFourHours,
  oneDay,
  sevenDays,
  tenDays,
  thirtyDays,
  untilDispelled,
  untilDispelledOrTriggered,
  special;

  String get label => switch (this) {
        DurationType.instantaneous => 'Instantaneous',
        DurationType.oneRound => '1 round',
        DurationType.oneMinute => '1 minute',
        DurationType.tenMinutes => '10 minutes',
        DurationType.oneHour => '1 hour',
        DurationType.eightHours => '8 hours',
        DurationType.twentyFourHours => '24 hours',
        DurationType.oneDay => '1 day',
        DurationType.sevenDays => '7 days',
        DurationType.tenDays => '10 days',
        DurationType.thirtyDays => '30 days',
        DurationType.untilDispelled => 'Until dispelled',
        DurationType.untilDispelledOrTriggered => 'Until dispelled or triggered',
        DurationType.special => 'Special',
      };
}

enum RangeType {
  self,
  touch,
  ranged,
  sight,
  unlimited,
  special;

  String get label => switch (this) {
        RangeType.self => 'Self',
        RangeType.touch => 'Touch',
        RangeType.ranged => 'Ranged',
        RangeType.sight => 'Sight',
        RangeType.unlimited => 'Unlimited',
        RangeType.special => 'Special',
      };
}

class SpellComponents {
  final bool verbal;
  final bool somatic;
  final bool material;
  final String? materialDescription;
  final double? materialCostGp;
  final bool materialConsumed;

  const SpellComponents({
    required this.verbal,
    required this.somatic,
    required this.material,
    this.materialDescription,
    this.materialCostGp,
    this.materialConsumed = false,
  });

  String get shortLabel {
    final parts = <String>[
      if (verbal) 'V',
      if (somatic) 'S',
      if (material) 'M',
    ];
    var label = parts.join(', ');
    if (material && materialDescription != null) {
      label += ' ($materialDescription)';
    }
    return label.isEmpty ? '—' : label;
  }

  factory SpellComponents.fromJson(Map<String, dynamic> json) {
    return SpellComponents(
      verbal: json['verbal'] as bool? ?? false,
      somatic: json['somatic'] as bool? ?? false,
      material: json['material'] as bool? ?? false,
      materialDescription: json['materialDescription'] as String?,
      materialCostGp: (json['materialCostGp'] as num?)?.toDouble(),
      materialConsumed: json['materialConsumed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'verbal': verbal,
        'somatic': somatic,
        'material': material,
        if (materialDescription != null)
          'materialDescription': materialDescription,
        if (materialCostGp != null) 'materialCostGp': materialCostGp,
        'materialConsumed': materialConsumed,
      };
}

class SpellDuration {
  final DurationType type;
  final bool concentration;
  final String? special;

  const SpellDuration({
    required this.type,
    this.concentration = false,
    this.special,
  });

  const SpellDuration.instantaneous()
      : type = DurationType.instantaneous,
        concentration = false,
        special = null;

  String get label {
    final base = type == DurationType.special
        ? (special ?? 'Special')
        : type.label;
    if (!concentration || type == DurationType.instantaneous) return base;
    return 'Concentration, up to $base';
  }

  factory SpellDuration.fromJson(Map<String, dynamic> json) {
    return SpellDuration(
      type: _parseDurationType(json),
      concentration: json['concentration'] as bool? ?? false,
      special: json['special'] as String?,
    );
  }

  static DurationType _parseDurationType(Map<String, dynamic> json) {
    final raw = json['type'] as String?;
    if (raw == null) return DurationType.instantaneous;

    for (final type in DurationType.values) {
      if (type.name == raw) return type;
    }

    // Legacy timed payloads: { type: "timed", amount, unit }
    if (raw == 'timed') {
      final amount = json['amount'] as int?;
      final unit = (json['unit'] as String?)?.toLowerCase().trim();
      return switch ((amount, unit)) {
        (1, 'round') => DurationType.oneRound,
        (1, 'minute') => DurationType.oneMinute,
        (10, 'minute' || 'minutes') => DurationType.tenMinutes,
        (1, 'hour') => DurationType.oneHour,
        (8, 'hour' || 'hours') => DurationType.eightHours,
        (24, 'hour' || 'hours') => DurationType.twentyFourHours,
        (1, 'day') => DurationType.oneDay,
        (7, 'day' || 'days') => DurationType.sevenDays,
        (10, 'day' || 'days') => DurationType.tenDays,
        (30, 'day' || 'days') => DurationType.thirtyDays,
        _ => DurationType.special,
      };
    }

    return DurationType.instantaneous;
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'concentration': concentration,
        if (special != null) 'special': special,
      };
}

class SpellRange {
  final RangeType type;
  final int? distanceFeet;
  final String? special;

  const SpellRange({required this.type, this.distanceFeet, this.special});

  const SpellRange.self()
      : type = RangeType.self,
        distanceFeet = null,
        special = null;

  const SpellRange.touch()
      : type = RangeType.touch,
        distanceFeet = null,
        special = null;

  String get label {
    switch (type) {
      case RangeType.self:
        return 'Self';
      case RangeType.touch:
        return 'Touch';
      case RangeType.sight:
        return 'Sight';
      case RangeType.unlimited:
        return 'Unlimited';
      case RangeType.ranged:
        return '${distanceFeet ?? 0} feet';
      case RangeType.special:
        return special ?? 'Special';
    }
  }

  factory SpellRange.fromJson(Map<String, dynamic> json) {
    return SpellRange(
      type: RangeType.values.byName(json['type'] as String),
      distanceFeet: json['distanceFeet'] as int?,
      special: json['special'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        if (distanceFeet != null) 'distanceFeet': distanceFeet,
        if (special != null) 'special': special,
      };
}

class CastingTime {
  final int amount;
  final String unit;
  final String? reactionTrigger;

  const CastingTime({
    required this.amount,
    required this.unit,
    this.reactionTrigger,
  });

  const CastingTime.action()
      : amount = 1,
        unit = 'action',
        reactionTrigger = null;

  const CastingTime.bonusAction()
      : amount = 1,
        unit = 'bonus action',
        reactionTrigger = null;

  String get label {
    final plural = amount == 1 ? '' : 's';
    var text = '$amount $unit$plural';
    if (reactionTrigger != null) text += ', $reactionTrigger';
    return text;
  }

  factory CastingTime.fromJson(Map<String, dynamic> json) {
    return CastingTime(
      amount: json['amount'] as int,
      unit: json['unit'] as String,
      reactionTrigger: json['reactionTrigger'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'unit': unit,
        if (reactionTrigger != null) 'reactionTrigger': reactionTrigger,
      };
}

class SpellScaling {
  final String? description;
  final String? damageDiceIncrement;
  final List<int>? cantripLevelBreakpoints;

  const SpellScaling({
    this.description,
    this.damageDiceIncrement,
    this.cantripLevelBreakpoints,
  });

  factory SpellScaling.fromJson(Map<String, dynamic> json) {
    return SpellScaling(
      description: json['description'] as String?,
      damageDiceIncrement: json['damageDiceIncrement'] as String?,
      cantripLevelBreakpoints: (json['cantripLevelBreakpoints'] as List?)
          ?.map((e) => e as int)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (description != null) 'description': description,
        if (damageDiceIncrement != null)
          'damageDiceIncrement': damageDiceIncrement,
        if (cantripLevelBreakpoints != null)
          'cantripLevelBreakpoints': cantripLevelBreakpoints,
      };
}

class SpellDamage {
  final String? dice;
  final String? damageType;

  const SpellDamage({this.dice, this.damageType});

  factory SpellDamage.fromJson(Map<String, dynamic> json) {
    return SpellDamage(
      dice: json['dice'] as String?,
      damageType: json['damageType'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (dice != null) 'dice': dice,
        if (damageType != null) 'damageType': damageType,
      };
}

class Spell {
  final String id;
  final String name;
  final int level;
  final SpellSchool school;
  final CastingTime castingTime;
  final SpellRange range;
  final SpellComponents components;
  final SpellDuration duration;
  /// Catalog item IDs for caster classes.
  final List<int> classIds;
  final String description;
  final SpellScaling? higherLevels;
  final SpellDamage? damage;
  final SavingThrowAbility savingThrow;
  final SpellAttackType attackType;
  /// Resource file ID from DM Tools → Resources.
  final int? sourceFileId;
  final int? sourcePage;

  const Spell({
    required this.id,
    required this.name,
    required this.level,
    required this.school,
    required this.castingTime,
    required this.range,
    required this.components,
    required this.duration,
    required this.classIds,
    required this.description,
    this.higherLevels,
    this.damage,
    this.savingThrow = SavingThrowAbility.none,
    this.attackType = SpellAttackType.none,
    this.sourceFileId,
    this.sourcePage,
  }) : assert(level >= 0 && level <= 9, 'Spell level must be 0-9');

  bool get isCantrip => level == 0;
  bool get isConcentration => duration.concentration;

  String get levelSchoolLabel {
    if (isCantrip) return '${school.label} cantrip';
    return '${_ordinal(level)}-level ${school.name}';
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  static String slugify(String name) {
    final slug = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'spell' : slug;
  }

  static List<int> _parseClassIds(dynamic raw) {
    if (raw is! List) return const [];
    final ids = <int>[];
    for (final item in raw) {
      if (item is int) {
        ids.add(item);
      } else if (item is num) {
        ids.add(item.toInt());
      }
      // Legacy string class names are ignored.
    }
    return ids;
  }

  factory Spell.fromJson(Map<String, dynamic> json) {
    return Spell(
      id: json['id'] as String,
      name: json['name'] as String,
      level: json['level'] as int,
      school: SpellSchool.fromJson(json['school'] as String),
      castingTime: CastingTime.fromJson(
        json['castingTime'] as Map<String, dynamic>,
      ),
      range: SpellRange.fromJson(json['range'] as Map<String, dynamic>),
      components: SpellComponents.fromJson(
        json['components'] as Map<String, dynamic>,
      ),
      duration: SpellDuration.fromJson(
        json['duration'] as Map<String, dynamic>,
      ),
      classIds: _parseClassIds(json['classIds'] ?? json['classes']),
      description: json['description'] as String? ?? '',
      higherLevels: json['higherLevels'] != null
          ? SpellScaling.fromJson(
              json['higherLevels'] as Map<String, dynamic>,
            )
          : null,
      damage: json['damage'] != null
          ? SpellDamage.fromJson(json['damage'] as Map<String, dynamic>)
          : null,
      savingThrow: json['savingThrow'] != null
          ? SavingThrowAbility.values.byName(json['savingThrow'] as String)
          : SavingThrowAbility.none,
      attackType: json['attackType'] != null
          ? SpellAttackType.values.byName(json['attackType'] as String)
          : SpellAttackType.none,
      sourceFileId: json['sourceFileId'] as int? ??
          (json['source_file_id'] as int?),
      sourcePage: json['sourcePage'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'level': level,
        'school': school.toJson(),
        'castingTime': castingTime.toJson(),
        'range': range.toJson(),
        'components': components.toJson(),
        'duration': duration.toJson(),
        'classIds': classIds,
        'description': description,
        if (higherLevels != null) 'higherLevels': higherLevels!.toJson(),
        if (damage != null) 'damage': damage!.toJson(),
        'savingThrow': savingThrow.name,
        'attackType': attackType.name,
        if (sourceFileId != null) 'sourceFileId': sourceFileId,
        if (sourcePage != null) 'sourcePage': sourcePage,
      };

  Spell copyWith({
    String? id,
    String? name,
    int? level,
    SpellSchool? school,
    CastingTime? castingTime,
    SpellRange? range,
    SpellComponents? components,
    SpellDuration? duration,
    List<int>? classIds,
    String? description,
    SpellScaling? higherLevels,
    SpellDamage? damage,
    SavingThrowAbility? savingThrow,
    SpellAttackType? attackType,
    int? sourceFileId,
    int? sourcePage,
  }) {
    return Spell(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      school: school ?? this.school,
      castingTime: castingTime ?? this.castingTime,
      range: range ?? this.range,
      components: components ?? this.components,
      duration: duration ?? this.duration,
      classIds: classIds ?? this.classIds,
      description: description ?? this.description,
      higherLevels: higherLevels ?? this.higherLevels,
      damage: damage ?? this.damage,
      savingThrow: savingThrow ?? this.savingThrow,
      attackType: attackType ?? this.attackType,
      sourceFileId: sourceFileId ?? this.sourceFileId,
      sourcePage: sourcePage ?? this.sourcePage,
    );
  }

  @override
  bool operator ==(Object other) => other is Spell && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Spell($name, $levelSchoolLabel)';
}
