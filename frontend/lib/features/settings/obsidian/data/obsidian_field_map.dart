import '../../../catalog/data/catalog_kind.dart';

/// System frontmatter keys (not part of catalog payload).
const obsidianSystemFrontmatterKeys = {
  'rpg_manager_id',
  'rpg_manager_kind',
  'name',
};

/// A top-level payload string field rendered as `## {title}`.
class ObsidianMarkdownField {
  const ObsidianMarkdownField(this.payloadKey, this.sectionTitle);

  final String payloadKey;
  final String sectionTitle;
}

/// Nested prose blocks exported under a parent `##` with `###` children.
enum ObsidianNestedProseKind {
  /// `featuresByLevel` map (classes / subclasses).
  featuresByLevel,

  /// Flat `features` list with `name` + `description` (transformations).
  namedFeatures,

  /// Creature-type `sections` (`title` + `contents`).
  typeSections,

  /// Creature-type `traits` (`name` + `description` [+ optional catalog id]).
  typeTraits,

  /// Creature `features` list (local text or catalog snapshotText).
  creatureFeatures,
}

/// Declares how a catalog kind maps to Obsidian body sections.
class ObsidianKindFieldMap {
  const ObsidianKindFieldMap({
    this.markdownFields = const [],
    this.nested = const [],
    this.spellHigherLevels = false,
  });

  final List<ObsidianMarkdownField> markdownFields;
  final List<ObsidianNestedProseKind> nested;

  /// Spells: extra `## At higher levels` ↔ `higherLevels.description`.
  final bool spellHigherLevels;

  Set<String> get markdownPayloadKeys => {
        for (final f in markdownFields) f.payloadKey,
      };

  /// Payload keys fully represented in the body (omit from frontmatter).
  Set<String> get bodyOwnedPayloadKeys {
    final keys = {...markdownPayloadKeys};
    for (final n in nested) {
      switch (n) {
        case ObsidianNestedProseKind.featuresByLevel:
          keys.add('featuresByLevel');
        case ObsidianNestedProseKind.namedFeatures:
        case ObsidianNestedProseKind.creatureFeatures:
          keys.add('features');
        case ObsidianNestedProseKind.typeSections:
          keys.add('sections');
        case ObsidianNestedProseKind.typeTraits:
          keys.add('traits');
      }
    }
    return keys;
  }
}

const _description = ObsidianMarkdownField('description', 'Description');

/// Stable section titles used on import (case-insensitive match).
abstract final class ObsidianSectionTitles {
  static const atHigherLevels = 'At higher levels';
  static const features = 'Features';
  static const sections = 'Sections';
  static const traits = 'Traits';
}

ObsidianKindFieldMap obsidianFieldMapFor(CatalogKind kind) {
  switch (kind) {
    case CatalogKind.organisations:
      return const ObsidianKindFieldMap(
        markdownFields: [
          _description,
          ObsidianMarkdownField('founding', 'Founding'),
          ObsidianMarkdownField('motto', 'Motto'),
          ObsidianMarkdownField('type', 'Type'),
        ],
      );
    case CatalogKind.locations:
      return const ObsidianKindFieldMap(
        markdownFields: [
          _description,
          ObsidianMarkdownField('history', 'History'),
          ObsidianMarkdownField('mapNotes', 'Map notes'),
        ],
      );
    case CatalogKind.feats:
      return const ObsidianKindFieldMap(
        markdownFields: [
          ObsidianMarkdownField('requirement', 'Requirement'),
          _description,
        ],
      );
    case CatalogKind.features:
      return const ObsidianKindFieldMap(
        markdownFields: [
          ObsidianMarkdownField('text', 'Text'),
        ],
      );
    case CatalogKind.creatures:
      return const ObsidianKindFieldMap(
        markdownFields: [
          ObsidianMarkdownField('trigger', 'Trigger'),
        ],
        nested: [ObsidianNestedProseKind.creatureFeatures],
      );
    case CatalogKind.rules:
      return const ObsidianKindFieldMap(
        markdownFields: [
          ObsidianMarkdownField('body', 'Body'),
        ],
      );
    case CatalogKind.spells:
      return const ObsidianKindFieldMap(
        markdownFields: [_description],
        spellHigherLevels: true,
      );
    case CatalogKind.classes:
    case CatalogKind.subclasses:
      return const ObsidianKindFieldMap(
        markdownFields: [_description],
        nested: [ObsidianNestedProseKind.featuresByLevel],
      );
    case CatalogKind.transformations:
      return const ObsidianKindFieldMap(
        markdownFields: [
          _description,
          ObsidianMarkdownField('prereqRoleplay', 'Roleplay prerequisite'),
        ],
        nested: [ObsidianNestedProseKind.namedFeatures],
      );
    case CatalogKind.creatureTypes:
      return const ObsidianKindFieldMap(
        markdownFields: [
          ObsidianMarkdownField('quote', 'Quote'),
        ],
        nested: [
          ObsidianNestedProseKind.typeSections,
          ObsidianNestedProseKind.typeTraits,
        ],
      );
    case CatalogKind.generators:
      return const ObsidianKindFieldMap();
    default:
      // characters, events, campaigns, sessions, items, races, skills,
      // languages, conditions, damage_types, item_properties, spell_tags, …
      return const ObsidianKindFieldMap(markdownFields: [_description]);
  }
}

String? markdownFieldKeyForTitle(ObsidianKindFieldMap map, String title) {
  final needle = title.trim().toLowerCase();
  for (final f in map.markdownFields) {
    if (f.sectionTitle.toLowerCase() == needle) return f.payloadKey;
  }
  if (map.spellHigherLevels &&
      needle == ObsidianSectionTitles.atHigherLevels.toLowerCase()) {
    return '__higherLevels.description__';
  }
  return null;
}
