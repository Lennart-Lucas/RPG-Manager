class OrganisationRecord {
  const OrganisationRecord({
    required this.name,
    this.description = '',
    this.memberIds = const [],
  });

  final String name;
  final String description;
  final List<int> memberIds;

  factory OrganisationRecord.fromCatalogPayload({
    required String name,
    Map<String, dynamic>? payload,
  }) {
    if (payload == null) return OrganisationRecord(name: name);
    final rawMembers = payload['memberIds'];
    final members = <int>[];
    if (rawMembers is List) {
      for (final entry in rawMembers) {
        final id = (entry as num?)?.toInt();
        if (id != null) members.add(id);
      }
    }
    return OrganisationRecord(
      name: payload['name'] as String? ?? name,
      description: payload['description'] as String? ?? '',
      memberIds: members,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'memberIds': memberIds,
      };

  String get descriptionPreview =>
      description.replaceAll(RegExp(r'\s+'), ' ').trim();
}
