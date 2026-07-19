import 'package:rpg_manager/features/world/data/labeled_amount.dart';

class CreatureTypeSection {
  const CreatureTypeSection({required this.title, required this.contents});

  final String title;
  final String contents;

  factory CreatureTypeSection.fromJson(Map<String, dynamic> json) {
    return CreatureTypeSection(
      title: json['title'] as String? ?? '',
      contents: json['contents'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'title': title, 'contents': contents};
}

class CreatureTypeTrait {
  const CreatureTypeTrait({
    required this.name,
    required this.description,
    this.featureCatalogItemId,
  });

  final String name;
  final String description;
  final int? featureCatalogItemId;

  factory CreatureTypeTrait.fromJson(Map<String, dynamic> json) {
    final rawFeatureId = json['featureCatalogItemId'] ?? json['featureId'];
    int? featureCatalogItemId;
    if (rawFeatureId is num) {
      featureCatalogItemId = rawFeatureId.toInt();
    } else if (rawFeatureId is String && rawFeatureId.trim().isNotEmpty) {
      featureCatalogItemId = int.tryParse(rawFeatureId.trim());
    }
    return CreatureTypeTrait(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      featureCatalogItemId: featureCatalogItemId,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        if (featureCatalogItemId != null)
          'featureCatalogItemId': featureCatalogItemId,
      };
}

List<int> _intIdsFromJson(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e is num) e.toInt() else if (e is String) ...[
        if (int.tryParse(e.trim()) case final id?) id,
      ],
  ];
}

List<String> _stringListFromJson(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final e in raw)
      if (e != null) '$e'.trim(),
  ].where((s) => s.isNotEmpty).toList();
}

List<CreatureTypeTrait> _traitsFromJson(dynamic raw) {
  if (raw is! List) return const [];
  final out = <CreatureTypeTrait>[];
  for (final e in raw) {
    if (e is Map<String, dynamic>) {
      out.add(CreatureTypeTrait.fromJson(e));
    } else if (e is Map) {
      out.add(CreatureTypeTrait.fromJson(Map<String, dynamic>.from(e)));
    }
  }
  return out;
}

class CreatureType {
  const CreatureType({
    required this.id,
    required this.name,
    this.size,
    this.parentCreatureTypeId,
    this.quote = '',
    this.author = '',
    this.sections = const [],
    this.movement = const [],
    this.senses = const [],
    this.languageIds = const [],
    this.skillIds = const [],
    this.damageVulnerabilityIds = const [],
    this.damageResistanceIds = const [],
    this.damageImmunityIds = const [],
    this.conditionImmunityIds = const [],
    this.customLanguages = const [],
    this.customDamageVulnerabilities = const [],
    this.customDamageResistances = const [],
    this.customDamageImmunities = const [],
    this.traits = const [],
  });

  final int id;
  final String name;
  final String? size;
  final int? parentCreatureTypeId;
  final String quote;
  final String author;
  final List<CreatureTypeSection> sections;
  final List<LabeledAmount> movement;
  final List<LabeledAmount> senses;
  final List<int> languageIds;
  final List<int> skillIds;
  final List<int> damageVulnerabilityIds;
  final List<int> damageResistanceIds;
  final List<int> damageImmunityIds;
  final List<int> conditionImmunityIds;
  final List<String> customLanguages;
  final List<String> customDamageVulnerabilities;
  final List<String> customDamageResistances;
  final List<String> customDamageImmunities;
  final List<CreatureTypeTrait> traits;

