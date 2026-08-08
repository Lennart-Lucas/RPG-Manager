class EventRecord {
  const EventRecord({
    required this.name,
    this.description = '',
    this.yearStart,
    this.yearEnd,
  });

  final String name;
  final String description;

  /// Optional start year (AR). Alone = single-year event.
  final int? yearStart;

  /// Optional end year (AR). With [yearStart] = inclusive range.
  final int? yearEnd;

  factory EventRecord.fromJson(Map<String, dynamic> json) {
    return EventRecord(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      yearStart: _parseYear(json['yearStart']),
      yearEnd: _parseYear(json['yearEnd']),
    );
  }

  factory EventRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) {
      return EventRecord(name: name);
    }
    return EventRecord(
      name: payload['name'] as String? ?? name,
      description: payload['description'] as String? ?? '',
      yearStart: _parseYear(payload['yearStart']),
      yearEnd: _parseYear(payload['yearEnd']),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'yearStart': yearStart,
        'yearEnd': yearEnd,
      };

  /// Display label: `null`, `"1234 AR"`, or `"1234–1250 AR"`.
  String? get yearLabel {
    if (yearStart == null) return null;
    if (yearEnd == null || yearEnd == yearStart) {
      return '$yearStart AR';
    }
    return '$yearStart–$yearEnd AR';
  }

  /// Validates year fields. Returns an error message or `null` if ok.
  String? validateYears() {
    if (yearStart == null && yearEnd != null) {
      return 'Set a start year, or clear the end year';
    }
    if (yearStart != null && yearEnd != null && yearEnd! < yearStart!) {
      return 'End year must be on or after the start year';
    }
    return null;
  }

  String get descriptionPreview {
    final plain = description
        .replaceAll(RegExp(r'!?\[\[([^\]|/]+)/([^\]|]+)(?:\|([^\]]+))?\]\]'), '')
        .replaceAll(RegExp(r'[*_#>`]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (plain.length <= 140) return plain;
    return '${plain.substring(0, 137)}…';
  }

  static int? _parseYear(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final text = '$raw'.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }
}
