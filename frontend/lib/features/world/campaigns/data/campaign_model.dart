/// Legacy embedded session shape kept for one-time migration into catalog
/// [SessionRecord]s.
class LegacyCampaignSession {
  const LegacyCampaignSession({
    required this.dateTime,
    this.title = '',
  });

  /// ISO-8601 datetime string.
  final String dateTime;
  final String title;

  factory LegacyCampaignSession.fromJson(Map<String, dynamic> json) {
    return LegacyCampaignSession(
      dateTime: json['dateTime'] as String? ?? '',
      title: json['title'] as String? ?? '',
    );
  }

  DateTime? get parsedDateTime => DateTime.tryParse(dateTime);
}

class CampaignRecord {
  const CampaignRecord({
    required this.name,
    this.description = '',
    this.playerCharacterIds = const [],
    this.houseRuleIds = const [],
    this.legacySessions = const [],
  });

  final String name;
  final String description;
  final List<int> playerCharacterIds;
  final List<int> houseRuleIds;

  /// Sessions formerly embedded in the campaign payload. Migrated once into
  /// catalog `sessions` records, then cleared.
  final List<LegacyCampaignSession> legacySessions;

  factory CampaignRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) return CampaignRecord(name: name);
    final players = <int>[];
    final rawPlayers = payload['playerCharacterIds'];
    if (rawPlayers is List) {
      for (final e in rawPlayers) {
        final id = (e as num?)?.toInt();
        if (id != null) players.add(id);
      }
    }
    final rules = <int>[];
    final rawRules = payload['houseRuleIds'];
    if (rawRules is List) {
      for (final e in rawRules) {
        final id = (e as num?)?.toInt();
        if (id != null) rules.add(id);
      }
    }
    final sessions = <LegacyCampaignSession>[];
    final rawSessions = payload['sessions'];
    if (rawSessions is List) {
      for (final e in rawSessions) {
        if (e is Map<String, dynamic>) {
          sessions.add(LegacyCampaignSession.fromJson(e));
        } else if (e is Map) {
          sessions.add(
            LegacyCampaignSession.fromJson(Map<String, dynamic>.from(e)),
          );
        }
      }
    }
    return CampaignRecord(
      name: payload['name'] as String? ?? name,
      description: payload['description'] as String? ?? '',
      playerCharacterIds: players,
      houseRuleIds: rules,
      legacySessions: sessions,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'playerCharacterIds': playerCharacterIds,
        'houseRuleIds': houseRuleIds,
        // Keep embedded sessions until migration clears [legacySessions].
        'sessions': [
          for (final s in legacySessions)
            {'dateTime': s.dateTime, 'title': s.title},
        ],
      };

  CampaignRecord copyWith({
    String? name,
    String? description,
    List<int>? playerCharacterIds,
    List<int>? houseRuleIds,
    List<LegacyCampaignSession>? legacySessions,
  }) {
    return CampaignRecord(
      name: name ?? this.name,
      description: description ?? this.description,
      playerCharacterIds: playerCharacterIds ?? this.playerCharacterIds,
      houseRuleIds: houseRuleIds ?? this.houseRuleIds,
      legacySessions: legacySessions ?? this.legacySessions,
    );
  }

  String get descriptionPreview =>
      description.replaceAll(RegExp(r'\s+'), ' ').trim();
}
