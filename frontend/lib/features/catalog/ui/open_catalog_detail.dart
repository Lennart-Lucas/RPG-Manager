import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_paths.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/state/auth_controller.dart';
import '../../mechanics/features/data/feature_model.dart';
import '../../mechanics/item_properties/data/item_property_model.dart';
import '../../mechanics/rules/data/rule_model.dart';
import '../../mechanics/spell_tags/data/spell_tag_model.dart';
import '../../player_options/classes/data/class_model.dart';
import '../../player_options/classes/data/subclass_model.dart';
import '../../player_options/feats/data/feat_model.dart';
import '../../player_options/skills/data/skill_model.dart';
import '../../settings/generators/data/generator_model.dart';
import '../data/catalog_kind.dart';
import '../data/catalog_models.dart';
import '../data/catalog_wiki_resolve.dart';

/// Opens the appropriate detail page for a catalog search hit via URL route.
Future<bool?> openCatalogRecordDetail({
  required BuildContext context,
  required AuthController auth,
  required String kindApiValue,
  required int itemId,
}) async {
  final kind = CatalogKind.tryParseApiValue(kindApiValue) ??
      CatalogKind.tryParseApiValue(kindApiValue.replaceAll('-', '_'));
  if (kind == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unknown record type: $kindApiValue')),
      );
    }
    return null;
  }

  if (!context.mounted) return null;
  return context.push<bool>(AppPaths.catalogDetail(kind, itemId));
}

/// Opens a catalog record by wiki kind + name (first search match).
Future<void> openCatalogWikiLink({
  required BuildContext context,
  required AuthController auth,
  required String kindApiValue,
  required String name,
}) async {
  final kind = CatalogKind.tryParseApiValue(kindApiValue) ??
      CatalogKind.tryParseApiValue(kindApiValue.replaceAll('-', '_'));
  if (kind == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unknown link type: $kindApiValue')),
      );
    }
    return;
  }

  try {
    final item = await resolveCatalogItemByWikiRef(
      auth: auth,
      kindApiValue: kindApiValue,
      name: name,
    );
    if (item == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No $kindApiValue named “$name”')),
        );
      }
      return;
    }
    if (!context.mounted) return;
    await openCatalogRecordDetail(
      context: context,
      auth: auth,
      kindApiValue: item.kind.apiValue,
      itemId: item.id,
    );
  } on AuthApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open linked record')),
      );
    }
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
      final parts = <String>[
        record.hitDie,
        if (record.isCaster) 'Spellcaster' else 'Non-caster',
        'Subclass at ${record.subclassChosenAtLevel}',
      ];
      return parts.join(' · ');
    case CatalogKind.subclasses:
      final record = SubclassRecord.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
      final featureCount = record.allFeatures.length;
      return featureCount == 0
          ? 'No features'
          : '$featureCount feature${featureCount == 1 ? '' : 's'}';
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
    case CatalogKind.skills:
      final skill = SkillRecord.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
      return skill.attribute;
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
    case CatalogKind.generators:
      final record = GeneratorRecord.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
      return 'Type: ${record.recordTypeLabel}';
    case CatalogKind.rules:
      final rule = RuleRecord.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
      final body = rule.body.trim();
      if (body.isEmpty) {
        return rule.parentRuleId != null ? 'Has parent rule' : null;
      }
      final oneLine = body.replaceAll(RegExp(r'\s+'), ' ');
      if (oneLine.length <= 120) return oneLine;
      return '${oneLine.substring(0, 117)}…';
    case CatalogKind.feats:
      final feat = FeatRecord.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
      final description = feat.description.trim();
      if (description.isEmpty) {
        final requirement = feat.requirement.trim();
        if (requirement.isEmpty) return null;
        final oneLine = requirement.replaceAll(RegExp(r'\s+'), ' ');
        if (oneLine.length <= 120) return oneLine;
        return '${oneLine.substring(0, 117)}…';
      }
      final oneLine = description.replaceAll(RegExp(r'\s+'), ' ');
      if (oneLine.length <= 120) return oneLine;
      return '${oneLine.substring(0, 117)}…';
    case CatalogKind.itemProperties:
      final property = ItemPropertyRecord.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
      final description = property.description.trim();
      if (description.isEmpty) return null;
      final oneLine = description.replaceAll(RegExp(r'\s+'), ' ');
      if (oneLine.length <= 120) return oneLine;
      return '${oneLine.substring(0, 117)}…';
    default:
      return null;
  }
}
