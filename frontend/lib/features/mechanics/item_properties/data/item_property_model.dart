class ItemPropertyRecord {
  const ItemPropertyRecord({
    required this.name,
    this.description = '',
  });

  final String name;
  final String description;

  factory ItemPropertyRecord.fromJson(Map<String, dynamic> json) {
    return ItemPropertyRecord(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  factory ItemPropertyRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return ItemPropertyRecord(name: name);
    }
    return ItemPropertyRecord(
      name: payload['name'] as String? ?? name,
      description: payload['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
      };

  ItemPropertyRecord copyWith({
    String? name,
    String? description,
  }) {
    return ItemPropertyRecord(
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }
}
