class ItemPropertyRecord {
  const ItemPropertyRecord({
    required this.id,
    required this.name,
    this.description = '',
  });

  final String id;
  final String name;
  final String description;

  static String slugify(String name) {
    final slug = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'item-property' : slug;
  }

  factory ItemPropertyRecord.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    return ItemPropertyRecord(
      id: json['id'] as String? ?? slugify(name),
      name: name,
      description: json['description'] as String? ?? '',
    );
  }

  factory ItemPropertyRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
    String? id,
  }) {
    if (payload == null) {
      return ItemPropertyRecord(id: id ?? slugify(name), name: name);
    }
    final resolvedName = payload['name'] as String? ?? name;
    return ItemPropertyRecord(
      id: payload['id'] as String? ?? id ?? slugify(resolvedName),
      name: resolvedName,
      description: payload['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
      };

  ItemPropertyRecord copyWith({
    String? id,
    String? name,
    String? description,
  }) {
    return ItemPropertyRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ItemPropertyRecord && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
