enum SpellcastingType {
  full,
  half,
  third,
  pact,
  none;

  String get apiValue => name;

  String get label => switch (this) {
        SpellcastingType.full => 'Full',
        SpellcastingType.half => 'Half',
        SpellcastingType.third => 'Third',
        SpellcastingType.pact => 'Pact',
        SpellcastingType.none => 'None',
      };

  static SpellcastingType parse(String? value) {
    final v = value?.trim().toLowerCase();
    for (final t in SpellcastingType.values) {
      if (t.apiValue == v) return t;
    }
    return SpellcastingType.none;
  }
}

/// Ability labels used on classes (STR…CHA).
const kClassAbilityLabels = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];

String normalizeClassAbility(String? raw) {
  final v = (raw ?? '').trim().toUpperCase();
  if (v.isEmpty) return 'STR';
  if (v == 'INTELLIGENCE') return 'INT';
  if (v == 'STRENGTH') return 'STR';
  if (v == 'DEXTERITY') return 'DEX';
  if (v == 'CONSTITUTION') return 'CON';
  if (v == 'WISDOM') return 'WIS';
  if (v == 'CHARISMA') return 'CHA';
  if (kClassAbilityLabels.contains(v)) return v;
  // Lowercase api values from other models.
  switch (v.toLowerCase()) {
    case 'str':
      return 'STR';
    case 'dex':
      return 'DEX';
    case 'con':
      return 'CON';
    case 'int':
    case 'intel':
      return 'INT';
    case 'wis':
      return 'WIS';
    case 'cha':
      return 'CHA';
    default:
      return v.length <= 3 ? v : v.substring(0, 3);
  }
}

String slugifyClassPart(String name, {String fallback = 'feature'}) {
  final slug = name
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? fallback : slug;
}

class ClassFeature {
  const ClassFeature({
    required this.id,
    required this.name,
    required this.level,
    this.description = '',
  });

  final String id;
  final String name;
  final int level;
  final String description;

  factory ClassFeature.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final level = ((json['level'] as num?)?.toInt() ?? 1).clamp(1, 20);
    return ClassFeature(
      id: json['id'] as String? ?? slugifyClassPart(name),
      name: name,
      level: level,
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'level': level,
        'description': description,
      };

  ClassFeature copyWith({
    String? id,
    String? name,
    int? level,
    String? description,
  }) {
    return ClassFeature(
      id: id ?? this.id,
      name: name ?? this.name,
      level: level ?? this.level,
      description: description ?? this.description,
    );
  }
}

class ClassSubclass {
  const ClassSubclass({
    required this.id,
    required this.name,
    this.chosenAtLevel = 3,
    this.featuresByLevel = const {},
  });

  final String id;
  final String name;
  final int chosenAtLevel;
  final Map<int, List<ClassFeature>> featuresByLevel;

  factory ClassSubclass.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    return ClassSubclass(
      id: json['id'] as String? ?? slugifyClassPart(name, fallback: 'subclass'),
      name: name,
      chosenAtLevel:
          ((json['chosenAtLevel'] as num?)?.toInt() ?? 3).clamp(1, 20),
      featuresByLevel: _featuresByLevelFromJson(json['featuresByLevel']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'chosenAtLevel': chosenAtLevel,
        'featuresByLevel': _featuresByLevelToJson(featuresByLevel),
      };

  ClassSubclass copyWith({
    String? id,
    String? name,
    int? chosenAtLevel,
    Map<int, List<ClassFeature>>? featuresByLevel,
  }) {
    return ClassSubclass(
      id: id ?? this.id,
      name: name ?? this.name,
      chosenAtLevel: chosenAtLevel ?? this.chosenAtLevel,
      featuresByLevel: featuresByLevel ?? this.featuresByLevel,
    );
  }

  List<ClassFeature> get allFeatures {
    final levels = featuresByLevel.keys.toList()..sort();
    return [
      for (final lvl in levels) ...?featuresByLevel[lvl],
    ];
  }
}

class SpellSlotTable {
  const SpellSlotTable({
    this.cantripsKnown = 0,
    this.spellsKnownOrPrepared = 0,
    this.slotsByCircle = const [],
  });

