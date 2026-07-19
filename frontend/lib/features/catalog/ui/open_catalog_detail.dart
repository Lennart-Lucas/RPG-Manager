import 'package:flutter/material.dart';

import '../../auth/data/auth_api.dart';
import '../../auth/state/auth_controller.dart';
import '../../dm_tools/resources/data/resources_api.dart';
import '../../mechanics/features/data/feature_model.dart';
import '../../mechanics/features/ui/feature_detail_page.dart';
import '../../mechanics/spell_tags/data/spell_tag_model.dart';
import '../../player_options/classes/data/class_model.dart';
import '../../player_options/items/data/item_model.dart';
import '../../player_options/items/ui/item_detail_page.dart';
import '../../player_options/spells/data/spell_model.dart';
import '../../player_options/spells/ui/spell_detail_page.dart';
import '../../world/creature_types/data/creature_type_model.dart';
import '../../world/creature_types/ui/creature_type_detail_page.dart';
import '../../world/creatures/data/creature_model.dart';
import '../../world/creatures/ui/creature_detail_page.dart';
import '../data/catalog_api.dart';
import '../data/catalog_kind.dart';
import '../data/catalog_models.dart';
import 'catalog_record_detail_page.dart';

/// Opens the appropriate detail page for a catalog search hit.
Future<void> openCatalogRecordDetail({
  required BuildContext context,
  required AuthController auth,
  required String kindApiValue,
  required int itemId,
}) async {
  final kind = CatalogKind.tryParseApiValue(kindApiValue);
  if (kind == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unknown record type: $kindApiValue')),
      );
    }
    return;
  }

  final api = CatalogApi();
  final token = await auth.requireAccessToken();
  if (token == null || !context.mounted) return;

  try {
    final item = await api.get(token, kind, itemId);
    if (!context.mounted) return;

    switch (kind) {
      case CatalogKind.spells:
        await _openSpellDetail(context, auth, item);
      case CatalogKind.items:
        await _openItemDetail(context, auth, item);
      case CatalogKind.creatures:
        await _openCreatureDetail(context, auth, item);
      case CatalogKind.creatureTypes:
        await _openCreatureTypeDetail(context, auth, item);
      case CatalogKind.features:
        await _openFeatureDetail(context, auth, item);
      default:
        await Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (context) => CatalogRecordDetailPage(
              auth: auth,
              item: item,
            ),
          ),
        );
    }
  } on AuthApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open record')),
      );
    }
  }
}

Future<void> _openSpellDetail(
  BuildContext context,
  AuthController auth,
  CatalogItem item,
) async {
  final spell = _spellFromItem(item);
  if (spell == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not read spell data')),
    );
    return;
  }

  final api = CatalogApi();
  final resourcesApi = ResourcesApi();
  final token = await auth.requireAccessToken();
  if (token == null || !context.mounted) return;

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

  final tagNames = <String>[];
  for (final id in spell.tagIds) {
    for (final t in spellTags) {
      if (t.id == id) {
        final name = t.name.trim();
        tagNames.add(name.isEmpty ? '$id' : name);
        break;
      }
    }
  }
  tagNames.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

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

  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => SpellDetailPage(
        auth: auth,
        item: item,
        spell: spell,
        classNames: classNames,
        tagNames: tagNames,
        sourceFileName: sourceFileName,
      ),
    ),
  );
}

Future<void> _openItemDetail(
  BuildContext context,
  AuthController auth,
  CatalogItem item,
) async {
  final entry = _itemFromCatalog(item);
  if (entry == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not read item data')),
    );
    return;
  }

  String? sourceFileName;
  if (entry.sourceFileId != null) {
    final token = await auth.requireAccessToken();
    if (token != null) {
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
  }

  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => ItemDetailPage(
        auth: auth,
        item: item,
        entry: entry.copyWith(name: item.name),
        sourceFileName: sourceFileName,
      ),
    ),
  );
}

Future<void> _openFeatureDetail(
  BuildContext context,
  AuthController auth,
  CatalogItem item,
) async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not read feature data')),
    );
    return;
  }

  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => FeatureDetailPage(
        auth: auth,
        item: item,
        feature: feature!.copyWith(name: item.name),
      ),
    ),
  );
}

Future<void> _openCreatureTypeDetail(
  BuildContext context,
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
  if (token == null || !context.mounted) return;

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

  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => CreatureTypeDetailPage(
        auth: auth,
        item: item,
        type: type.copyWith(name: item.name),
        typesById: typesById,
      ),
    ),
  );
}

Future<void> _openCreatureDetail(
  BuildContext context,
  AuthController auth,
  CatalogItem item,
) async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not read creature data')),
    );
    return;
  }

  if (!context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (context) => CreatureDetailPage(
        auth: auth,
        item: item,
        creature: creature!.copyWith(name: item.name),
      ),
    ),
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

/// Used by [CatalogRecordDetailPage] for kind-specific summaries.
String? catalogRecordSubtitle(CatalogItem item) {
  switch (item.kind) {
    case CatalogKind.classes:
      final record = ClassRecord.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
      return record.isCaster ? 'Spellcaster' : 'Non-caster';
    case CatalogKind.spellTags:
      final tag = SpellTag.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
      final desc = tag.description.trim();
      if (desc.isEmpty) return null;
      final oneLine = desc.replaceAll(RegExp(r'\s+'), ' ');
      if (oneLine.length <= 120) return oneLine;
      return '${oneLine.substring(0, 117)}…';
    case CatalogKind.features:
      final feature = MonsterFeature.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
      final text = feature.text.trim();
      if (text.isEmpty) {
        return '${feature.category.label} · ${feature.rarity.label} · ${feature.effectPoints} EP';
      }
      final oneLine = text.replaceAll(RegExp(r'\s+'), ' ');
      if (oneLine.length <= 120) return oneLine;
      return '${oneLine.substring(0, 117)}…';
    default:
      return null;
  }
}
