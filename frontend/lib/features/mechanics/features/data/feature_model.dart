/// Giffyglyph Monster Maker Part 2 — feature / effect models.
library;

enum FeatureCategory { trait, attack, utility }

enum FeatureRarity { common, uncommon, rare }

enum FeatureActivation {
  none,
  bonus,
  action,
  reaction,
}

enum FeatureLimitationType {
  none,
  charges,
  recharge,
  cooldown,
  recoveryEvent,
}

enum FeatureDefence { ac, str, dex, con, int_, wis, cha }

enum FeatureDelivery { weapon, magic }

enum FeatureRangeMode { melee, ranged }

enum FeatureTargetQuantity { none, one, limited, all }

enum FeatureTargetCategory { target, object, creature, self }

enum FeatureTargetAlliance { any, friendly, hostile }

enum FeatureDeferralType { none, delayed, dooming }

enum FeatureEffectType {
  damage,
  condition,
  terrain,
  resource,
  movement,
  empower,
}

enum FeatureEffectDuration {
  instant,
  concentration,
  ongoing,
}

enum FeatureBudgetSlot { ancestral, role, misc }

enum DamageDeliveryMode { aimedSingle, aimedMulti, area }

enum MovementKind { direct, pull, push, slide }

extension FeatureRarityApi on FeatureRarity {
  String get label => name[0].toUpperCase() + name.substring(1);
  int get baseEffectPoints => switch (this) {
        FeatureRarity.common => 1,
        FeatureRarity.uncommon => 3,
        FeatureRarity.rare => 5,
      };
  String toJson() => name;
  static FeatureRarity fromJson(String? v) => FeatureRarity.values.firstWhere(
        (e) => e.name == v,
        orElse: () => FeatureRarity.common,
      );
}

extension FeatureCategoryApi on FeatureCategory {
  String get label => name[0].toUpperCase() + name.substring(1);
  String toJson() => name;
  static FeatureCategory fromJson(String? v) =>
      FeatureCategory.values.firstWhere(
        (e) => e.name == v,
        orElse: () => FeatureCategory.trait,
      );
}

extension FeatureActivationApi on FeatureActivation {
  String get label => switch (this) {
        FeatureActivation.none => 'Trait',
        FeatureActivation.bonus => 'Bonus Action',
        FeatureActivation.action => 'Action',
        FeatureActivation.reaction => 'Reaction',
      };
  String toJson() => name;
  static FeatureActivation fromJson(String? v) {
    if (v == 'free') return FeatureActivation.bonus;
    if (v == 'time') return FeatureActivation.action;
    return FeatureActivation.values.firstWhere(
      (e) => e.name == v,
      orElse: () => FeatureActivation.none,
    );
  }
}

extension FeatureDeliveryApi on FeatureDelivery {
  String get label => switch (this) {
        FeatureDelivery.weapon => 'Weapon',
        FeatureDelivery.magic => 'Magic',
      };
  String toJson() => name;
  static FeatureDelivery fromJson(String? v) =>
      FeatureDelivery.values.firstWhere(
        (e) => e.name == v,
        orElse: () => FeatureDelivery.weapon,
      );
}

extension FeatureRangeModeApi on FeatureRangeMode {
  String get label => switch (this) {
        FeatureRangeMode.melee => 'Melee',
        FeatureRangeMode.ranged => 'Range',
      };
  String get distanceLabel => switch (this) {
        FeatureRangeMode.melee => 'Reach',
        FeatureRangeMode.ranged => 'Range',
      };
  String toJson() => name;
  static FeatureRangeMode fromJson(String? v) =>
      FeatureRangeMode.values.firstWhere(
        (e) => e.name == v || (v == 'range' && e == FeatureRangeMode.ranged),
        orElse: () => FeatureRangeMode.melee,
      );
}

extension FeatureTargetAllianceApi on FeatureTargetAlliance {
  String get label => switch (this) {
        FeatureTargetAlliance.any => 'Any',
        FeatureTargetAlliance.friendly => 'Friendly',
        FeatureTargetAlliance.hostile => 'Hostile',
      };

  /// Lowercase word for rules text; null when alliance is unrestricted.
  String? get displayWord => switch (this) {
        FeatureTargetAlliance.any => null,
        FeatureTargetAlliance.friendly => 'friendly',
        FeatureTargetAlliance.hostile => 'hostile',
      };

