import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/class_model.dart';

/// Shared editor for class / subclass features grouped by level.
class ClassFeaturesEditor extends StatefulWidget {
  const ClassFeaturesEditor({
    required this.title,
    required this.features,
    required this.onChanged,
    this.minLevel = 1,
    this.searchLinks,
    this.loadAutoLinkTargets,
    super.key,
  });

  final String title;
  final List<ClassFeature> features;
  final ValueChanged<List<ClassFeature>> onChanged;

  /// Lowest selectable feature level (e.g. subclass unlock level).
  final int minLevel;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<ClassFeaturesEditor> createState() => _ClassFeaturesEditorState();
}

class _ClassFeaturesEditorState extends State<ClassFeaturesEditor> {
  String? _expandedId;

  int get _minLevel => widget.minLevel.clamp(1, 20);

  List<ClassFeature> get _sortedFeatures =>
      sortClassFeaturesByLevel(widget.features);

  int _clampLevel(int level) => level.clamp(_minLevel, 20);

  void _emit(List<ClassFeature> features, {String? keepExpandedId}) {
    final sorted = sortClassFeaturesByLevel([
      for (final f in features) f.copyWith(level: _clampLevel(f.level)),
    ]);
    widget.onChanged(sorted);
    setState(() {
      final id = keepExpandedId ?? _expandedId;
      if (id == null) {
        _expandedId = null;
        return;
      }
      _expandedId = sorted.any((f) => f.id == id) ? id : null;
    });
  }

  void _updateFeature(int index, ClassFeature feature) {
    final features = _sortedFeatures;
    final id = features[index].id;
    final next = [...features];
    next[index] = feature.copyWith(level: _clampLevel(feature.level));
    _emit(next, keepExpandedId: id);
  }

  void _removeFeature(int index) {
    final features = _sortedFeatures;
    final id = features[index].id;
    final next = [...features]..removeAt(index);
    _emit(next, keepExpandedId: _expandedId == id ? null : _expandedId);
  }

  void _addFeature() {
    final feature = ClassFeature(
      id: 'feature-${DateTime.now().microsecondsSinceEpoch}',
      name: '',
      level: _minLevel,
    );
    _emit([..._sortedFeatures, feature], keepExpandedId: feature.id);
  }

  void _toggleExpanded(String id) {
    setState(() {
      _expandedId = _expandedId == id ? null : id;
    });
  }

  @override
  void didUpdateWidget(covariant ClassFeaturesEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minLevel == widget.minLevel) return;
    final min = _minLevel;
    final needsClamp = widget.features.any((f) => f.level < min);
    if (!needsClamp) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _emit(widget.features, keepExpandedId: _expandedId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final features = _sortedFeatures;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final minLevel = _minLevel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        for (var i = 0; i < features.length; i++) ...[
          const SizedBox(height: 8),
          _FeatureAccordionItem(
            key: ValueKey(features[i].id),
            feature: features[i].copyWith(
              level: _clampLevel(features[i].level),
            ),
            minLevel: minLevel,
            expanded: _expandedId == features[i].id,
            onHeaderTap: () => _toggleExpanded(features[i].id),
            onDelete: () => _removeFeature(i),
            onChanged: (feature) => _updateFeature(i, feature),
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
            scheme: scheme,
            textTheme: textTheme,
          ),
        ],
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: _addFeature,
          icon: const Icon(Icons.add),
          label: const Text('Add feature'),
        ),
      ],
    );
  }
}

class _FeatureAccordionItem extends StatefulWidget {
  const _FeatureAccordionItem({
    super.key,
    required this.feature,
    required this.minLevel,
    required this.expanded,
    required this.onHeaderTap,
    required this.onDelete,
    required this.onChanged,
    required this.scheme,
    required this.textTheme,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final ClassFeature feature;
  final int minLevel;
  final bool expanded;
  final VoidCallback onHeaderTap;
  final VoidCallback onDelete;
  final ValueChanged<ClassFeature> onChanged;
  final ColorScheme scheme;
  final TextTheme textTheme;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_FeatureAccordionItem> createState() => _FeatureAccordionItemState();
}

class _FeatureAccordionItemState extends State<_FeatureAccordionItem> {
  late final TextEditingController _nameController;
  late int _level;

  ClassFeature get feature => widget.feature;
  int get minLevel => widget.minLevel;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: feature.name);
    _level = feature.level.clamp(minLevel, 20);
  }

