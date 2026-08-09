import '../../ui/overview_sections.dart';

class SessionRecord {
  const SessionRecord({
    required this.name,
    required this.campaignId,
    required this.dateTime,
    this.description = '',
    this.overviewSections = const [],
  });

  final String name;
  final int campaignId;

  /// ISO-8601 datetime string.
  final String dateTime;
  final String description;
  final List<OverviewSection> overviewSections;

  DateTime? get parsedDateTime => DateTime.tryParse(dateTime);

  factory SessionRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return SessionRecord(
        name: name,
        campaignId: 0,
        dateTime: '',
      );
    }
    return SessionRecord(
      name: payload['name'] as String? ?? name,
      campaignId: (payload['campaignId'] as num?)?.toInt() ?? 0,
      dateTime: payload['dateTime'] as String? ?? '',
      description: payload['description'] as String? ?? '',
      overviewSections: parseOverviewSections(payload['overviewSections']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'campaignId': campaignId,
        'dateTime': dateTime,
        'description': description,
        'overviewSections': overviewSectionsToJson(overviewSections),
      };

  SessionRecord copyWith({
    String? name,
    int? campaignId,
    String? dateTime,
    String? description,
    List<OverviewSection>? overviewSections,
  }) {
    return SessionRecord(
      name: name ?? this.name,
      campaignId: campaignId ?? this.campaignId,
      dateTime: dateTime ?? this.dateTime,
      description: description ?? this.description,
      overviewSections: overviewSections ?? this.overviewSections,
    );
  }

  static List<T> sortByDateTime<T>({
    required List<T> items,
    required String Function(T) dateTimeOf,
  }) {
    final copy = [...items];
    copy.sort((a, b) {
      final da = DateTime.tryParse(dateTimeOf(a));
      final db = DateTime.tryParse(dateTimeOf(b));
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return copy;
  }

  String get descriptionPreview =>
      description.replaceAll(RegExp(r'\s+'), ' ').trim();
}
