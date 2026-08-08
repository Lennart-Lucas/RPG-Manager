import 'package:flutter/material.dart';

import '../../features/auth/data/auth_api.dart';
import '../../features/auth/state/auth_controller.dart';
import '../../features/catalog/data/catalog_api.dart';
import '../../features/catalog/data/catalog_kind.dart';
import '../../features/catalog/data/catalog_models.dart';
import '../../features/catalog/ui/catalog_record_detail_page.dart';
import '../../features/dm_tools/resources/data/resources_api.dart';
import '../../features/mechanics/conditions/ui/conditions_body.dart';
import '../../features/mechanics/damage_types/ui/damage_types_body.dart';
import '../../features/mechanics/features/data/feature_model.dart';
import '../../features/mechanics/features/ui/feature_detail_page.dart';
import '../../features/mechanics/item_properties/data/item_property_model.dart';
import '../../features/mechanics/item_properties/ui/item_property_detail_page.dart';
import '../../features/mechanics/rules/ui/rule_detail_page.dart';
import '../../features/mechanics/spell_tags/ui/spell_tag_detail_page.dart';
import '../../features/player_options/classes/ui/class_detail_page.dart';
import '../../features/player_options/classes/ui/subclass_detail_page.dart';
import '../../features/player_options/feats/data/feat_model.dart';
import '../../features/player_options/feats/ui/feat_detail_page.dart';
import '../../features/player_options/items/data/item_model.dart';
import '../../features/player_options/items/ui/item_detail_page.dart';
import '../../features/player_options/races/ui/race_detail_page.dart';
import '../../features/player_options/spells/data/spell_model.dart';
import '../../features/player_options/spells/ui/spell_detail_page.dart';
import '../../features/player_options/transformations/ui/transformation_detail_page.dart';
import '../../features/settings/generators/ui/generator_detail_page.dart';
import '../../features/world/campaigns/ui/campaign_detail_page.dart';
import '../../features/world/campaigns/ui/session_detail_page.dart';
import '../../features/world/characters/ui/character_detail_page.dart';
import '../../features/world/creature_types/data/creature_type_model.dart';
import '../../features/world/creature_types/ui/creature_type_detail_page.dart';
import '../../features/world/creatures/data/creature_model.dart';
import '../../features/world/creatures/ui/creature_detail_page.dart';
import '../../features/world/events/ui/event_detail_page.dart';
import '../../features/world/lore/ui/lore_detail_page.dart';
import '../../features/world/locations/ui/location_detail_page.dart';
import '../../features/world/organisations/ui/organisation_detail_page.dart';

/// Loads a catalog record by kind+id and shows the typed detail page.
class CatalogDetailLoaderPage extends StatefulWidget {
  const CatalogDetailLoaderPage({
    super.key,
    required this.auth,
    required this.kind,
    required this.itemId,
  });

  final AuthController auth;
  final CatalogKind kind;
  final int itemId;

  @override
  State<CatalogDetailLoaderPage> createState() =>
      _CatalogDetailLoaderPageState();
}

class _CatalogDetailLoaderPageState extends State<CatalogDetailLoaderPage> {
  late final Future<Widget> _future = _load();

  Future<Widget> _load() async {
    final api = CatalogApi();
    final token = await widget.auth.requireAccessToken();
    if (token == null) {
      throw AuthApiException('Not signed in');
    }
    final item = await api.get(token, widget.kind, widget.itemId);
    return buildCatalogDetailPage(
      auth: widget.auth,
      item: item,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          final message = snapshot.error is AuthApiException
              ? (snapshot.error! as AuthApiException).message
              : 'Could not open record';
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Back'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return snapshot.data!;
      },
    );
  }
}

