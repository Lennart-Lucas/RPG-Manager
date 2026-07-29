class RaceRecord {
  const RaceRecord({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;

  factory RaceRecord.fromJson(Map<String, dynamic> json) {
    return RaceRecord(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  factory RaceRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return RaceRecord(name: name, description: '');
    }
    return RaceRecord(
      name: payload['name'] as String? ?? name,
      description: payload['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
      };

  String get descriptionPreview {
    final plain = description
        .replaceAll(RegExp(r'\[\[([^\]|/]+)/([^\]|]+)(?:\|([^\]]+))?\]\]'), '')
        .replaceAll(RegExp(r'[*_#>`]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plain.length <= 140) return plain;
    return '${plain.substring(0, 137)}…';
  }
}
