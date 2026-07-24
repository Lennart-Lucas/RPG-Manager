import '../../../player_options/items/data/item_model.dart';
import 'extract_models.dart';

/// Build an [Item] from an extract draft for review / commit.
Item itemFromExtractDraft({
  required ExtractDraft draft,
  int? sourceFileId,
}) {
  final fromEdited = _tryItemFromEditedPayload(
    draft.payload,
    sourceFileId: sourceFileId,
  );
  if (fromEdited != null) return fromEdited;

  final payload = draft.payload;
  final rawName = payload['name'];
  final name = rawName is String && rawName.trim().isNotEmpty
      ? rawName.trim()
      : draft.displayName;

  var description = payload['description'] is String
      ? (payload['description'] as String)
      : '';
  if (description.trim().isEmpty &&
      draft.notes != null &&
      draft.notes!.trim().isNotEmpty) {
    description = draft.notes!.trim();
  }

  final itemType = ItemType.fromJson(
    payload['itemType'] is String
        ? payload['itemType'] as String
        : 'equipment',
  );
  final rarity = ItemRarity.fromJson(
    payload['rarity'] is String ? payload['rarity'] as String : 'common',
  );

  final magic = payload['magic'] == true ||
      itemType == ItemType.wondrousItem ||
      itemType == ItemType.potion ||
      itemType == ItemType.ring ||
      itemType == ItemType.rod ||
      itemType == ItemType.stave ||
      itemType == ItemType.wand ||
      itemType == ItemType.scroll;

  final consumable = payload['consumable'] == true ||
      itemType == ItemType.potion ||
      itemType == ItemType.scroll;

  final requiresAttunement =
      magic && payload['requiresAttunement'] == true;

  final typeReference = payload['typeReference'] is String
      ? (payload['typeReference'] as String).trim()
      : '';

  final sourcePage = draft.source.page ??
      (payload['sourcePage'] is num
          ? (payload['sourcePage'] as num).toInt()
          : null);

  return Item(
    id: Item.slugify(name),
    name: name,
    description: description,
    itemType: itemType,
    rarity: rarity,
    magic: magic,
    consumable: consumable,
    requiresAttunement: requiresAttunement,
    typeReference: typeReference,
    sourceFileId: sourceFileId,
    sourcePage: sourcePage,
  );
}

/// Payload written by Edit ([Item.toJson]) — distinguished by `id` + `itemType`.
Item? _tryItemFromEditedPayload(
  Map<String, dynamic> payload, {
  int? sourceFileId,
}) {
  if (!payload.containsKey('itemType') || !payload.containsKey('rarity')) {
    return null;
  }
  // Edited payloads always include `id` from Item.toJson().
  if (payload['id'] is! String) return null;

  try {
    final map = Map<String, dynamic>.from(payload);
    final item = Item.fromJson(map);
    return item.copyWith(
      sourceFileId: sourceFileId ?? item.sourceFileId,
    );
  } catch (_) {
    return null;
  }
}