/// Builds the detail page widget for an already-fetched [item].
Future<Widget> buildCatalogDetailPage({
  required AuthController auth,
  required CatalogItem item,
}) async {
  switch (item.kind) {
    case CatalogKind.spells:
      return _spellDetail(auth, item);
    case CatalogKind.items:
      return _itemDetail(auth, item);
    case CatalogKind.feats:
      return FeatDetailPage(
        auth: auth,
        item: item,
        entry: FeatRecord.fromCatalogPayload(
          name: item.name,
          payload: item.payload,
          id: FeatRecord.slugify(item.name),
        ).copyWith(name: item.name),
      );
    case CatalogKind.itemProperties:
      return ItemPropertyDetailPage(
        auth: auth,
        item: item,
        entry: ItemPropertyRecord.fromCatalogPayload(
          name: item.name,
          payload: item.payload,
          id: ItemPropertyRecord.slugify(item.name),
        ).copyWith(name: item.name),
      );
    case CatalogKind.classes:
      return ClassDetailPage(auth: auth, item: item);
    case CatalogKind.subclasses:
      return _subclassDetail(auth, item);
    case CatalogKind.rules:
      return _ruleDetail(auth, item);
    case CatalogKind.spellTags:
      return SpellTagDetailPage(auth: auth, item: item);
    case CatalogKind.conditions:
      return ConditionDetailPage(auth: auth, item: item);
    case CatalogKind.damageTypes:
      return DamageTypeDetailPage(auth: auth, item: item);
    case CatalogKind.races:
      return RaceDetailPage(auth: auth, item: item);
    case CatalogKind.transformations:
      return TransformationDetailPage(auth: auth, item: item);
    case CatalogKind.creatures:
      return _creatureDetail(auth, item);
    case CatalogKind.creatureTypes:
      return _creatureTypeDetail(auth, item);
    case CatalogKind.features:
      return _featureDetail(auth, item);
    case CatalogKind.generators:
      return GeneratorDetailPage(auth: auth, item: item);
    case CatalogKind.characters:
      return CharacterDetailPage(auth: auth, item: item);
    case CatalogKind.organisations:
      return OrganisationDetailPage(auth: auth, item: item);
    case CatalogKind.events:
      return EventDetailPage(auth: auth, item: item);
    case CatalogKind.lore:
      return LoreDetailPage(auth: auth, item: item);
    case CatalogKind.locations:
      return LocationDetailPage(auth: auth, item: item);
    case CatalogKind.campaigns:
      return CampaignDetailPage(auth: auth, item: item);
    case CatalogKind.sessions:
      return SessionDetailPage(auth: auth, item: item);
    default:
      return CatalogRecordDetailPage(auth: auth, item: item);
  }
}

Future<Widget> _spellDetail(AuthController auth, CatalogItem item) async {
  final spell = _spellFromItem(item);
  if (spell == null) {
    throw StateError('Could not read spell data');
  }

  final api = CatalogApi();
  final resourcesApi = ResourcesApi();
  final token = await auth.requireAccessToken();
  if (token == null) throw AuthApiException('Not signed in');

  final results = await Future.wait([
    api.list(token, CatalogKind.classes),
    api.list(token, CatalogKind.spellTags),
  ]);
  final classItems = results[0];
  final spellTags = results[1];

  final classNames = <String>[];
  for (final id in spell.classIds) {
    for (final c in classItems) {
      if (c.id == id) {
        final name = c.name.trim();
        classNames.add(name.isEmpty ? '$id' : name);
        break;
      }
    }
  }
  classNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final tags = <({int id, String name})>[];
  for (final id in spell.tagIds) {
    for (final t in spellTags) {
      if (t.id == id) {
        final name = t.name.trim();
        tags.add((id: id, name: name.isEmpty ? '$id' : name));
        break;
      }
    }
  }
  tags.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  String? sourceFileName;
  if (spell.sourceFileId != null) {
    try {
      final files = await resourcesApi.listFiles(token);
      for (final f in files) {
        if (f.id == spell.sourceFileId) {
          sourceFileName = f.name;
          break;
        }
      }
    } on AuthApiException {
      // Non-DM users cannot list resources.
    } catch (_) {}
  }

  return SpellDetailPage(
    auth: auth,
    item: item,
    spell: spell,
    classNames: classNames,
    tags: tags,
    sourceFileName: sourceFileName,
  );
}

Future<Widget> _itemDetail(AuthController auth, CatalogItem item) async {
  final entry = _itemFromCatalog(item);
  if (entry == null) {
    throw StateError('Could not read item data');
  }

  String? sourceFileName;
  var itemProperties = const <CatalogItem>[];
  final token = await auth.requireAccessToken();
  if (token != null) {
    if (entry.sourceFileId != null) {
      try {
        final files = await ResourcesApi().listFiles(token);
        for (final f in files) {
          if (f.id == entry.sourceFileId) {
            sourceFileName = f.name;
            break;
          }
        }
      } on AuthApiException {
        // Non-DM users cannot list resources.
      } catch (_) {}
    }
    try {
      itemProperties =
          await CatalogApi().list(token, CatalogKind.itemProperties);
    } catch (_) {}
  }

  return ItemDetailPage(
    auth: auth,
    item: item,
    entry: entry.copyWith(name: item.name),
    sourceFileName: sourceFileName,
    itemProperties: itemProperties,
  );
}

