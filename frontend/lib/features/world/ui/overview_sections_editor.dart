import 'package:flutter/material.dart';

import '../../../core/ui/markdown_form_field.dart';
import '../../dm_tools/resources/ui/resource_form_helpers.dart';
import 'overview_sections.dart';

/// Accordion editor for named overview sections containing name+markdown items.
class OverviewSectionsEditor extends StatefulWidget {
  const OverviewSectionsEditor({
    super.key,
    required this.sections,
    required this.onChanged,
    this.searchLinks,
    this.loadAutoLinkTargets,
    this.title = 'Overview sections',
  });

  final List<OverviewSection> sections;
  final ValueChanged<List<OverviewSection>> onChanged;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;
  final String title;

  @override
  State<OverviewSectionsEditor> createState() => _OverviewSectionsEditorState();
}

class _OverviewSectionsEditorState extends State<OverviewSectionsEditor> {
  /// Stable ids so expand state survives list mutations.
  final List<String> _sectionIds = [];
  final List<List<String>> _itemIds = [];
  String? _expandedSectionId;
  String? _expandedItemId;

  @override
  void initState() {
    super.initState();
    _syncIds(widget.sections);
  }

  @override
  void didUpdateWidget(covariant OverviewSectionsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.sections, widget.sections)) {
      _syncIds(widget.sections);
    }
  }

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_sectionIds.length}';

  void _syncIds(List<OverviewSection> sections) {
    while (_sectionIds.length < sections.length) {
      _sectionIds.add(_newId('section'));
      _itemIds.add([]);
    }
    while (_sectionIds.length > sections.length) {
      _sectionIds.removeLast();
      _itemIds.removeLast();
    }
    for (var s = 0; s < sections.length; s++) {
      final items = sections[s].items;
      while (_itemIds[s].length < items.length) {
        _itemIds[s].add(_newId('item'));
      }
      while (_itemIds[s].length > items.length) {
        _itemIds[s].removeLast();
      }
    }
  }

  void _emit(List<OverviewSection> next) {
    _syncIds(next);
    widget.onChanged(next);
  }

  void _addSection() {
    final next = [
      ...widget.sections,
      const OverviewSection(name: 'Details', items: [OverviewItem()]),
    ];
    _emit(next);
    setState(() {
      _expandedSectionId = _sectionIds.last;
      _expandedItemId = _itemIds.last.first;
    });
  }

  void _removeSection(int index) {
    final removedSectionId = _sectionIds[index];
    final next = [...widget.sections]..removeAt(index);
    _sectionIds.removeAt(index);
    _itemIds.removeAt(index);
    _emit(next);
    setState(() {
      if (_expandedSectionId == removedSectionId) {
        _expandedSectionId = null;
        _expandedItemId = null;
      }
    });
  }

  void _moveSection(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= widget.sections.length) return;
    final next = [...widget.sections];
    final section = next.removeAt(index);
    next.insert(target, section);
    final sid = _sectionIds.removeAt(index);
    _sectionIds.insert(target, sid);
    final iid = _itemIds.removeAt(index);
    _itemIds.insert(target, iid);
    _emit(next);
  }

  void _updateSection(int index, OverviewSection section) {
    final next = [...widget.sections];
    next[index] = section;
    _emit(next);
  }

  void _addItem(int sectionIndex) {
    final section = widget.sections[sectionIndex];
    final items = [...section.items, const OverviewItem()];
    _updateSection(sectionIndex, section.copyWith(items: items));
    setState(() {
      _expandedSectionId = _sectionIds[sectionIndex];
      _expandedItemId = _itemIds[sectionIndex].last;
    });
  }

  void _removeItem(int sectionIndex, int itemIndex) {
    final removedId = _itemIds[sectionIndex][itemIndex];
    final section = widget.sections[sectionIndex];
    final items = [...section.items]..removeAt(itemIndex);
    _itemIds[sectionIndex].removeAt(itemIndex);
    _updateSection(sectionIndex, section.copyWith(items: items));
    setState(() {
      if (_expandedItemId == removedId) _expandedItemId = null;
    });
  }

  void _moveItem(int sectionIndex, int itemIndex, int delta) {
    final section = widget.sections[sectionIndex];
    final target = itemIndex + delta;
    if (target < 0 || target >= section.items.length) return;
    final items = [...section.items];
    final item = items.removeAt(itemIndex);
    items.insert(target, item);
    final id = _itemIds[sectionIndex].removeAt(itemIndex);
    _itemIds[sectionIndex].insert(target, id);
    _updateSection(sectionIndex, section.copyWith(items: items));
  }

  void _updateItem(int sectionIndex, int itemIndex, OverviewItem item) {
    final section = widget.sections[sectionIndex];
    final items = [...section.items];
    items[itemIndex] = item;
    _updateSection(sectionIndex, section.copyWith(items: items));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sections = widget.sections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.title,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Grouped name + description rows for the Wikipedia overview box.',
          style: textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        for (var s = 0; s < sections.length; s++) ...[
          const SizedBox(height: 10),
          _SectionTile(
            key: ValueKey(_sectionIds[s]),
            section: sections[s],
            expanded: _expandedSectionId == _sectionIds[s],
            onToggle: () {
              setState(() {
                _expandedSectionId = _expandedSectionId == _sectionIds[s]
                    ? null
                    : _sectionIds[s];
              });
            },
            canMoveUp: s > 0,
            canMoveDown: s < sections.length - 1,
            onMoveUp: () => _moveSection(s, -1),
            onMoveDown: () => _moveSection(s, 1),
            onDelete: () => _removeSection(s),
            onNameChanged: (name) =>
                _updateSection(s, sections[s].copyWith(name: name)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sections[s].items.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _ItemTile(
                    key: ValueKey(_itemIds[s][i]),
                    item: sections[s].items[i],
                    expanded: _expandedItemId == _itemIds[s][i],
                    onToggle: () {
                      setState(() {
                        _expandedItemId = _expandedItemId == _itemIds[s][i]
                            ? null
                            : _itemIds[s][i];
                      });
                    },
                    canMoveUp: i > 0,
                    canMoveDown: i < sections[s].items.length - 1,
                    onMoveUp: () => _moveItem(s, i, -1),
                    onMoveDown: () => _moveItem(s, i, 1),
                    onDelete: () => _removeItem(s, i),
                    onChanged: (item) => _updateItem(s, i, item),
                    searchLinks: widget.searchLinks,
                    loadAutoLinkTargets: widget.loadAutoLinkTargets,
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _addItem(s),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add item'),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _addSection,
          icon: const Icon(Icons.add),
          label: const Text('Add section'),
        ),
      ],
    );
  }
}