  @override
  void didUpdateWidget(covariant _FeatureAccordionItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feature.id != feature.id) {
      _nameController.text = feature.name;
      _level = feature.level.clamp(minLevel, 20);
      return;
    }
    final nextLevel = feature.level.clamp(minLevel, 20);
    if (_level != nextLevel) {
      _level = nextLevel;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _emit({String? name, int? level, String? description}) {
    widget.onChanged(
      feature.copyWith(
        name: name ?? _nameController.text,
        level: (level ?? _level).clamp(minLevel, 20),
        description: description ?? feature.description,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final textTheme = widget.textTheme;
    final name = _nameController.text.trim();
    final title = name.isEmpty ? 'Untitled feature' : name;
    final expanded = widget.expanded;

    return Material(
      color: expanded
          ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
          : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: expanded
              ? scheme.outline.withValues(alpha: 0.55)
              : scheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: widget.onHeaderTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.expand_more : Icons.chevron_right,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Level $_level',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete feature',
                    onPressed: widget.onDelete,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
          // Keep the body mounted so expand/collapse does not churn the
          // platform accessibility tree (AnimatedSize / remount caused AXTree
          // "nodes left pending" errors on Windows).
          if (expanded) ...[
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.8),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: ResourceFormStyles.inputDecoration(
                      context,
                      label: 'Feature name',
                    ),
                    onChanged: (value) {
                      setState(() {});
                      _emit(name: value);
                    },
                  ),
                  const SizedBox(height: ResourceFormStyles.fieldSpacing),
                  DropdownButtonFormField<int>(
                    key: ValueKey('feat-level-${feature.id}-$minLevel'),
                    initialValue: _level,
                    decoration: ResourceFormStyles.inputDecoration(
                      context,
                      label: 'Level',
                      helperText: minLevel > 1
                          ? 'Subclass features start at level $minLevel'
                          : null,
                    ),
                    items: [
                      for (var lvl = minLevel; lvl <= 20; lvl++)
                        DropdownMenuItem(
                          value: lvl,
                          child: Text('$lvl'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _level = value);
                      _emit(level: value);
                    },
                  ),
                  const SizedBox(height: ResourceFormStyles.fieldSpacing),
                  MarkdownFormField(
                    key: ValueKey('feat-desc-${feature.id}'),
                    initialValue: feature.description,
                    label: 'Description',
                    minLines: 2,
                    maxLines: 6,
                    searchLinks: widget.searchLinks,
                    loadAutoLinkTargets: widget.loadAutoLinkTargets,
                    onChanged: (value) => _emit(description: value),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

List<ClassFeature> sortClassFeaturesByLevel(List<ClassFeature> features) {
  final next = [...features];
  next.sort((a, b) {
    final byLevel = a.level.compareTo(b.level);
    if (byLevel != 0) return byLevel;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return next;
}

Map<int, List<ClassFeature>> groupClassFeaturesByLevel(
  List<ClassFeature> features, {
  int minLevel = 1,
}) {
  final map = <int, List<ClassFeature>>{};
  final min = minLevel.clamp(1, 20);
  for (final f in sortClassFeaturesByLevel(features)) {
    if (f.name.trim().isEmpty && f.description.trim().isEmpty) continue;
    final level = f.level.clamp(min, 20);
    final cleaned = f.copyWith(
      id: f.id.trim().isEmpty ? slugifyClassPart(f.name) : f.id,
      name: f.name.trim(),
      level: level,
      description: f.description.trim(),
    );
    map.putIfAbsent(level, () => []).add(cleaned);
  }
  return map;
}

List<ClassFeature> flattenClassFeaturesByLevel(
  Map<int, List<ClassFeature>> featuresByLevel, {
  int minLevel = 1,
}) {
  final min = minLevel.clamp(1, 20);
  return sortClassFeaturesByLevel([
    for (final entry in featuresByLevel.entries)
      ...entry.value.map(
        (f) => f.copyWith(level: (entry.key).clamp(min, 20)),
      ),
  ]);
}