  final int cantripsKnown;
  final int spellsKnownOrPrepared;

  /// Index 0 = 1st-circle slots.
  final List<int> slotsByCircle;

  factory SpellSlotTable.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SpellSlotTable();
    final rawSlots = json['slotsByCircle'];
    final slots = <int>[];
    if (rawSlots is List) {
      for (final e in rawSlots) {
        slots.add((e as num?)?.toInt() ?? 0);
      }
    }
    return SpellSlotTable(
      cantripsKnown: (json['cantripsKnown'] as num?)?.toInt() ?? 0,
      spellsKnownOrPrepared:
          (json['spellsKnownOrPrepared'] as num?)?.toInt() ?? 0,
      slotsByCircle: slots,
    );
  }

  Map<String, dynamic> toJson() => {
        'cantripsKnown': cantripsKnown,
        'spellsKnownOrPrepared': spellsKnownOrPrepared,
        'slotsByCircle': slotsByCircle,
      };

  SpellSlotTable copyWith({
    int? cantripsKnown,
    int? spellsKnownOrPrepared,
    List<int>? slotsByCircle,
  }) {
    return SpellSlotTable(
      cantripsKnown: cantripsKnown ?? this.cantripsKnown,
      spellsKnownOrPrepared:
          spellsKnownOrPrepared ?? this.spellsKnownOrPrepared,
      slotsByCircle: slotsByCircle ?? this.slotsByCircle,
    );
  }
}

class SpellcastingInfo {
  const SpellcastingInfo({
    this.ability = 'INT',
    this.type = SpellcastingType.full,
    this.slotsByLevel = const {},
    this.preparesSpells = true,
  });

  final String ability;
  final SpellcastingType type;
  final Map<int, SpellSlotTable> slotsByLevel;
  final bool preparesSpells;

  factory SpellcastingInfo.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const SpellcastingInfo();
    final rawSlots = json['slotsByLevel'];
    final slots = <int, SpellSlotTable>{};
    if (rawSlots is Map) {
      for (final entry in rawSlots.entries) {
        final level = int.tryParse(entry.key.toString());
        if (level == null || level < 1 || level > 20) continue;
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          slots[level] = SpellSlotTable.fromJson(value);
        } else if (value is Map) {
          slots[level] = SpellSlotTable.fromJson(
            Map<String, dynamic>.from(value),
          );
        }
      }
    }
    return SpellcastingInfo(
      ability: normalizeClassAbility(json['ability'] as String?),
      type: SpellcastingType.parse(json['type'] as String?),
      slotsByLevel: slots,
      preparesSpells: json['preparesSpells'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'ability': ability,
        'type': type.apiValue,
        'slotsByLevel': {
          for (final e in slotsByLevel.entries) '${e.key}': e.value.toJson(),
        },
        'preparesSpells': preparesSpells,
      };

  SpellcastingInfo copyWith({
    String? ability,
    SpellcastingType? type,
    Map<int, SpellSlotTable>? slotsByLevel,
    bool? preparesSpells,
  }) {
    return SpellcastingInfo(
      ability: ability ?? this.ability,
      type: type ?? this.type,
      slotsByLevel: slotsByLevel ?? this.slotsByLevel,
      preparesSpells: preparesSpells ?? this.preparesSpells,
    );
  }
}

class ClassRecord {
  const ClassRecord({
    required this.name,
    this.description = '',
    this.hitDie = 'd8',
    this.primaryAbilities = const [],
    this.savingThrowProficiencies = const [],
    this.armorProficiencies = const [],
    this.weaponProficiencies = const [],
    this.toolProficiencies = const [],
    this.skillChoiceCount = 0,
    this.skillChoices = const [],
    this.featuresByLevel = const {},
    this.subclassChosenAtLevel = 3,
    this.legacySubclasses = const [],
    this.spellcasting,
    bool? isCaster,
  }) : _legacyIsCaster = isCaster;

