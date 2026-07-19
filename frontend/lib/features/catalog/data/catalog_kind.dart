enum CatalogKind {
  classes,
  feats,
  languages,
  races,
  skills,
  spells,
  conditions,
  damageTypes,
  itemProperties,
  rules,
}

extension CatalogKindApi on CatalogKind {
  String get apiValue => switch (this) {
        CatalogKind.classes => 'classes',
        CatalogKind.feats => 'feats',
        CatalogKind.languages => 'languages',
        CatalogKind.races => 'races',
        CatalogKind.skills => 'skills',
        CatalogKind.spells => 'spells',
        CatalogKind.conditions => 'conditions',
        CatalogKind.damageTypes => 'damage_types',
        CatalogKind.itemProperties => 'item_properties',
        CatalogKind.rules => 'rules',
      };

  String get singularLabel => switch (this) {
        CatalogKind.classes => 'class',
        CatalogKind.feats => 'feat',
        CatalogKind.languages => 'language',
        CatalogKind.races => 'race',
        CatalogKind.skills => 'skill',
        CatalogKind.spells => 'spell',
        CatalogKind.conditions => 'condition',
        CatalogKind.damageTypes => 'damage type',
        CatalogKind.itemProperties => 'item property',
        CatalogKind.rules => 'rule',
      };

  String get pluralLabel => switch (this) {
        CatalogKind.classes => 'classes',
        CatalogKind.feats => 'feats',
        CatalogKind.languages => 'languages',
        CatalogKind.races => 'races',
        CatalogKind.skills => 'skills',
        CatalogKind.spells => 'spells',
        CatalogKind.conditions => 'conditions',
        CatalogKind.damageTypes => 'damage types',
        CatalogKind.itemProperties => 'item properties',
        CatalogKind.rules => 'rules',
      };
}
