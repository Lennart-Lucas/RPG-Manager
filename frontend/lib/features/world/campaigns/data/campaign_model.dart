class CampaignSession {
  const CampaignSession({
    required this.dateTime,
    this.title = '',
  });

  /// ISO-8601 datetime string.
  final String dateTime;
  final String title;

  factory CampaignSession.fromJson(Map<String, dynamic> json) {
    return CampaignSession(
      dateTime: json['dateTime'] as String? ?? '',
      title: json['title'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'dateTime': dateTime,
        'title': title,
      };

  DateTime? get parsedDateTime => DateTime.tryParse(dateTime);

  static String displayName({
    required String campaignName,
    required int index1Based,
    required String title,
  }) {
    final base = '$campaignName s$index1Based';
    final t = title.trim();
    if (t.isEmpty) return base;
    return '$base - $t';
  }

  CampaignSession copyWith({String? dateTime, String? title}) {
    return CampaignSession(
      dateTime: dateTime ?? this.dateTime,
      title: title ?? this.title,
    );
  }
}

class CampaignRecord {
  const CampaignRecord({
    required this.name,
    this.description = '',
    this.playerCharacterIds = const [],
    this.houseRuleIds = const [],
    this.sessions = const [],
  });

  final String name;
  final String description;
  final List<int> playerCharacterIds;
  final List<int> houseRuleIds;
  final List<CampaignSession> sessions;

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
    final sessions = <CampaignSession>[];
    final rawSessions = payload['sessions'];
    if (rawSessions is List) {
      for (final e in rawSessions) {
        if (e is Map<String, dynamic>) {
          sessions.add(CampaignSession.fromJson(e));
        } else if (e is Map) {
          sessions.add(CampaignSession.fromJson(Map<String, dynamic>.from(e)));
        }
      }
    }
    return CampaignRecord(
      name: payload['name'] as String? ?? name,
      description: payload['description'] as String? ?? '',
      playerCharacterIds: players,
      houseRuleIds: rules,
      sessions: sortSessions(sessions),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'playerCharacterIds': playerCharacterIds,
        'houseRuleIds': houseRuleIds,
        'sessions': [for (final s in sortSessions(sessions)) s.toJson()],
      };

  static List<CampaignSession> sortSessions(List<CampaignSession> sessions) {
    final copy = [...sessions];
    copy.sort((a, b) {
      final da = a.parsedDateTime;
      final db = b.parsedDateTime;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return da.compareTo(db);
    });
    return copy;
  }

  String sessionDisplayNameAt(int index1Based, CampaignSession session) {
    return CampaignSession.displayName(
      campaignName: name,
      index1Based: index1Based,
      title: session.title,
    );
  }

  String get descriptionPreview =>
      description.replaceAll(RegExp(r'\s+'), ' ').trim();
}
