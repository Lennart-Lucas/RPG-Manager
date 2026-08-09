import 'package:flutter/material.dart';

import '../../../../core/ui/catalog_image_slot.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../characters/ui/mtg_alignment_chips.dart';
import '../../world_icons.dart';
import '../data/organisation_model.dart';

/// Indented tree of organisations.
///
/// - When [rootParentId] is set, shows descendants of that organisation only.
/// - When null, shows the full forest of root organisations and descendants.
class OrganisationTreeView extends StatelessWidget {
  const OrganisationTreeView({
    super.key,
    required this.organisations,
    required this.onTap,
    this.rootParentId,
    this.onDelete,
    this.emptyLabel = 'No organisations.',
  });

  final List<CatalogItem> organisations;
  final int? rootParentId;
  final ValueChanged<CatalogItem> onTap;
  final ValueChanged<CatalogItem>? onDelete;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final childrenByParent = organisationChildrenByParentId(organisations);
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
      for (final root in organisationForestRoots(organisations)) {
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
    final record = OrganisationRecord.fromCatalogPayload(
      name: item.name,
      payload: item.payload,
    );
    final count = record.memberIds.length;
    final aliases = record.aliases.join(', ');
    final muted = textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
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
                CatalogImageThumb(
                  imageUrl: record.imageUrl,
                  fallback: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      organisationsPageIcon,
                      size: 22,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (aliases.isNotEmpty)
                        Text(
                          aliases,
                          style: muted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (record.mtgAlignment.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        MtgAlignmentChips(
                          colors: record.mtgAlignment,
                          size: 20,
                        ),
                      ],
                      Text(
                        '$count member${count == 1 ? '' : 's'}',
                        style: muted,
                      ),
                    ],
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
