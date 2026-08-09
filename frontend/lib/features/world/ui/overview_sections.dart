/// Freeform Wikipedia-style overview rows grouped into named sections.
class OverviewItem {
  const OverviewItem({
    this.name = '',
    this.description = '',
  });

  final String name;
  final String description;

  OverviewItem copyWith({
    String? name,
    String? description,
  }) {
    return OverviewItem(
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
      };

  factory OverviewItem.fromJson(Map<String, dynamic> json) {
    return OverviewItem(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
    );
  }

  bool get isBlank => name.trim().isEmpty && description.trim().isEmpty;
}

class OverviewSection {
  const OverviewSection({
    this.name = '',
    this.items = const [],
  });

  final String name;
  final List<OverviewItem> items;

  OverviewSection copyWith({
    String? name,
    List<OverviewItem>? items,
  }) {
    return OverviewSection(
      name: name ?? this.name,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'items': [for (final item in items) item.toJson()],
      };

  factory OverviewSection.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = <OverviewItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map<String, dynamic>) {
          items.add(OverviewItem.fromJson(entry));
        } else if (entry is Map) {
          items.add(
            OverviewItem.fromJson(Map<String, dynamic>.from(entry)),
          );
        }
      }
    }
    return OverviewSection(
      name: json['name'] as String? ?? '',
      items: items,
    );
  }

  bool get isBlank =>
      name.trim().isEmpty && items.every((item) => item.isBlank);
}

/// Parses `payload['overviewSections']` into typed sections.
List<OverviewSection> parseOverviewSections(Object? raw) {
  if (raw is! List) return const [];
  final out = <OverviewSection>[];
  for (final entry in raw) {
    if (entry is Map<String, dynamic>) {
      out.add(OverviewSection.fromJson(entry));
    } else if (entry is Map) {
      out.add(OverviewSection.fromJson(Map<String, dynamic>.from(entry)));
    }
  }
  return out;
}

List<Map<String, dynamic>> overviewSectionsToJson(
  List<OverviewSection> sections,
) {
  return [
    for (final section in normalizeOverviewSections(sections)) section.toJson(),
  ];
}

/// Drops blank items/sections; keeps sections that still have content or a name
/// with at least one non-blank item.
List<OverviewSection> normalizeOverviewSections(
  List<OverviewSection> sections,
) {
  final out = <OverviewSection>[];
  for (final section in sections) {
    final items = [
      for (final item in section.items)
        if (!item.isBlank)
          OverviewItem(
            name: item.name.trim(),
            description: item.description.trim(),
          ),
    ];
    if (items.isEmpty) continue;
    out.add(
      OverviewSection(
        name: section.name.trim().isEmpty ? 'Details' : section.name.trim(),
        items: items,
      ),
    );
  }
  return out;
}

bool overviewSectionsNonEmpty(List<OverviewSection> sections) {
  return normalizeOverviewSections(sections).isNotEmpty;
}

/// Builds overview sections from legacy location string fields when
/// `overviewSections` is absent.
List<OverviewSection> migrateLocationLegacyOverview({
  required String population,
  required String government,
  required String ruler,
  required String alignment,
  required String religions,
  required String languages,
  required String exports,
  required String imports,
  required String defenses,
  required String history,
  required String mapNotes,
}) {
  final details = <OverviewItem>[
    for (final entry in [
      ('Population', population),
      ('Government', government),
      ('Ruler', ruler),
      ('Alignment', alignment),
      ('Religions', religions),
      ('Languages', languages),
      ('Exports', exports),
      ('Imports', imports),
      ('Defenses', defenses),
    ])
      if (entry.$2.trim().isNotEmpty)
        OverviewItem(name: entry.$1, description: entry.$2.trim()),
  ];
  final notes = <OverviewItem>[
    for (final entry in [
      ('History', history),
      ('Map notes', mapNotes),
    ])
      if (entry.$2.trim().isNotEmpty)
        OverviewItem(name: entry.$1, description: entry.$2.trim()),
  ];

  return [
    if (details.isNotEmpty) OverviewSection(name: 'Details', items: details),
    if (notes.isNotEmpty) OverviewSection(name: 'Notes', items: notes),
  ];
}