Future<Widget> _subclassDetail(AuthController auth, CatalogItem item) async {
  List<CatalogItem> parentClasses = const [];
  final token = await auth.requireAccessToken();
  if (token != null) {
    try {
      parentClasses = await CatalogApi().list(token, CatalogKind.classes);
    } catch (_) {}
  }
  return SubclassDetailPage(
    auth: auth,
    item: item,
    parentClasses: parentClasses,
  );
}

Future<Widget> _ruleDetail(AuthController auth, CatalogItem item) async {
  final api = CatalogApi();
  final token = await auth.requireAccessToken();
  var siblings = const <CatalogItem>[];
  if (token != null) {
    try {
      siblings = await api.list(token, CatalogKind.rules);
    } catch (_) {}
  }
  return RuleDetailPage(
    auth: auth,
    item: item,
    siblingRules: siblings,
  );
}

Future<Widget> _featureDetail(AuthController auth, CatalogItem item) async {
  MonsterFeature? feature;
  try {
    feature = MonsterFeature.fromCatalogPayload(
      name: item.name,
      payload: item.payload,
    );
  } catch (_) {
    feature = null;
  }
  if (feature == null) {
    throw StateError('Could not read feature data');
  }
  return FeatureDetailPage(
    auth: auth,
    item: item,
    feature: feature.copyWith(name: item.name),
  );
}

Future<Widget> _creatureTypeDetail(
  AuthController auth,
  CatalogItem item,
) async {
  final type = CreatureType.fromCatalogPayload(
    id: item.id,
    name: item.name,
    payload: item.payload,
  );
  final api = CatalogApi();
  final token = await auth.requireAccessToken();
  if (token == null) throw AuthApiException('Not signed in');

  Map<int, CreatureType> typesById = {item.id: type};
  try {
    final items = await api.list(token, CatalogKind.creatureTypes);
    typesById = {
      for (final catalogItem in items)
        catalogItem.id: CreatureType.fromCatalogPayload(
          id: catalogItem.id,
          name: catalogItem.name,
          payload: catalogItem.payload,
        ),
    };
  } catch (_) {}

  return CreatureTypeDetailPage(
    auth: auth,
    item: item,
    type: type.copyWith(name: item.name),
    typesById: typesById,
  );
}

Future<Widget> _creatureDetail(AuthController auth, CatalogItem item) async {
  Creature? creature;
  final payload = item.payload;
  if (payload == null) {
    creature = Creature(id: Creature.slugify(item.name), name: item.name);
  } else {
    try {
      final map = Map<String, dynamic>.from(payload);
      map.putIfAbsent('id', () => Creature.slugify(item.name));
      map.putIfAbsent('name', () => item.name);
      creature = Creature.fromJson(map);
    } catch (_) {
      creature = null;
    }
  }
  if (creature == null) {
    throw StateError('Could not read creature data');
  }
  return CreatureDetailPage(
    auth: auth,
    item: item,
    creature: creature.copyWith(name: item.name),
  );
}

Spell? _spellFromItem(CatalogItem item) {
  final payload = item.payload;
  if (payload == null) {
    return Spell(
      id: Spell.slugify(item.name),
      name: item.name,
      level: 0,
      school: SpellSchool.evocation,
      castingTime: const CastingTime.action(),
      range: const SpellRange.self(),
      components: const SpellComponents(
        verbal: false,
        somatic: false,
        material: false,
      ),
      duration: const SpellDuration.instantaneous(),
      classIds: const [],
      description: '',
    );
  }
  try {
    final map = Map<String, dynamic>.from(payload);
    map.putIfAbsent('id', () => Spell.slugify(item.name));
    map.putIfAbsent('name', () => item.name);
    return Spell.fromJson(map);
  } catch (_) {
    return null;
  }
}

Item? _itemFromCatalog(CatalogItem item) {
  final payload = item.payload;
  if (payload == null) {
    return Item(
      id: Item.slugify(item.name),
      name: item.name,
      description: '',
      itemType: ItemType.equipment,
      rarity: ItemRarity.common,
    );
  }
  try {
    final map = Map<String, dynamic>.from(payload);
    map.putIfAbsent('id', () => Item.slugify(item.name));
    map.putIfAbsent('name', () => item.name);
    return Item.fromJson(map);
  } catch (_) {
    return null;
  }
}
