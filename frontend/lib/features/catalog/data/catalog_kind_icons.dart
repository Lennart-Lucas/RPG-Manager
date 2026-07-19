import 'package:flutter/material.dart';

import '../../mechanics/mechanics_icons.dart';
import '../../player_options/player_options_icons.dart';
import '../../world/world_icons.dart';
import 'catalog_kind.dart';

extension CatalogKindIcons on CatalogKind {
  IconData get pageIcon => switch (this) {
        CatalogKind.classes => classesPageIcon,
        CatalogKind.feats => featsPageIcon,
        CatalogKind.languages => languagesPageIcon,
        CatalogKind.races => racesPageIcon,
        CatalogKind.skills => skillsPageIcon,
        CatalogKind.spells => spellsPageIcon,
        CatalogKind.items => itemsPageIcon,
        CatalogKind.creatures => creaturesPageIcon,
        CatalogKind.creatureTypes => creatureTypesPageIcon,
        CatalogKind.conditions => conditionsPageIcon,
        CatalogKind.damageTypes => damageTypesPageIcon,
        CatalogKind.itemProperties => itemPropertiesPageIcon,
        CatalogKind.rules => rulesPageIcon,
        CatalogKind.spellTags => spellTagsPageIcon,
        CatalogKind.features => featuresPageIcon,
        CatalogKind.locations => atlasPageIcon,
        CatalogKind.characters => charactersPageIcon,
        CatalogKind.organisations => organisationsPageIcon,
      };
}