  String toJson() => name;
  static FeatureTargetAlliance fromJson(String? v) {
    if (v == null || v.isEmpty) return FeatureTargetAlliance.any;
    final n = v.toLowerCase();
    return FeatureTargetAlliance.values.firstWhere(
      (e) => e.name == n,
      orElse: () => FeatureTargetAlliance.any,
    );
  }
}

extension FeatureTargetQuantityApi on FeatureTargetQuantity {
  String get label => switch (this) {
        FeatureTargetQuantity.none => 'None',
        FeatureTargetQuantity.one => 'One',
        FeatureTargetQuantity.limited => 'Limited',
        FeatureTargetQuantity.all => 'All',
      };
}

extension FeatureTargetCategoryApi on FeatureTargetCategory {
  String get label => switch (this) {
        FeatureTargetCategory.target => 'Target',
        FeatureTargetCategory.object => 'Object',
        FeatureTargetCategory.creature => 'Creature',
        FeatureTargetCategory.self => 'Self',
      };
}

extension FeatureLimitationTypeApi on FeatureLimitationType {
  String get label => switch (this) {
        FeatureLimitationType.none => 'None',
        FeatureLimitationType.charges => 'Charges',
        FeatureLimitationType.recharge => 'Recharge',
        FeatureLimitationType.cooldown => 'Cooldown',
        FeatureLimitationType.recoveryEvent => 'Recovery Event',
      };
}

extension FeatureDeferralTypeApi on FeatureDeferralType {
  String get label => switch (this) {
        FeatureDeferralType.none => 'None',
        FeatureDeferralType.delayed => 'Delayed',
        FeatureDeferralType.dooming => 'Dooming',
      };
}

extension FeatureBudgetSlotApi on FeatureBudgetSlot {
  String get label => switch (this) {
        FeatureBudgetSlot.ancestral => 'Ancestral',
        FeatureBudgetSlot.role => 'Role',
        FeatureBudgetSlot.misc => 'Misc',
      };
}

extension FeatureEffectTypeApi on FeatureEffectType {
  String get label => switch (this) {
        FeatureEffectType.damage => 'Damage',
        FeatureEffectType.condition => 'Condition',
        FeatureEffectType.terrain => 'Terrain',
        FeatureEffectType.resource => 'Resource',
        FeatureEffectType.movement => 'Movement',
        FeatureEffectType.empower => 'Empower',
      };
}

extension FeatureEffectDurationApi on FeatureEffectDuration {
  String get label => switch (this) {
        FeatureEffectDuration.instant => 'Instant',
        FeatureEffectDuration.concentration => 'Concentration',
        FeatureEffectDuration.ongoing => 'Ongoing',
      };

  int get extraEpCost => switch (this) {
        FeatureEffectDuration.instant => 0,
        FeatureEffectDuration.concentration ||
        FeatureEffectDuration.ongoing =>
          1,
      };

  String get pickLabel => switch (this) {
        FeatureEffectDuration.instant => label,
        FeatureEffectDuration.concentration ||
        FeatureEffectDuration.ongoing =>
          '$label (${extraEpCost}EP)',
      };

  String toJson() => name;

  static FeatureEffectDuration fromJson(String? v) {
    if (v == 'endOfYourNextTurn' ||
        v == 'endOfTargetNextTurn' ||
        v == 'saveEnds') {
      return FeatureEffectDuration.concentration;
    }
    return FeatureEffectDuration.values.firstWhere(
      (e) => e.name == v,
      orElse: () => FeatureEffectDuration.instant,
    );
  }
}

extension FeatureDefenceApi on FeatureDefence {
  String get label => switch (this) {
        FeatureDefence.ac => 'AC',
        FeatureDefence.str => 'STR',
        FeatureDefence.dex => 'DEX',
        FeatureDefence.con => 'CON',
        FeatureDefence.int_ => 'INT',
        FeatureDefence.wis => 'WIS',
        FeatureDefence.cha => 'CHA',
      };
  String toJson() => switch (this) {
        FeatureDefence.int_ => 'INT',
        FeatureDefence.ac => 'AC',
        _ => name.toUpperCase(),
      };
  static FeatureDefence? fromJson(String? v) {
    if (v == null || v.isEmpty) return null;
    final n = v.toLowerCase();
    return switch (n) {
      'ac' => FeatureDefence.ac,
      'str' => FeatureDefence.str,
      'dex' => FeatureDefence.dex,
      'con' => FeatureDefence.con,
      'int' || 'int_' => FeatureDefence.int_,
      'wis' => FeatureDefence.wis,
      'cha' => FeatureDefence.cha,
      _ => null,
    };
  }
}

