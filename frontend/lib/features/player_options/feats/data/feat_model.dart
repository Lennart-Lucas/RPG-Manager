class FeatRecord {
  const FeatRecord({
    required this.id,
    required this.name,
    this.requirement = '',
    this.description = '',
  });

  final String id;
  final String name;
  final String requirement;
  final String description;

  static String slugify(String name) {
    final slug = name
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'feat' : slug;
  }

  factory FeatRecord.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    return FeatRecord(
      id: json['id'] as String? ?? slugify(name),
      name: name,
      requirement: json['requirement'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  factory FeatRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
    String? id,
  }) {
    if (payload == null) {
      return FeatRecord(id: id ?? slugify(name), name: name);
    }
    final resolvedName = payload['name'] as String? ?? name;
    return FeatRecord(
      id: payload['id'] as String? ?? id ?? slugify(resolvedName),
      name: resolvedName,
      requirement: payload['requirement'] as String? ?? '',
      description: payload['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'requirement': requirement,
        'description': description,
      };

  FeatRecord copyWith({
    String? id,
    String? name,
    String? requirement,
    String? description,
  }) {
    return FeatRecord(
      id: id ?? this.id,
      name: name ?? this.name,
      requirement: requirement ?? this.requirement,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) => other is FeatRecord && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
