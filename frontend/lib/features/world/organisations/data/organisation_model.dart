import '../../../catalog/data/catalog_models.dart';

class OrganisationRecord {
  const OrganisationRecord({
    required this.name,
    this.description = '',
    this.memberIds = const [],
    this.parentId,
  });

  final String name;
  final String description;
  final List<int> memberIds;
  final int? parentId;

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
      parentId: (payload['parentId'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'memberIds': memberIds,
        'parentId': parentId,
      };

  String get descriptionPreview =>
      description.replaceAll(RegExp(r'\s+'), ' ').trim();
}

Map<int, List<CatalogItem>> organisationChildrenByParentId(
  List<CatalogItem> all,
) {
  final map = <int, List<CatalogItem>>{};
  for (final item in all) {
    final parentId = OrganisationRecord.fromCatalogPayload(
      name: item.name,
      payload: item.payload,
    ).parentId;
    if (parentId == null) continue;
    map.putIfAbsent(parentId, () => []).add(item);
  }
  for (final children in map.values) {
    children.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
  }
  return map;
}

/// Roots of the organisation forest: no parent, or parent missing from [all].
List<CatalogItem> organisationForestRoots(List<CatalogItem> all) {
  final ids = {for (final item in all) item.id};
  final roots = <CatalogItem>[];
  for (final item in all) {
    final parentId = OrganisationRecord.fromCatalogPayload(
      name: item.name,
      payload: item.payload,
    ).parentId;
    if (parentId == null || !ids.contains(parentId)) {
      roots.add(item);
    }
  }
  roots.sort(
    (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
  );
  return roots;
}

/// [rootId] plus all descendant organisation ids (for cycle-safe parent picks).
Set<int> organisationSubtreeIds(List<CatalogItem> all, int rootId) {
  final childrenByParent = organisationChildrenByParentId(all);
  final out = <int>{rootId};
  void walk(int id) {
    for (final child in childrenByParent[id] ?? const <CatalogItem>[]) {
      if (out.add(child.id)) walk(child.id);
    }
  }

  walk(rootId);
  return out;
}
