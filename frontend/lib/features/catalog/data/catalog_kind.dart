enum CatalogKind {
  classes,
  feats,
  languages,
  races,
  skills,
  spells,
  items,
  creatures,
  conditions,
  damageTypes,
  itemProperties,
  rules,
  spellTags;

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
        CatalogKind.conditions => 'conditions',
        CatalogKind.damageTypes => 'damage_types',
        CatalogKind.itemProperties => 'item_properties',
        CatalogKind.rules => 'rules',
        CatalogKind.spellTags => 'spell_tags',
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
        CatalogKind.conditions => 'condition',
        CatalogKind.damageTypes => 'damage type',
        CatalogKind.itemProperties => 'item property',
        CatalogKind.rules => 'rule',
        CatalogKind.spellTags => 'spell tag',
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
        CatalogKind.conditions => 'conditions',
        CatalogKind.damageTypes => 'damage types',
        CatalogKind.itemProperties => 'item properties',
        CatalogKind.rules => 'rules',
        CatalogKind.spellTags => 'spell tags',
      };

  /// Title-cased singular label for UI (e.g. "Spell", "Damage type").
  String get displayLabel {
    final label = singularLabel;
    if (label.isEmpty) return label;
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }
}