class FeatureLimitation {
  const FeatureLimitation({
    this.type = FeatureLimitationType.none,
    this.value,
    this.recoveryTrigger,
  });

  final FeatureLimitationType type;
  /// Charges count, recharge label (e.g. "5-6"), cooldown turns, or event name.
  final String? value;
  final String? recoveryTrigger;

  factory FeatureLimitation.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FeatureLimitation();
    return FeatureLimitation(
      type: FeatureLimitationType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'none'),
        orElse: () => FeatureLimitationType.none,
      ),
      value: json['value']?.toString(),
      recoveryTrigger: json['recoveryTrigger'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'value': value,
        if (recoveryTrigger != null) 'recoveryTrigger': recoveryTrigger,
      };
}

class FeatureRange {
  const FeatureRange({
    this.mode = FeatureRangeMode.melee,
    this.feet,
  });

  final FeatureRangeMode mode;
  final int? feet;

  factory FeatureRange.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FeatureRange();
    if (json.containsKey('mode') || json.containsKey('feet')) {
      return FeatureRange(
        mode: FeatureRangeModeApi.fromJson(json['mode'] as String?),
        feet: (json['feet'] as num?)?.toInt(),
      );
    }
    // Legacy self/aimed/area + template/distance
    final category = json['category'] as String? ?? 'self';
    final distance = json['distance'] as String? ?? '';
    final match = RegExp(r'\d+').firstMatch(distance);
    return FeatureRange(
      mode: category == 'self'
          ? FeatureRangeMode.melee
          : FeatureRangeMode.ranged,
      feet: match == null ? null : int.tryParse(match.group(0)!),
    );
  }

  Map<String, dynamic> toJson() => {
        'mode': mode.toJson(),
        'feet': feet,
      };
}

class FeatureTargets {
  const FeatureTargets({
    this.quantity = FeatureTargetQuantity.none,
    this.limitedCount,
    this.category = FeatureTargetCategory.target,
    this.alliance = FeatureTargetAlliance.any,
    this.creatureTypeIds = const [],
  });

  final FeatureTargetQuantity quantity;
  final int? limitedCount;
  final FeatureTargetCategory category;
  final FeatureTargetAlliance alliance;
  final List<int> creatureTypeIds;

  factory FeatureTargets.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FeatureTargets();
    final rawIds = json['creatureTypeIds'];
    final ids = <int>[
      if (rawIds is List)
        for (final e in rawIds)
          if (e is num)
            e.toInt()
          else if (e is String) ?int.tryParse(e.trim()),
    ];
    return FeatureTargets(
      quantity: FeatureTargetQuantity.values.firstWhere(
        (e) => e.name == (json['quantity'] as String? ?? 'none'),
        orElse: () => FeatureTargetQuantity.none,
      ),
      limitedCount: (json['limitedCount'] as num?)?.toInt(),
      category: FeatureTargetCategory.values.firstWhere(
        (e) => e.name == (json['category'] as String? ?? 'target'),
        orElse: () => FeatureTargetCategory.target,
      ),
      alliance: FeatureTargetAllianceApi.fromJson(json['alliance'] as String?),
      creatureTypeIds: ids,
    );
  }

  Map<String, dynamic> toJson() => {
        'quantity': quantity.name,
        'limitedCount': limitedCount,
        'category': category.name,
        'alliance': alliance.toJson(),
        'creatureTypeIds': creatureTypeIds,
      };
}

class FeatureDeferral {
  const FeatureDeferral({
    this.type = FeatureDeferralType.none,
    this.turns,
  });

  final FeatureDeferralType type;
  final int? turns;

  factory FeatureDeferral.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const FeatureDeferral();
    return FeatureDeferral(
      type: FeatureDeferralType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'none'),
        orElse: () => FeatureDeferralType.none,
      ),
      turns: (json['turns'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'turns': turns,
      };

  bool get isActive => type != FeatureDeferralType.none;
}

class FeatureEffect {
  const FeatureEffect({
    required this.type,
    required this.cost,
    this.duration = FeatureEffectDuration.instant,
    this.payload = const {},
  });

  final FeatureEffectType type;
  final int cost;
  final FeatureEffectDuration duration;
  final Map<String, dynamic> payload;