  final String name;
  final String description;
  final String hitDie;
  final List<String> primaryAbilities;
  final List<String> savingThrowProficiencies;
  final List<String> armorProficiencies;
  final List<String> weaponProficiencies;
  final List<String> toolProficiencies;
  final int skillChoiceCount;
  final List<String> skillChoices;
  final Map<int, List<ClassFeature>> featuresByLevel;
  /// Level at which a subclass is chosen for this class.
  final int subclassChosenAtLevel;
  /// Nested subclasses from older payloads (migrated to catalog records).
  final List<ClassSubclass> legacySubclasses;
  final SpellcastingInfo? spellcasting;
  final bool? _legacyIsCaster;

  /// True when the class should appear on spell class lists.
  bool get isCaster {
    if (spellcasting != null && spellcasting!.type != SpellcastingType.none) {
      return true;
    }
    if (spellcasting != null && spellcasting!.type == SpellcastingType.none) {
      return false;
    }
    return _legacyIsCaster ?? false;
  }

  List<ClassFeature> featuresUpToLevel(int level) {
    return [
      for (var lvl = 1; lvl <= level; lvl++) ...?featuresByLevel[lvl],
    ];
  }

  List<ClassFeature> get allFeatures {
    final levels = featuresByLevel.keys.toList()..sort();
    return [
      for (final lvl in levels) ...?featuresByLevel[lvl],
    ];
  }

  factory ClassRecord.fromJson(Map<String, dynamic> json) {
    return ClassRecord.fromCatalogPayload(
      name: json['name'] as String? ?? '',
      payload: json,
    );
  }

