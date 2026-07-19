enum CatalogKind {
  classes,
  feats,
  languages,
  races,
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
  organisations;

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
        CatalogKind.feats => 'feats',
        CatalogKind.languages => 'languages',
        CatalogKind.races => 'races',
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
      };

  String get singularLabel => switch (this) {
        CatalogKind.classes => 'class',
        CatalogKind.feats => 'feat',
        CatalogKind.languages => 'language',
        CatalogKind.races => 'race',
        CatalogKind.skills => 'skill',
        CatalogKind.spells => 'spell',
        CatalogKind.items => 'item',
        CatalogKind.creatures => 'creature',
        CatalogKind.creatureTypes => 'creature type',
        CatalogKind.conditions => 'condition',
        CatalogKind.damageTypes => 'damage type',
        CatalogKind.itemProperties => 'item property',
        CatalogKind.rules => 'rule',
        CatalogKind.spellTags => 'spell tag',
        CatalogKind.features => 'feature',
        CatalogKind.locations => 'location',
        CatalogKind.characters => 'character',
        CatalogKind.organisations => 'organisation',
      };

  String get pluralLabel => switch (this) {
        CatalogKind.classes => 'classes',
        CatalogKind.feats => 'feats',
        CatalogKind.languages => 'languages',
        CatalogKind.races => 'races',
        CatalogKind.skills => 'skills',
        CatalogKind.spells => 'spells',
        CatalogKind.items => 'items',
        CatalogKind.creatures => 'creatures',
        CatalogKind.creatureTypes => 'creature types',
        CatalogKind.conditions => 'conditions',
        CatalogKind.damageTypes => 'damage types',
        CatalogKind.itemProperties => 'item properties',
        CatalogKind.rules => 'rules',
        CatalogKind.spellTags => 'spell tags',
        CatalogKind.features => 'features',
        CatalogKind.locations => 'locations',
        CatalogKind.characters => 'characters',
        CatalogKind.organisations => 'organisations',
      };

  /// Title-cased singular label for UI (e.g. "Spell", "Damage type").
  String get displayLabel {
    final label = singularLabel;
    if (label.isEmpty) return label;
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }
}