  factory FeatureEffect.fromJson(Map<String, dynamic> json) {
    return FeatureEffect(
      type: FeatureEffectType.values.firstWhere(
        (e) => e.name == (json['type'] as String? ?? 'damage'),
        orElse: () => FeatureEffectType.damage,
      ),
      cost: (json['cost'] as num?)?.toInt() ?? 0,
      duration: FeatureEffectDurationApi.fromJson(
        json['duration'] as String?,
      ),
      payload: json['payload'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'cost': cost,
        'duration': duration.name,
        'payload': payload,
      };

  FeatureEffect copyWith({
    FeatureEffectType? type,
    int? cost,
    FeatureEffectDuration? duration,
    Map<String, dynamic>? payload,
  }) {
    return FeatureEffect(
      type: type ?? this.type,
      cost: cost ?? this.cost,
      duration: duration ?? this.duration,
      payload: payload ?? this.payload,
    );
  }
}

class MonsterFeature {
  const MonsterFeature({
    this.id = '',
    required this.name,
    this.category = FeatureCategory.trait,
    this.rarity = FeatureRarity.common,
    this.delivery = FeatureDelivery.weapon,
    this.effectPoints = 1,
    this.activationTime = FeatureActivation.none,
    this.hasRequirement = false,
    this.limitation = const FeatureLimitation(),
    this.defence,
    this.range = const FeatureRange(),
    this.targets = const FeatureTargets(),
    this.deferral = const FeatureDeferral(),
    this.effects = const [],
    this.text = '',
    this.textOverride = false,
    this.monstrousTraitId,
    this.budgetSlot,
    this.autoKey,
  });

  final String id;
  final String name;
  final FeatureCategory category;
  final FeatureRarity rarity;
  final FeatureDelivery delivery;
  final int effectPoints;
  final FeatureActivation activationTime;
  final bool hasRequirement;
  final FeatureLimitation limitation;
  final FeatureDefence? defence;
  final FeatureRange range;
  final FeatureTargets targets;
  final FeatureDeferral deferral;
  final List<FeatureEffect> effects;
  final String text;
  final bool textOverride;
  final String? monstrousTraitId;
  final FeatureBudgetSlot? budgetSlot;
  final String? autoKey;

  factory MonsterFeature.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return MonsterFeature(name: name);
    }
    final map = Map<String, dynamic>.from(payload);
    map.putIfAbsent('name', () => name);
    return MonsterFeature.fromJson(map);
  }

  factory MonsterFeature.fromJson(Map<String, dynamic> json) {
    // Legacy creature feature shape.
    if (json['source'] == null &&
        json['category'] == null &&
        json['type'] != null) {
      return _fromLegacy(json);
    }
    return MonsterFeature(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: FeatureCategoryApi.fromJson(json['category'] as String?),
      rarity: FeatureRarityApi.fromJson(json['rarity'] as String?),
      delivery: FeatureDeliveryApi.fromJson(json['delivery'] as String?),
      effectPoints: (json['effectPoints'] as num?)?.toInt() ?? 1,
      activationTime:
          FeatureActivationApi.fromJson(json['activationTime'] as String?),
      hasRequirement: json['hasRequirement'] == true,
      limitation: FeatureLimitation.fromJson(
        json['limitation'] as Map<String, dynamic>?,
      ),
      defence: FeatureDefenceApi.fromJson(json['defence'] as String?),
      range: FeatureRange.fromJson(json['range'] as Map<String, dynamic>?),
      targets:
          FeatureTargets.fromJson(json['targets'] as Map<String, dynamic>?),
      deferral:
          FeatureDeferral.fromJson(json['deferral'] as Map<String, dynamic>?),
      effects: [
        for (final e in (json['effects'] as List?) ?? const [])
          if (e is Map<String, dynamic>) FeatureEffect.fromJson(e),
      ],
      text: json['text'] as String? ?? '',
      textOverride: json['textOverride'] == true,
      monstrousTraitId: json['monstrousTraitId'] as String?,
      budgetSlot: json['budgetSlot'] == null
          ? null
          : FeatureBudgetSlot.values.firstWhere(
              (e) => e.name == json['budgetSlot'],
              orElse: () => FeatureBudgetSlot.misc,
            ),
      autoKey: json['autoKey'] as String?,
    );
  }

