class SpellTag {
  const SpellTag({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;

  factory SpellTag.fromJson(Map<String, dynamic> json) {
    return SpellTag(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  factory SpellTag.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return SpellTag(name: name, description: '');
    }
    return SpellTag(
      name: payload['name'] as String? ?? name,
      description: payload['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
      };
}