  factory ClassRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return ClassRecord(name: name);
    }

    final legacyCaster = payload['isCaster'] as bool?;
    SpellcastingInfo? spellcasting;
    final rawCasting = payload['spellcasting'];
    if (rawCasting is Map<String, dynamic>) {
      spellcasting = SpellcastingInfo.fromJson(rawCasting);
    } else if (rawCasting is Map) {
      spellcasting = SpellcastingInfo.fromJson(
        Map<String, dynamic>.from(rawCasting),
      );
    } else if (legacyCaster == true) {
      // Preserve caster status without inventing a full slot table.
      spellcasting = const SpellcastingInfo(type: SpellcastingType.full);
    }

    final legacySubclasses = <ClassSubclass>[];
    final rawSubs = payload['subclasses'];
    if (rawSubs is List) {
      for (final e in rawSubs) {
        if (e is Map<String, dynamic>) {
          legacySubclasses.add(ClassSubclass.fromJson(e));
        } else if (e is Map) {
          legacySubclasses
              .add(ClassSubclass.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }

    var subclassChosenAtLevel =
        (payload['subclassChosenAtLevel'] as num?)?.toInt();
    if (subclassChosenAtLevel == null && legacySubclasses.isNotEmpty) {
      subclassChosenAtLevel = legacySubclasses.first.chosenAtLevel;
    }
    subclassChosenAtLevel = (subclassChosenAtLevel ?? 3).clamp(1, 20);

    return ClassRecord(
      name: payload['name'] as String? ?? name,
      description: payload['description'] as String? ?? '',
      hitDie: payload['hitDie'] as String? ?? 'd8',
      primaryAbilities: _stringList(payload['primaryAbilities'])
          .map(normalizeClassAbility)
          .toList(),
      savingThrowProficiencies: _stringList(payload['savingThrowProficiencies'])
          .map(normalizeClassAbility)
          .toList(),
      armorProficiencies: _stringList(payload['armorProficiencies']),
      weaponProficiencies: _stringList(payload['weaponProficiencies']),
      toolProficiencies: _stringList(payload['toolProficiencies']),
      skillChoiceCount: (payload['skillChoiceCount'] as num?)?.toInt() ?? 0,
      skillChoices: _stringList(payload['skillChoices']),
      featuresByLevel: _featuresByLevelFromJson(payload['featuresByLevel']),
      subclassChosenAtLevel: subclassChosenAtLevel,
      legacySubclasses: legacySubclasses,
      spellcasting: spellcasting,
      isCaster: legacyCaster,
    );
  }

  Map<String, dynamic> toJson() {
    final casting = spellcasting;
    final caster = isCaster;
    return {
      'name': name,
      'description': description,
      'isCaster': caster,
      'hitDie': hitDie,
      'primaryAbilities': primaryAbilities,
      'savingThrowProficiencies': savingThrowProficiencies,
      'armorProficiencies': armorProficiencies,
      'weaponProficiencies': weaponProficiencies,
      'toolProficiencies': toolProficiencies,
      'skillChoiceCount': skillChoiceCount,
      'skillChoices': skillChoices,
      'featuresByLevel': _featuresByLevelToJson(featuresByLevel),
      'subclassChosenAtLevel': subclassChosenAtLevel,
      if (casting != null) 'spellcasting': casting.toJson(),
    };
  }

  ClassRecord copyWith({
    String? name,
    String? description,
    String? hitDie,
    List<String>? primaryAbilities,
    List<String>? savingThrowProficiencies,
    List<String>? armorProficiencies,
    List<String>? weaponProficiencies,
    List<String>? toolProficiencies,
    int? skillChoiceCount,
    List<String>? skillChoices,
    Map<int, List<ClassFeature>>? featuresByLevel,
    int? subclassChosenAtLevel,
    List<ClassSubclass>? legacySubclasses,
    SpellcastingInfo? spellcasting,
    bool? isCaster,
    bool clearSpellcasting = false,
  }) {
    return ClassRecord(
      name: name ?? this.name,
      description: description ?? this.description,
      hitDie: hitDie ?? this.hitDie,
      primaryAbilities: primaryAbilities ?? this.primaryAbilities,
      savingThrowProficiencies:
          savingThrowProficiencies ?? this.savingThrowProficiencies,
      armorProficiencies: armorProficiencies ?? this.armorProficiencies,
      weaponProficiencies: weaponProficiencies ?? this.weaponProficiencies,
      toolProficiencies: toolProficiencies ?? this.toolProficiencies,
      skillChoiceCount: skillChoiceCount ?? this.skillChoiceCount,
      skillChoices: skillChoices ?? this.skillChoices,
      featuresByLevel: featuresByLevel ?? this.featuresByLevel,
      subclassChosenAtLevel:
          subclassChosenAtLevel ?? this.subclassChosenAtLevel,
      legacySubclasses: legacySubclasses ?? this.legacySubclasses,
      spellcasting:
          clearSpellcasting ? null : (spellcasting ?? this.spellcasting),
      isCaster: isCaster ?? _legacyIsCaster,
    );
  }
}

Map<String, dynamic>? _mapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

List<String> _stringList(dynamic value) {
  if (value is! List) return const [];
  return [
    for (final e in value)
      if (e != null && e.toString().trim().isNotEmpty) e.toString().trim(),
  ];
}

Map<int, List<ClassFeature>> featuresByLevelFromJson(dynamic raw) {
  final result = <int, List<ClassFeature>>{};
  if (raw is! Map) return result;
  for (final entry in raw.entries) {
    final level = int.tryParse(entry.key.toString());
    if (level == null || level < 1 || level > 20) continue;
    final list = <ClassFeature>[];
    final value = entry.value;
    if (value is List) {
      for (final e in value) {
        if (e is Map<String, dynamic>) {
          list.add(ClassFeature.fromJson({...e, 'level': e['level'] ?? level}));
        } else if (e is Map) {
          final map = Map<String, dynamic>.from(e);
          map.putIfAbsent('level', () => level);
          list.add(ClassFeature.fromJson(map));
        }
      }
    }
    if (list.isNotEmpty) result[level] = list;
  }
  return result;
}

Map<String, dynamic> featuresByLevelToJson(
  Map<int, List<ClassFeature>> features,
) {
  final sorted = features.keys.toList()..sort();
  return {
    for (final level in sorted)
      '$level': [
        for (final f in features[level] ?? const <ClassFeature>[])
          f.copyWith(level: level).toJson(),
      ],
  };
}

Map<int, List<ClassFeature>> _featuresByLevelFromJson(dynamic raw) =>
    featuresByLevelFromJson(raw);

Map<String, dynamic> _featuresByLevelToJson(
  Map<int, List<ClassFeature>> features,
) =>
    featuresByLevelToJson(features);