  static MonsterFeature _fromLegacy(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'trait';
    final activation = switch (type) {
      'free' => FeatureActivation.bonus,
      'bonus' => FeatureActivation.bonus,
      'action' => FeatureActivation.action,
      'reaction' => FeatureActivation.reaction,
      _ => FeatureActivation.none,
    };
    final category = activation == FeatureActivation.none
        ? FeatureCategory.trait
        : FeatureCategory.attack;
    return MonsterFeature(
      name: json['name'] as String? ?? '',
      category: category,
      rarity: FeatureRarityApi.fromJson(json['rarity'] as String?),
      activationTime: activation,
      text: json['text'] as String? ?? '',
      textOverride: true,
      autoKey: json['autoKey'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.toJson(),
        'rarity': rarity.toJson(),
        'delivery': delivery.toJson(),
        'effectPoints': effectPoints,
        'activationTime': activationTime.toJson(),
        'hasRequirement': hasRequirement,
        'limitation': limitation.toJson(),
        'defence': defence?.toJson(),
        'range': range.toJson(),
        'targets': targets.toJson(),
        'deferral': deferral.toJson(),
        'effects': [for (final e in effects) e.toJson()],
        'text': text,
        'textOverride': textOverride,
        if (monstrousTraitId != null) 'monstrousTraitId': monstrousTraitId,
        if (budgetSlot != null) 'budgetSlot': budgetSlot!.name,
        if (autoKey != null) 'autoKey': autoKey,
      };

  MonsterFeature copyWith({
    String? id,
    String? name,
    FeatureCategory? category,
    FeatureRarity? rarity,
    FeatureDelivery? delivery,
    int? effectPoints,
    FeatureActivation? activationTime,
    bool? hasRequirement,
    FeatureLimitation? limitation,
    FeatureDefence? defence,
    bool clearDefence = false,
    FeatureRange? range,
    FeatureTargets? targets,
    FeatureDeferral? deferral,
    List<FeatureEffect>? effects,
    String? text,
    bool? textOverride,
    String? monstrousTraitId,
    FeatureBudgetSlot? budgetSlot,
    String? autoKey,
  }) {
    return MonsterFeature(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      rarity: rarity ?? this.rarity,
      delivery: delivery ?? this.delivery,
      effectPoints: effectPoints ?? this.effectPoints,
      activationTime: activationTime ?? this.activationTime,
      hasRequirement: hasRequirement ?? this.hasRequirement,
      limitation: limitation ?? this.limitation,
      defence: clearDefence ? null : (defence ?? this.defence),
      range: range ?? this.range,
      targets: targets ?? this.targets,
      deferral: deferral ?? this.deferral,
      effects: effects ?? this.effects,
      text: text ?? this.text,
      textOverride: textOverride ?? this.textOverride,
      monstrousTraitId: monstrousTraitId ?? this.monstrousTraitId,
      budgetSlot: budgetSlot ?? this.budgetSlot,
      autoKey: autoKey ?? this.autoKey,
    );
  }
}

/// Entry on a creature: catalog reference or embedded local/auto feature.
class CreatureFeatureEntry {
  const CreatureFeatureEntry.catalog({
    required this.catalogItemId,
    required this.snapshotName,
    this.snapshotText = '',
  })  : source = CreatureFeatureSource.catalog,
        feature = null;

  const CreatureFeatureEntry.local(this.feature)
      : source = CreatureFeatureSource.local,
        catalogItemId = null,
        snapshotName = null,
        snapshotText = null;

  final CreatureFeatureSource source;
  final int? catalogItemId;
  final String? snapshotName;
  final String? snapshotText;
  final MonsterFeature? feature;

  String get displayName =>
      feature?.name ?? snapshotName ?? 'Feature';

  String get displayText => feature?.text ?? snapshotText ?? '';

  bool get isAuto => feature?.autoKey != null;

  factory CreatureFeatureEntry.fromJson(Map<String, dynamic> json) {
    final source = json['source'] as String?;
    if (source == 'catalog' || json['catalogItemId'] != null) {
      return CreatureFeatureEntry.catalog(
        catalogItemId: (json['catalogItemId'] as num).toInt(),
        snapshotName: json['snapshotName'] as String? ?? '',
        snapshotText: json['snapshotText'] as String? ?? '',
      );
    }
    return CreatureFeatureEntry.local(MonsterFeature.fromJson(json));
  }

  Map<String, dynamic> toJson() {
    if (source == CreatureFeatureSource.catalog) {
      return {
        'source': 'catalog',
        'catalogItemId': catalogItemId,
        'snapshotName': snapshotName,
        'snapshotText': snapshotText,
      };
    }
    final f = feature!;
    return {
      'source': 'local',
      ...f.toJson(),
    };
  }
}

enum CreatureFeatureSource { catalog, local }
