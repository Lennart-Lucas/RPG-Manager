class FeatRecord {
  const FeatRecord({
    required this.name,
    this.requirement = '',
    this.description = '',
  });

  final String name;
  final String requirement;
  final String description;

  factory FeatRecord.fromJson(Map<String, dynamic> json) {
    return FeatRecord(
      name: json['name'] as String? ?? '',
      requirement: json['requirement'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  factory FeatRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return FeatRecord(name: name);
    }
    return FeatRecord(
      name: payload['name'] as String? ?? name,
      requirement: payload['requirement'] as String? ?? '',
      description: payload['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'requirement': requirement,
        'description': description,
      };

  FeatRecord copyWith({
    String? name,
    String? requirement,
    String? description,
  }) {
    return FeatRecord(
      name: name ?? this.name,
      requirement: requirement ?? this.requirement,
      description: description ?? this.description,
    );
  }
}
