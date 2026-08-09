import '../../../world/characters/data/character_model.dart';

class RaceRecord {
  const RaceRecord({
    required this.name,
    required this.description,
    this.aliases = const [],
    this.mtgAlignment = const [],
    this.imageUrl = '',
  });

  final String name;
  final String description;
  final List<String> aliases;
  final List<MtgColor> mtgAlignment;
  final String imageUrl;

  factory RaceRecord.fromJson(Map<String, dynamic> json) {
    return RaceRecord.fromCatalogPayload(name: '', payload: json);
  }

  factory RaceRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return RaceRecord(name: name, description: '');
    }
    final rawAlign = payload['mtgAlignment'];
    final colors = <MtgColor>[];
    if (rawAlign is List) {
      for (final entry in rawAlign) {
        final parsed = MtgColor.tryParse(entry?.toString());
        if (parsed != null && !colors.contains(parsed)) colors.add(parsed);
      }
    }
    return RaceRecord(
      name: payload['name'] as String? ?? name,
      description: payload['description'] as String? ?? '',
      aliases: _parseAliases(payload['aliases']),
      mtgAlignment: colors,
      imageUrl: payload['imageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'aliases': aliases,
        'mtgAlignment': [for (final c in mtgAlignment) c.apiValue],
        'imageUrl': imageUrl,
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

  bool matchesNameOrAlias(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return false;
    if (name.trim().toLowerCase() == needle) return true;
    for (final alias in aliases) {
      if (alias.trim().toLowerCase() == needle) return true;
    }
    return false;
  }

  static List<String> _parseAliases(Object? raw) {
    if (raw is! List) return const [];
    final out = <String>[];
    final seen = <String>{};
    for (final entry in raw) {
      final text = '$entry'.trim();
      if (text.isEmpty) continue;
      final key = text.toLowerCase();
      if (!seen.add(key)) continue;
      out.add(text);
    }
    return out;
  }
}
