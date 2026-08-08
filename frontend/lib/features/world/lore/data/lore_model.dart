class LoreRecord {
  const LoreRecord({
    required this.name,
    this.description = '',
  });

  final String name;
  final String description;

  factory LoreRecord.fromJson(Map<String, dynamic> json) {
    return LoreRecord(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  factory LoreRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return LoreRecord(name: name);
    }
    return LoreRecord(
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
        .replaceAll(RegExp(r'!?\[\[([^\]|/]+)/([^\]|]+)(?:\|([^\]]+))?\]\]'), '')
        .replaceAll(RegExp(r'[*_#>`]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plain.length <= 140) return plain;
    return '${plain.substring(0, 137)}…';
  }
}
