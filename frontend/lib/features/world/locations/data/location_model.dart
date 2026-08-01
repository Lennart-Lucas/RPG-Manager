enum LocationType {
  plane,
  continent,
  nation,
  region,
  settlement,
  city,
  village,
  tradingpost,
  district,
  site;

  String get apiValue => name;

  String get label => switch (this) {
        LocationType.plane => 'Plane',
        LocationType.continent => 'Continent',
        LocationType.nation => 'Nation',
        LocationType.region => 'Region',
        LocationType.settlement => 'Settlement',
        LocationType.city => 'City',
        LocationType.village => 'Village',
        LocationType.tradingpost => 'Trading post',
        LocationType.district => 'District',
        LocationType.site => 'Site',
      };

  /// Allowed parent types for this location type.
  /// Empty = must have no parent (planes). Non-empty = optional parent,
  /// constrained to these types when set.
  List<LocationType> get allowedParentTypes => switch (this) {
        LocationType.plane => const [],
        LocationType.continent => const [LocationType.plane],
        LocationType.nation => const [
          LocationType.plane,
          LocationType.continent,
        ],
        LocationType.region => const [
          LocationType.continent,
          LocationType.nation,
          LocationType.region,
        ],
        LocationType.settlement => const [
          LocationType.region,
          LocationType.nation,
        ],
        LocationType.city => const [
          LocationType.region,
          LocationType.nation,
        ],
        LocationType.village => const [
          LocationType.region,
          LocationType.nation,
        ],
        LocationType.tradingpost => const [
          LocationType.region,
          LocationType.nation,
        ],
        LocationType.district => const [
          LocationType.settlement,
          LocationType.city,
        ],
        LocationType.site => const [
          LocationType.settlement,
          LocationType.city,
          LocationType.village,
          LocationType.tradingpost,
          LocationType.district,
          LocationType.region,
        ],
      };

  static LocationType parse(String? value) {
    final v = value?.trim().toLowerCase();
    for (final t in LocationType.values) {
      if (t.apiValue == v) return t;
    }
    return LocationType.site;
  }
}

class LocationRecord {
  const LocationRecord({
    required this.name,
    this.type = LocationType.site,
    this.parentId,
    this.description = '',
    this.population = '',
    this.government = '',
    this.ruler = '',
    this.alignment = '',
    this.religions = '',
    this.languages = '',
    this.exports = '',
    this.imports = '',
    this.defenses = '',
    this.history = '',
    this.mapNotes = '',
  });

  final String name;
  final LocationType type;
  final int? parentId;
  final String description;
  final String population;
  final String government;
  final String ruler;
  final String alignment;
  final String religions;
  final String languages;
  final String exports;
  final String imports;
  final String defenses;
  final String history;
  final String mapNotes;

  factory LocationRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) return LocationRecord(name: name);
    return LocationRecord(
      name: payload['name'] as String? ?? name,
      type: LocationType.parse(payload['type'] as String?),
      parentId: (payload['parentId'] as num?)?.toInt(),
      description: payload['description'] as String? ?? '',
      population: payload['population'] as String? ?? '',
      government: payload['government'] as String? ?? '',
      ruler: payload['ruler'] as String? ?? '',
      alignment: payload['alignment'] as String? ?? '',
      religions: payload['religions'] as String? ?? '',
      languages: payload['languages'] as String? ?? '',
      exports: payload['exports'] as String? ?? '',
      imports: payload['imports'] as String? ?? '',
      defenses: payload['defenses'] as String? ?? '',
      history: payload['history'] as String? ?? '',
      mapNotes: payload['mapNotes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type.apiValue,
        'parentId': parentId,
        'description': description,
        'population': population,
        'government': government,
        'ruler': ruler,
        'alignment': alignment,
        'religions': religions,
        'languages': languages,
        'exports': exports,
        'imports': imports,
        'defenses': defenses,
        'history': history,
        'mapNotes': mapNotes,
      };

  String get descriptionPreview =>
      description.replaceAll(RegExp(r'\s+'), ' ').trim();

  String? validateParent(LocationRecord? parent) {
    final allowed = type.allowedParentTypes;
    if (allowed.isEmpty) {
      if (parentId != null) return 'Planes cannot have a parent';
      return null;
    }
    if (parentId == null) return null;
    if (parent == null) return 'Parent location not found';
    if (!allowed.contains(parent.type)) {
      return '${type.label} parent must be ${allowed.map((t) => t.label).join(' or ')}';
    }
    return null;
  }
}
