class RecentPageVisit {
  const RecentPageVisit({
    required this.path,
    required this.title,
    required this.visitedAt,
  });

  final String path;
  final String title;
  final DateTime visitedAt;

  factory RecentPageVisit.fromJson(Map<String, dynamic> json) {
    final raw = json['visited_at'] ?? json['visitedAt'];
    return RecentPageVisit(
      path: json['path'] as String? ?? '',
      title: json['title'] as String? ?? '',
      visitedAt: raw is String
          ? DateTime.tryParse(raw)?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class UserActivity {
  const UserActivity({
    required this.id,
    required this.email,
    required this.isDm,
    this.lastLoginAt,
    this.lastActiveAt,
    this.recentPages = const [],
  });

  final int id;
  final String email;
  final bool isDm;
  final DateTime? lastLoginAt;
  final DateTime? lastActiveAt;
  final List<RecentPageVisit> recentPages;

  factory UserActivity.fromJson(Map<String, dynamic> json) {
    final pagesRaw = json['recent_pages'] ?? json['recentPages'];
    return UserActivity(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String? ?? '',
      isDm: json['is_dm'] as bool? ?? json['isDm'] as bool? ?? false,
      lastLoginAt: _parseDate(json['last_login_at'] ?? json['lastLoginAt']),
      lastActiveAt: _parseDate(json['last_active_at'] ?? json['lastActiveAt']),
      recentPages: pagesRaw is List
          ? [
              for (final entry in pagesRaw)
                if (entry is Map<String, dynamic>)
                  RecentPageVisit.fromJson(entry),
            ]
          : const [],
    );
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }
}
