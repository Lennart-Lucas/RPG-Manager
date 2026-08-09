import '../../ui/overview_sections.dart';

enum MtgColor {
  white,
  blue,
  black,
  red,
  green;

  String get apiValue => switch (this) {
        MtgColor.white => 'W',
        MtgColor.blue => 'U',
        MtgColor.black => 'B',
        MtgColor.red => 'R',
        MtgColor.green => 'G',
      };

  String get label => apiValue;

  String get displayName => switch (this) {
        MtgColor.white => 'White',
        MtgColor.blue => 'Blue',
        MtgColor.black => 'Black',
        MtgColor.red => 'Red',
        MtgColor.green => 'Green',
      };

  int get colorArgb => switch (this) {
        MtgColor.white => 0xFFF8F6D8,
        MtgColor.blue => 0xFF0E68AB,
        MtgColor.black => 0xFF150B00,
        MtgColor.red => 0xFFD3202A,
        MtgColor.green => 0xFF00733E,
      };

  int get onColorArgb => switch (this) {
        MtgColor.white => 0xFF1A1A1A,
        MtgColor.blue => 0xFFFFFFFF,
        MtgColor.black => 0xFFE8E8E8,
        MtgColor.red => 0xFFFFFFFF,
        MtgColor.green => 0xFFFFFFFF,
      };

  static MtgColor? tryParse(String? value) {
    if (value == null) return null;
    final v = value.trim().toUpperCase();
    for (final c in MtgColor.values) {
      if (c.apiValue == v || c.name.toUpperCase() == v) return c;
    }
    return null;
  }
}

class CharacterRecord {
  const CharacterRecord({
    required this.name,
    this.raceId,
    this.mtgAlignment = const [],
    this.playerName = '',
    this.description = '',
    this.imageUrl = '',
    this.overviewSections = const [],
  });

  final String name;
  final int? raceId;
  final List<MtgColor> mtgAlignment;
  final String playerName;
  final String description;
  final String imageUrl;
  final List<OverviewSection> overviewSections;

  factory CharacterRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) return CharacterRecord(name: name);
    final rawAlign = payload['mtgAlignment'];
    final colors = <MtgColor>[];
    if (rawAlign is List) {
      for (final entry in rawAlign) {
        final parsed = MtgColor.tryParse(entry?.toString());
        if (parsed != null && !colors.contains(parsed)) colors.add(parsed);
      }
    }
    return CharacterRecord(
      name: payload['name'] as String? ?? name,
      raceId: (payload['raceId'] as num?)?.toInt(),
      mtgAlignment: colors,
      playerName: payload['playerName'] as String? ?? '',
      description: payload['description'] as String? ?? '',
      imageUrl: payload['imageUrl'] as String? ?? '',
      overviewSections: parseOverviewSections(payload['overviewSections']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'raceId': raceId,
        'mtgAlignment': [for (final c in mtgAlignment) c.apiValue],
        'playerName': playerName,
        'description': description,
        'imageUrl': imageUrl,
        'overviewSections': overviewSectionsToJson(overviewSections),
      };

  String get descriptionPreview =>
      description.replaceAll(RegExp(r'\s+'), ' ').trim();
}
