import 'package:flutter/material.dart';

import '../../../catalog/data/catalog_models.dart';
import '../data/location_model.dart';

Map<int, List<CatalogItem>> locationChildrenByParentId(
  List<CatalogItem> all,
) {
  final map = <int, List<CatalogItem>>{};
  for (final item in all) {
    final parentId = LocationRecord.fromCatalogPayload(
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

/// Roots of the location forest: no parent, or parent missing from [all].
List<CatalogItem> locationForestRoots(List<CatalogItem> all) {
  final ids = {for (final item in all) item.id};
  final roots = <CatalogItem>[];
  for (final item in all) {
    final parentId = LocationRecord.fromCatalogPayload(
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

/// Indented staggered tree of locations.
///
/// - When [rootParentId] is set, shows descendants of that location only.
/// - When null, shows the full forest of root locations and their descendants.
class LocationTreeView extends StatelessWidget {
  const LocationTreeView({
    super.key,
    required this.locations,
    required this.onTap,
    this.rootParentId,
    this.onDelete,
    this.emptyLabel = 'No locations.',
  });

  final List<CatalogItem> locations;
  final int? rootParentId;
  final ValueChanged<CatalogItem> onTap;
  final ValueChanged<CatalogItem>? onDelete;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final childrenByParent = locationChildrenByParentId(locations);
    final seen = <int>{};
    final rows = <Widget>[];

    if (rootParentId != null) {
      seen.add(rootParentId!);
      rows.addAll(
        _subtreeRows(
          parentId: rootParentId!,
          depth: 0,
          childrenByParent: childrenByParent,
          seen: seen,
          scheme: scheme,
          textTheme: textTheme,
        ),
      );
    } else {
      for (final root in locationForestRoots(locations)) {
        if (seen.contains(root.id)) continue;
        seen.add(root.id);
        rows.add(
          _row(
            item: root,
            depth: 0,
            scheme: scheme,
            textTheme: textTheme,
          ),
        );
        rows.addAll(
          _subtreeRows(
            parentId: root.id,
            depth: 1,
            childrenByParent: childrenByParent,
            seen: seen,
            scheme: scheme,
            textTheme: textTheme,
          ),
        );
      }
    }

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          emptyLabel,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  List<Widget> _subtreeRows({
    required int parentId,
    required int depth,
    required Map<int, List<CatalogItem>> childrenByParent,
    required Set<int> seen,
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    final children = childrenByParent[parentId] ?? const <CatalogItem>[];
    final rows = <Widget>[];
    for (final child in children) {
      if (seen.contains(child.id)) continue;
      seen.add(child.id);
      rows.add(
        _row(
          item: child,
          depth: depth,
          scheme: scheme,
          textTheme: textTheme,
        ),
      );
      rows.addAll(
        _subtreeRows(
          parentId: child.id,
          depth: depth + 1,
          childrenByParent: childrenByParent,
          seen: seen,
          scheme: scheme,
          textTheme: textTheme,
        ),
      );
    }
    return rows;
  }

  Widget _row({
    required CatalogItem item,
    required int depth,
    required ColorScheme scheme,
    required TextTheme textTheme,
  }) {
    final record = LocationRecord.fromCatalogPayload(
      name: item.name,
      payload: item.payload,
    );
    return Padding(
      padding: EdgeInsets.only(left: 16.0 * depth, top: 4),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(item),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    record.type.label,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.name,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: () => onDelete!(item),
                    icon: Icon(
                      Icons.delete_outline,
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  Icon(
                    Icons.chevron_right,
                    color: scheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
