import 'package:flutter/material.dart';

enum ItemType {
  armor('armor', 'Armor'),
  shield('shield', 'Shield'),
  book('book', 'Book'),
  scroll('scroll', 'Scroll'),
  equipment('equipment', 'Equipment'),
  potion('potion', 'Potion'),
  ring('ring', 'Ring'),
  rod('rod', 'Rod'),
  stave('stave', 'Stave'),
  wand('wand', 'Wand'),
  tool('tool', 'Tool'),
  weapon('weapon', 'Weapon'),
  wondrousItem('wondrous_item', 'Wondrous Item');

  const ItemType(this.jsonValue, this.label);

  final String jsonValue;
  final String label;

  String toJson() => jsonValue;

  static ItemType fromJson(String value) {
    return ItemType.values.firstWhere(
      (itemType) => itemType.jsonValue == value,
      orElse: () => ItemType.equipment,
    );
  }
}

extension ItemTypeIcons on ItemType {
  IconData get listIcon => switch (this) {
        ItemType.armor => Icons.shield_outlined,
        ItemType.shield => Icons.shield_outlined,
        ItemType.book => Icons.menu_book_outlined,
        ItemType.scroll => Icons.description_outlined,
        ItemType.equipment => Icons.inventory_2_outlined,
        ItemType.potion => Icons.science_outlined,
        ItemType.ring => Icons.circle_outlined,
        ItemType.rod => Icons.view_column_outlined,
        ItemType.stave => Icons.auto_fix_high_outlined,
        ItemType.wand => Icons.nightlight_outlined,
        ItemType.tool => Icons.build_outlined,
        ItemType.weapon => Icons.gavel_outlined,
        ItemType.wondrousItem => Icons.auto_awesome_outlined,
      };
}

enum ItemRarity {
  common('common', 'Common'),
  uncommon('uncommon', 'Uncommon'),
  rare('rare', 'Rare'),
  veryRare('very_rare', 'Very Rare'),
  legendary('legendary', 'Legendary'),
  artifact('artifact', 'Artifact');

  const ItemRarity(this.jsonValue, this.label);

  final String jsonValue;
  final String label;

  String toJson() => jsonValue;

  static ItemRarity fromJson(String value) {
    final normalized = value == 'ledgendary' ? 'legendary' : value;
    return ItemRarity.values.firstWhere(
      (itemRarity) => itemRarity.jsonValue == normalized,
      orElse: () => ItemRarity.common,
    );
  }
}

class Item {
  final String id;
  final String name;
  final String description;
  final ItemType itemType;
  final ItemRarity rarity;
  final bool magic;
  final bool consumable;
  final bool requiresAttunement;
  final String typeReference;
  final int? sourceFileId;
  final int? sourcePage;

  const Item({
    required this.id,
    required this.name,
    required this.description,
    required this.itemType,
    required this.rarity,
    this.magic = false,
    this.consumable = false,
    this.requiresAttunement = false,
    this.typeReference = '',
    this.sourceFileId,
    this.sourcePage,
  });

  static String slugify(String name) {
    final slug = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'item' : slug;
  }

  factory Item.fromJson(Map<String, dynamic> json) {
    final magic = json['magic'] == true;
    return Item(
      id: json['id'] as String? ?? slugify(json['name'] as String? ?? ''),
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      itemType: ItemType.fromJson(json['itemType'] as String? ?? 'equipment'),
      rarity: ItemRarity.fromJson(json['rarity'] as String? ?? 'common'),
      magic: magic,
      consumable: json['consumable'] == true,
      requiresAttunement: magic && json['requiresAttunement'] == true,
      typeReference: json['typeReference'] as String? ?? '',
      sourceFileId: json['sourceFileId'] as int? ??
          (json['source_file_id'] as int?),
      sourcePage: json['sourcePage'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'itemType': itemType.toJson(),
        'rarity': rarity.toJson(),
        'magic': magic,
        'consumable': consumable,
        if (magic) 'requiresAttunement': requiresAttunement,
        'typeReference': typeReference,
        if (sourceFileId != null) 'sourceFileId': sourceFileId,
        if (sourcePage != null) 'sourcePage': sourcePage,
      };

  Item copyWith({
    String? id,
    String? name,
    String? description,
    ItemType? itemType,
    ItemRarity? rarity,
    bool? magic,
    bool? consumable,
    bool? requiresAttunement,
    String? typeReference,
    int? sourceFileId,
    int? sourcePage,
  }) {
    final nextMagic = magic ?? this.magic;
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      itemType: itemType ?? this.itemType,
      rarity: rarity ?? this.rarity,
      magic: nextMagic,
      consumable: consumable ?? this.consumable,
      requiresAttunement:
          nextMagic && (requiresAttunement ?? this.requiresAttunement),
      typeReference: typeReference ?? this.typeReference,
      sourceFileId: sourceFileId ?? this.sourceFileId,
      sourcePage: sourcePage ?? this.sourcePage,
    );
  }

  @override
  bool operator ==(Object other) => other is Item && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Item($name, ${itemType.label})';
}
