enum CatalogKind {
  classes,
  subclasses,
  feats,
  languages,
  races,
  transformations,
  skills,
  spells,
  items,
  creatures,
  creatureTypes,
  conditions,
  damageTypes,
  itemProperties,
  rules,
  spellTags,
  features,
  locations,
  characters,
  organisations,
  events,
  lore,
  generators,
  campaigns,
  sessions;

  static CatalogKind? tryParseApiValue(String value) {
    for (final kind in CatalogKind.values) {
      if (kind.apiValue == value) return kind;
    }
    return null;
  }
}

extension CatalogKindApi on CatalogKind {
  String get apiValue => switch (this) {
        CatalogKind.classes => 'classes',
        CatalogKind.subclasses => 'subclasses',
        CatalogKind.feats => 'feats',
        CatalogKind.languages => 'languages',
        CatalogKind.races => 'races',
        CatalogKind.transformations => 'transformations',
        CatalogKind.skills => 'skills',
        CatalogKind.spells => 'spells',
        CatalogKind.items => 'items',
        CatalogKind.creatures => 'creatures',
        CatalogKind.creatureTypes => 'creature_types',
        CatalogKind.conditions => 'conditions',
        CatalogKind.damageTypes => 'damage_types',
        CatalogKind.itemProperties => 'item_properties',
        CatalogKind.rules => 'rules',
        CatalogKind.spellTags => 'spell_tags',
        CatalogKind.features => 'features',
        CatalogKind.locations => 'locations',
        CatalogKind.characters => 'characters',
        CatalogKind.organisations => 'organisations',
        CatalogKind.events => 'events',
        CatalogKind.lore => 'lore',
        CatalogKind.generators => 'generators',
        CatalogKind.campaigns => 'campaigns',
        CatalogKind.sessions => 'sessions',
      };

  String get singularLabel => switch (this) {
        CatalogKind.classes => 'class',
        CatalogKind.subclasses => 'subclass',
        CatalogKind.feats => 'feat',
        CatalogKind.languages => 'language',
        CatalogKind.races => 'race',
        CatalogKind.transformations => 'transformation',
        CatalogKind.skills => 'skill',
        CatalogKind.spells => 'spell',
        CatalogKind.items => 'item',
        CatalogKind.creatures => 'monster',
        CatalogKind.creatureTypes => 'monster type',
        CatalogKind.conditions => 'condition',
        CatalogKind.damageTypes => 'damage type',
        CatalogKind.itemProperties => 'item property',
        CatalogKind.rules => 'rule',
        CatalogKind.spellTags => 'spell tag',
        CatalogKind.features => 'feature',
        CatalogKind.locations => 'location',
        CatalogKind.characters => 'character',
        CatalogKind.organisations => 'organisation',
        CatalogKind.events => 'event',
        CatalogKind.lore => 'lore',
        CatalogKind.generators => 'generator',
        CatalogKind.campaigns => 'campaign',
        CatalogKind.sessions => 'session',
      };

  String get pluralLabel => switch (this) {
        CatalogKind.classes => 'classes',
        CatalogKind.subclasses => 'subclasses',
        CatalogKind.feats => 'feats',
        CatalogKind.languages => 'languages',
        CatalogKind.races => 'races',
        CatalogKind.transformations => 'transformations',
        CatalogKind.skills => 'skills',
        CatalogKind.spells => 'spells',
        CatalogKind.items => 'items',
        CatalogKind.creatures => 'creatures',
        CatalogKind.creatureTypes => 'monster types',
        CatalogKind.conditions => 'conditions',
        CatalogKind.damageTypes => 'damage types',
        CatalogKind.itemProperties => 'item properties',
        CatalogKind.rules => 'rules',
        CatalogKind.spellTags => 'spell tags',
        CatalogKind.features => 'features',
        CatalogKind.locations => 'locations',
        CatalogKind.characters => 'characters',
        CatalogKind.organisations => 'organisations',
        CatalogKind.events => 'events',
        CatalogKind.lore => 'lore',
        CatalogKind.generators => 'generators',
        CatalogKind.campaigns => 'campaigns',
        CatalogKind.sessions => 'sessions',
      };

  /// Title-cased singular label for UI (e.g. "Spell", "Damage type").
  String get displayLabel {
    final label = singularLabel;
    if (label.isEmpty) return label;
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }
}
