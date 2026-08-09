import '../../ui/overview_sections.dart';

class LoreRecord {
  const LoreRecord({
    required this.name,
    this.description = '',
    this.overviewSections = const [],
  });

  final String name;
  final String description;
  final List<OverviewSection> overviewSections;

  factory LoreRecord.fromJson(Map<String, dynamic> json) {
    return LoreRecord(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      overviewSections: parseOverviewSections(json['overviewSections']),
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
      overviewSections: parseOverviewSections(payload['overviewSections']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'overviewSections': overviewSectionsToJson(overviewSections),
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
