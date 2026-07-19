import '../../../../core/ui/multi_picklist_sheet.dart';
import 'item_model.dart';

List<PicklistOption> itemTypePicklistOptions() {
  final types = List<ItemType>.from(ItemType.values)
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return [
    for (final t in types) PicklistOption(id: t.jsonValue, label: t.label),
  ];
}

List<PicklistOption> rarityPicklistOptions() {
  final rarities = List<ItemRarity>.from(ItemRarity.values)
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return [
    for (final r in rarities) PicklistOption(id: r.jsonValue, label: r.label),
  ];
}

class ItemsListFilter {
  const ItemsListFilter({
    this.selectedItemTypeJson = const {},
    this.selectedRarityJson = const {},
    this.magicOnly = false,
    this.attunementOnly = false,
  });

  final Set<String> selectedItemTypeJson;
  final Set<String> selectedRarityJson;
  final bool magicOnly;
  final bool attunementOnly;

  static const ItemsListFilter empty = ItemsListFilter();

  bool get hasAny =>
      selectedItemTypeJson.isNotEmpty ||
      selectedRarityJson.isNotEmpty ||
      magicOnly ||
      attunementOnly;

  ItemsListFilter copyWith({
    Set<String>? selectedItemTypeJson,
    Set<String>? selectedRarityJson,
    bool? magicOnly,
    bool? attunementOnly,
  }) {
    return ItemsListFilter(
      selectedItemTypeJson:
          selectedItemTypeJson ?? this.selectedItemTypeJson,
      selectedRarityJson: selectedRarityJson ?? this.selectedRarityJson,
      magicOnly: magicOnly ?? this.magicOnly,
      attunementOnly: attunementOnly ?? this.attunementOnly,
    );
  }

  bool matchesItem(Item item) {
    if (selectedItemTypeJson.isNotEmpty) {
      if (!selectedItemTypeJson.contains(item.itemType.jsonValue)) {
        return false;
      }
    }
    if (selectedRarityJson.isNotEmpty) {
      if (!selectedRarityJson.contains(item.rarity.jsonValue)) {
        return false;
      }
    }
    if (magicOnly && !item.magic) return false;
    if (attunementOnly && !item.requiresAttunement) return false;
    return true;
  }
}

String itemListFilterSignature(ItemsListFilter filter) {
  String setSig(Set<String> values) {
    if (values.isEmpty) return '';
    final sorted = values.toList(growable: false)..sort();
    return sorted.join('|');
  }

  return [
    setSig(filter.selectedItemTypeJson),
    setSig(filter.selectedRarityJson),
    filter.magicOnly ? '1' : '0',
    filter.attunementOnly ? '1' : '0',
  ].join('::');
}
