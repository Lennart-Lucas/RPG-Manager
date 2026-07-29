enum AbilityAttribute {
  str,
  dex,
  con,
  intel,
  wis,
  cha;

  String get apiValue => switch (this) {
        AbilityAttribute.str => 'str',
        AbilityAttribute.dex => 'dex',
        AbilityAttribute.con => 'con',
        AbilityAttribute.intel => 'int',
        AbilityAttribute.wis => 'wis',
        AbilityAttribute.cha => 'cha',
      };

  String get label => switch (this) {
        AbilityAttribute.str => 'STR',
        AbilityAttribute.dex => 'DEX',
        AbilityAttribute.con => 'CON',
        AbilityAttribute.intel => 'INT',
        AbilityAttribute.wis => 'WIS',
        AbilityAttribute.cha => 'CHA',
      };

  static AbilityAttribute? tryParse(String? value) {
    if (value == null) return null;
    final v = value.trim().toLowerCase();
    for (final a in AbilityAttribute.values) {
      if (a.apiValue == v) return a;
    }
    return null;
  }
}

enum TransformationFeatureKind {
  boon,
  flaw;

  String get apiValue => name;

  String get label => switch (this) {
        TransformationFeatureKind.boon => 'Boon',
        TransformationFeatureKind.flaw => 'Flaw',
      };

  static TransformationFeatureKind parse(String? value) {
    if (value?.trim().toLowerCase() == 'flaw') {
      return TransformationFeatureKind.flaw;
    }
    return TransformationFeatureKind.boon;
  }
}

class TransformationPrereqAbility {
  const TransformationPrereqAbility({
    required this.attribute,
    required this.score,
  });

  final AbilityAttribute attribute;
  final int score;

  factory TransformationPrereqAbility.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TransformationPrereqAbility(
        attribute: AbilityAttribute.str,
        score: 13,
      );
    }
    return TransformationPrereqAbility(
      attribute:
          AbilityAttribute.tryParse(json['attribute'] as String?) ??
              AbilityAttribute.str,
      score: (json['score'] as num?)?.toInt() ?? 13,
    );
  }

  Map<String, dynamic> toJson() => {
        'attribute': attribute.apiValue,
        'score': score,
      };

  String get display => '${attribute.label} $score';
}

class TransformationFeature {
  const TransformationFeature({
    required this.name,
    this.kind = TransformationFeatureKind.boon,
    this.level = 1,
    this.description = '',
  });

  final String name;
  final TransformationFeatureKind kind;
  final int level;
  final String description;

  factory TransformationFeature.fromJson(Map<String, dynamic> json) {
    final level = (json['level'] as num?)?.toInt() ?? 1;
    return TransformationFeature(
      name: json['name'] as String? ?? '',
      kind: TransformationFeatureKind.parse(json['kind'] as String?),
      level: level.clamp(1, 4),
      description: json['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'kind': kind.apiValue,
        'level': level.clamp(1, 4),
        'description': description,
      };

  TransformationFeature copyWith({
    String? name,
    TransformationFeatureKind? kind,
    int? level,
    String? description,
  }) {
    return TransformationFeature(
      name: name ?? this.name,
      kind: kind ?? this.kind,
      level: level ?? this.level,
      description: description ?? this.description,
    );
  }
}

class TransformationRecord {
  const TransformationRecord({
    required this.name,
    this.prereqAbility = const TransformationPrereqAbility(
      attribute: AbilityAttribute.str,
      score: 13,
    ),
    this.prereqRoleplay = '',
    this.description = '',
    this.features = const [],
  });

  final String name;
  final TransformationPrereqAbility prereqAbility;
  final String prereqRoleplay;
  final String description;
  final List<TransformationFeature> features;

  factory TransformationRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return TransformationRecord(name: name);
    }
    final rawFeatures = payload['features'];
    final features = <TransformationFeature>[];
    if (rawFeatures is List) {
      for (final entry in rawFeatures) {
        if (entry is Map<String, dynamic>) {
          features.add(TransformationFeature.fromJson(entry));
        } else if (entry is Map) {
          features.add(
            TransformationFeature.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }
    final prereqRaw = payload['prereqAbility'];
    return TransformationRecord(
      name: payload['name'] as String? ?? name,
      prereqAbility: TransformationPrereqAbility.fromJson(
        prereqRaw is Map<String, dynamic>
            ? prereqRaw
            : prereqRaw is Map
                ? Map<String, dynamic>.from(prereqRaw)
                : null,
      ),
      prereqRoleplay: payload['prereqRoleplay'] as String? ?? '',
      description: payload['description'] as String? ?? '',
      features: features,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'prereqAbility': prereqAbility.toJson(),
        'prereqRoleplay': prereqRoleplay,
        'description': description,
        'features': [for (final f in features) f.toJson()],
      };

  String get descriptionPreview =>
      description.replaceAll(RegExp(r'\s+'), ' ').trim();

  List<TransformationFeature> featuresForLevel(int level) =>
      features.where((f) => f.level == level).toList();
}
