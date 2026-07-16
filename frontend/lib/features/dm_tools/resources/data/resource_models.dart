const kLinkSources = <String>[
  'website',
  'patreon',
  'drive',
  'dropbox',
  'mega',
  'reddit',
  'homebrewery',
  'gmbinder',
];

class AuthorLink {
  const AuthorLink({required this.source, required this.url});

  final String source;
  final String url;

  Map<String, dynamic> toJson() => {'source': source, 'url': url};

  factory AuthorLink.fromJson(Map<String, dynamic> json) {
    return AuthorLink(
      source: json['source'] as String,
      url: json['url'] as String,
    );
  }
}

class Author {
  const Author({
    required this.id,
    required this.userId,
    required this.name,
    required this.links,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int userId;
  final String name;
  final List<AuthorLink> links;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Author.fromJson(Map<String, dynamic> json) {
    final rawLinks = json['links'];
    final links = <AuthorLink>[];
    if (rawLinks is List) {
      for (final item in rawLinks) {
        if (item is Map<String, dynamic>) {
          links.add(AuthorLink.fromJson(item));
        } else if (item is Map) {
          links.add(AuthorLink.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return Author(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      name: json['name'] as String,
      links: links,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class ResourceFile {
  const ResourceFile({
    required this.id,
    required this.userId,
    required this.authorId,
    required this.name,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int userId;
  final int authorId;
  final String name;
  final String? source;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory ResourceFile.fromJson(Map<String, dynamic> json) {
    return ResourceFile(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      authorId: json['author_id'] as int,
      name: json['name'] as String,
      source: json['source'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
