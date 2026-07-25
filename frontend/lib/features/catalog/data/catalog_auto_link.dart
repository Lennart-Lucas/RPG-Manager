import '../../../core/markdown/wiki_link.dart';
import '../../../core/ui/markdown_form_field.dart';
import '../../player_options/items/data/item_model.dart';
import '../../player_options/spells/data/spell_model.dart';
import 'catalog_api.dart';
import 'catalog_kind.dart';
import 'catalog_models.dart';

/// Result of applying wiki auto-link to a record's markdown fields.
class AutoLinkApplyResult<T> {
  const AutoLinkApplyResult({
    required this.value,
    required this.changed,
  });

  final T value;
  final bool changed;
}

List<CatalogLinkTarget> catalogItemsToAutoLinkTargets(
  Iterable<CatalogItem> items,
) {
  return [
    for (final item in items)
      CatalogLinkTarget(
        id: item.id,
        kind: item.kind.apiValue,
        name: item.name,
      ),
  ];
}

Iterable<({String kind, String name})> autoLinkTargetPairs(
  Iterable<CatalogLinkTarget> targets,
) {
  return targets.map((t) => (kind: t.kind, name: t.name));
}

/// Loads condition + damage-type targets used by the markdown auto-link toolbar.
Future<List<CatalogLinkTarget>> loadConditionDamageAutoLinkTargets(
  CatalogApi api,
  String accessToken,
) async {
  final results = await Future.wait([
    api.list(accessToken, CatalogKind.conditions),
    api.list(accessToken, CatalogKind.damageTypes),
  ]);
  return [
    ...catalogItemsToAutoLinkTargets(results[0]),
    ...catalogItemsToAutoLinkTargets(results[1]),
  ];
}

/// Catalog search for `[[` autocomplete (optional kind/ prefix filter).
Future<List<CatalogLinkTarget>> searchCatalogLinkTargets(
  CatalogApi api,
  String accessToken,
  String query,
) async {
  var nameQuery = query;
  String? kindPrefix;
  final slash = query.lastIndexOf('/');
  if (slash >= 0) {
    kindPrefix = query.substring(0, slash).trim().toLowerCase();
    nameQuery = query.substring(slash + 1);
  }
  try {
    final results = await api.search(accessToken, query: nameQuery);
    if (kindPrefix == null || kindPrefix.isEmpty) return results;
    return results
        .where((item) => item.kind.toLowerCase().startsWith(kindPrefix!))
        .toList();
  } catch (_) {
    return const [];
  }
}

AutoLinkApplyResult<Spell> autoLinkSpellFields(
  Spell spell,
  Iterable<CatalogLinkTarget> targets,
) {
  final pairs = autoLinkTargetPairs(targets);
  final description = autoLinkCatalogNames(spell.description, targets: pairs);
  final higherRaw = spell.higherLevels?.description;
  final higherLinked = higherRaw == null
      ? null
      : autoLinkCatalogNames(higherRaw, targets: pairs);

  final changed = description != spell.description ||
      higherLinked != higherRaw;
  if (!changed) {
    return AutoLinkApplyResult(value: spell, changed: false);
  }

  SpellScaling? higherLevels = spell.higherLevels;
  if (higherLevels != null && higherLinked != null) {
    higherLevels = SpellScaling(
      description: higherLinked,
      damageDiceIncrement: higherLevels.damageDiceIncrement,
      cantripLevelBreakpoints: higherLevels.cantripLevelBreakpoints,
    );
  } else if (higherLinked != null && higherLinked.trim().isNotEmpty) {
    higherLevels = SpellScaling(description: higherLinked);
  }

  return AutoLinkApplyResult(
    value: spell.copyWith(
      description: description,
      higherLevels: higherLevels,
    ),
    changed: true,
  );
}

AutoLinkApplyResult<Item> autoLinkItemFields(
  Item item,
  Iterable<CatalogLinkTarget> targets,
) {
  final description = autoLinkCatalogNames(
    item.description,
    targets: autoLinkTargetPairs(targets),
  );
  if (description == item.description) {
    return AutoLinkApplyResult(value: item, changed: false);
  }
  return AutoLinkApplyResult(
    value: item.copyWith(description: description),
    changed: true,
  );
}