class _SectionTile extends StatefulWidget {
  const _SectionTile({
    super.key,
    required this.section,
    required this.expanded,
    required this.onToggle,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onNameChanged,
    required this.child,
  });

  final OverviewSection section;
  final bool expanded;
  final VoidCallback onToggle;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final ValueChanged<String> onNameChanged;
  final Widget child;

  @override
  State<_SectionTile> createState() => _SectionTileState();
}

class _SectionTileState extends State<_SectionTile> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.section.name);
  }

  @override
  void didUpdateWidget(covariant _SectionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section.name != widget.section.name &&
        _nameController.text != widget.section.name) {
      _nameController.text = widget.section.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = widget.section.name.trim().isEmpty
        ? 'Untitled section'
        : widget.section.name;
    final count = widget.section.items.where((i) => !i.isBlank).length;

    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            onTap: widget.onToggle,
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('$count item${count == 1 ? '' : 's'}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Move up',
                  onPressed: widget.canMoveUp ? widget.onMoveUp : null,
                  icon: const Icon(Icons.arrow_upward, size: 18),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: widget.canMoveDown ? widget.onMoveDown : null,
                  icon: const Icon(Icons.arrow_downward, size: 18),
                ),
                IconButton(
                  tooltip: 'Delete section',
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
                Icon(widget.expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          if (widget.expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: ResourceFormStyles.inputDecoration(
                      context,
                      label: 'Section name',
                    ),
                    onChanged: widget.onNameChanged,
                  ),
                  const SizedBox(height: 10),
                  widget.child,
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatefulWidget {
  const _ItemTile({
    super.key,
    required this.item,
    required this.expanded,
    required this.onToggle,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onChanged,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final OverviewItem item;
  final bool expanded;
  final VoidCallback onToggle;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final ValueChanged<OverviewItem> onChanged;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_ItemTile> createState() => _ItemTileState();
}

class _ItemTileState extends State<_ItemTile> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.item.name);
    _descriptionController =
        TextEditingController(text: widget.item.description);
  }

  @override
  void didUpdateWidget(covariant _ItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.name != widget.item.name &&
        _nameController.text != widget.item.name) {
      _nameController.text = widget.item.name;
    }
    if (oldWidget.item.description != widget.item.description &&
        _descriptionController.text != widget.item.description) {
      _descriptionController.text = widget.item.description;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(
      OverviewItem(
        name: _nameController.text,
        description: _descriptionController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title =
        widget.item.name.trim().isEmpty ? 'Untitled item' : widget.item.name;

    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            dense: true,
            onTap: widget.onToggle,
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Move up',
                  onPressed: widget.canMoveUp ? widget.onMoveUp : null,
                  icon: const Icon(Icons.arrow_upward, size: 18),
                ),
                IconButton(
                  tooltip: 'Move down',
                  onPressed: widget.canMoveDown ? widget.onMoveDown : null,
                  icon: const Icon(Icons.arrow_downward, size: 18),
                ),
                IconButton(
                  tooltip: 'Delete item',
                  onPressed: widget.onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
                Icon(widget.expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          if (widget.expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: ResourceFormStyles.inputDecoration(
                      context,
                      label: 'Name',
                    ),
                    onChanged: (_) => _emit(),
                  ),
                  const SizedBox(height: ResourceFormStyles.fieldSpacing),
                  MarkdownFormField(
                    controller: _descriptionController,
                    label: 'Description',
                    minLines: 2,
                    maxLines: 8,
                    searchLinks: widget.searchLinks,
                    loadAutoLinkTargets: widget.loadAutoLinkTargets,
                    onChanged: (_) => _emit(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