  factory CreatureType.fromJson(Map<String, dynamic> json, {required int id}) {
    final sectionsRaw = json['sections'];
    final sections = <CreatureTypeSection>[];
    if (sectionsRaw is List) {
      for (final e in sectionsRaw) {
        if (e is Map<String, dynamic>) {
          sections.add(CreatureTypeSection.fromJson(e));
        } else if (e is Map) {
          sections.add(
            CreatureTypeSection.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return CreatureType(
      id: id,
      name: json['name'] as String? ?? '',
      size: json['size'] as String?,
      parentCreatureTypeId: (json['parentCreatureTypeId'] as num?)?.toInt(),
      quote: json['quote'] as String? ?? '',
      author: json['author'] as String? ?? '',
      sections: sections,
      movement: labeledAmountsFromJson(json['movement']),
      senses: labeledAmountsFromJson(json['senses']),
      languageIds: _intIdsFromJson(json['languageIds']),
      skillIds: _intIdsFromJson(json['skillIds']),
      damageVulnerabilityIds: _intIdsFromJson(json['damageVulnerabilityIds']),
      damageResistanceIds: _intIdsFromJson(json['damageResistanceIds']),
      damageImmunityIds: _intIdsFromJson(json['damageImmunityIds']),
      conditionImmunityIds: _intIdsFromJson(json['conditionImmunityIds']),
      customLanguages: _stringListFromJson(json['customLanguages']),
      customDamageVulnerabilities:
          _stringListFromJson(json['customDamageVulnerabilities']),
      customDamageResistances:
          _stringListFromJson(json['customDamageResistances']),
      customDamageImmunities:
          _stringListFromJson(json['customDamageImmunities']),
      traits: _traitsFromJson(json['traits']),
    );
  }

  factory CreatureType.fromCatalogPayload({
    required int id,
    required String name,
    Map<String, dynamic>? payload,
  }) {
    final map = Map<String, dynamic>.from(payload ?? const {});
    map.putIfAbsent('name', () => name);
    return CreatureType.fromJson(map, id: id);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (size != null) 'size': size,
        if (parentCreatureTypeId != null)
          'parentCreatureTypeId': parentCreatureTypeId,
        if (quote.isNotEmpty) 'quote': quote,
        if (author.isNotEmpty) 'author': author,
        if (sections.isNotEmpty)
          'sections': [for (final s in sections) s.toJson()],
        if (movement.isNotEmpty)
          'movement': labeledAmountsToJson(movement),
        if (senses.isNotEmpty) 'senses': labeledAmountsToJson(senses),
        if (languageIds.isNotEmpty) 'languageIds': languageIds,
        if (skillIds.isNotEmpty) 'skillIds': skillIds,
        if (damageVulnerabilityIds.isNotEmpty)
          'damageVulnerabilityIds': damageVulnerabilityIds,
        if (damageResistanceIds.isNotEmpty)
          'damageResistanceIds': damageResistanceIds,
        if (damageImmunityIds.isNotEmpty)
          'damageImmunityIds': damageImmunityIds,
        if (conditionImmunityIds.isNotEmpty)
          'conditionImmunityIds': conditionImmunityIds,
        if (customLanguages.isNotEmpty) 'customLanguages': customLanguages,
        if (customDamageVulnerabilities.isNotEmpty)
          'customDamageVulnerabilities': customDamageVulnerabilities,
        if (customDamageResistances.isNotEmpty)
          'customDamageResistances': customDamageResistances,
        if (customDamageImmunities.isNotEmpty)
          'customDamageImmunities': customDamageImmunities,
        if (traits.isNotEmpty)
          'traits': [for (final t in traits) t.toJson()],
      };

  CreatureType copyWith({
    int? id,
    String? name,
    String? size,
    bool clearSize = false,
    int? parentCreatureTypeId,
    bool clearParentCreatureTypeId = false,
    String? quote,
    String? author,
    List<CreatureTypeSection>? sections,
    List<LabeledAmount>? movement,
    List<LabeledAmount>? senses,
    List<int>? languageIds,
    List<int>? skillIds,
    List<int>? damageVulnerabilityIds,
    List<int>? damageResistanceIds,
    List<int>? damageImmunityIds,
    List<int>? conditionImmunityIds,
    List<String>? customLanguages,
    List<String>? customDamageVulnerabilities,
    List<String>? customDamageResistances,
    List<String>? customDamageImmunities,
    List<CreatureTypeTrait>? traits,
  }) {
    return CreatureType(
      id: id ?? this.id,
      name: name ?? this.name,
      size: clearSize ? null : (size ?? this.size),
      parentCreatureTypeId: clearParentCreatureTypeId
          ? null
          : (parentCreatureTypeId ?? this.parentCreatureTypeId),
      quote: quote ?? this.quote,
      author: author ?? this.author,
      sections: sections ?? this.sections,
      movement: movement ?? this.movement,
      senses: senses ?? this.senses,
      languageIds: languageIds ?? this.languageIds,
      skillIds: skillIds ?? this.skillIds,
      damageVulnerabilityIds:
          damageVulnerabilityIds ?? this.damageVulnerabilityIds,
      damageResistanceIds: damageResistanceIds ?? this.damageResistanceIds,
      damageImmunityIds: damageImmunityIds ?? this.damageImmunityIds,
      conditionImmunityIds: conditionImmunityIds ?? this.conditionImmunityIds,
      customLanguages: customLanguages ?? this.customLanguages,
      customDamageVulnerabilities:
          customDamageVulnerabilities ?? this.customDamageVulnerabilities,
      customDamageResistances:
          customDamageResistances ?? this.customDamageResistances,
      customDamageImmunities:
          customDamageImmunities ?? this.customDamageImmunities,
      traits: traits ?? this.traits,
    );
  }
}

List<CreatureType> creatureTypeRoots(List<CreatureType> all) {
  final roots = all.where((t) => t.parentCreatureTypeId == null).toList();
  roots.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return roots;
}

Map<int, List<CreatureType>> creatureTypesByParentId(List<CreatureType> all) {
  final map = <int, List<CreatureType>>{};
  for (final type in all) {
    final parentId = type.parentCreatureTypeId;
    if (parentId == null) continue;
    map.putIfAbsent(parentId, () => []).add(type);
  }
  for (final children in map.values) {
    children.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }
  return map;
}

List<({CreatureType record, int depth})> creatureTypeOutlineRows(
  List<CreatureType> roots,
  Map<int, List<CreatureType>> childrenByParentId,
) {
  final out = <({CreatureType record, int depth})>[];
  void walk(CreatureType node, int depth) {
    out.add((record: node, depth: depth));
    for (final child in childrenByParentId[node.id] ?? const []) {
      walk(child, depth + 1);
    }
  }

  for (final root in roots) {
    walk(root, 0);
  }
  return out;
}

Set<int> excludedCreatureTypeParentIds({
  required int? editingId,
  required List<CreatureType> allTypes,
}) {
  if (editingId == null) return const {};
  final excluded = <int>{editingId};
  final byParent = creatureTypesByParentId(allTypes);
  void walk(int id) {
    for (final child in byParent[id] ?? const []) {
      if (excluded.add(child.id)) walk(child.id);
    }
  }

  walk(editingId);
  return excluded;
}

List<CreatureType> creatureTypeAncestry({
  required CreatureType type,
  required Map<int, CreatureType> byId,
}) {
  final chain = <CreatureType>[type];
  var current = type;
  while (current.parentCreatureTypeId != null) {
    final parent = byId[current.parentCreatureTypeId!];
    if (parent == null) break;
    chain.add(parent);
    current = parent;
  }
  return chain;
}
