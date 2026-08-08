import 'package:flutter/material.dart';

import '../../../../core/ui/catalog_image_slot.dart';
import '../../../../core/ui/markdown_form_field.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../../ui/world_form_helpers.dart';
import '../data/organisation_model.dart';

Future<OrganisationRecord?> showOrganisationFormSheet(
  BuildContext context, {
  OrganisationRecord? initial,
  required Map<int, String> characterNames,
  required Map<int, String> locationNames,
  List<CatalogItem> allOrganisations = const [],
  int? editingItemId,
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<OrganisationRecord>(
    context,
    title: editing ? 'Edit organisation' : 'New organisation',
    child: _OrganisationForm(
      initial: initial,
      characterNames: characterNames,
      locationNames: locationNames,
      allOrganisations: allOrganisations,
      editingItemId: editingItemId,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _OrganisationForm extends StatefulWidget {
  const _OrganisationForm({
    this.initial,
    required this.characterNames,
    required this.locationNames,
    required this.allOrganisations,
    this.editingItemId,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final OrganisationRecord? initial;
  final Map<int, String> characterNames;
  final Map<int, String> locationNames;
  final List<CatalogItem> allOrganisations;
  final int? editingItemId;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_OrganisationForm> createState() => _OrganisationFormState();
}

class _OrganisationFormState extends State<_OrganisationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late final _foundingController =
      TextEditingController(text: widget.initial?.founding ?? '');
  late final _typeController =
      TextEditingController(text: widget.initial?.type ?? '');
  late final _mottoController =
      TextEditingController(text: widget.initial?.motto ?? '');
  late final _imageUrlController =
      TextEditingController(text: widget.initial?.imageUrl ?? '');
  late List<String> _aliases = [...?widget.initial?.aliases];
  late List<int> _memberIds = [...?widget.initial?.memberIds];
  late int? _parentId = widget.initial?.parentId;
  late int? _seatId = widget.initial?.seatId;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _foundingController.dispose();
    _typeController.dispose();
    _mottoController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  List<CatalogItem> get _parentOptions {
    final excluded = widget.editingItemId == null
        ? <int>{}
        : organisationSubtreeIds(
            widget.allOrganisations,
            widget.editingItemId!,
          );
    final options = [
      for (final item in widget.allOrganisations)
        if (!excluded.contains(item.id)) item,
    ];
    options.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return options;
  }

  List<MapEntry<int, String>> get _seatOptions {
    final entries = widget.locationNames.entries.toList()
      ..sort(
        (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
      );
    return entries;
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final name = _nameController.text.trim();
    Navigator.pop(
      context,
      OrganisationRecord(
        name: name,
        description: _descriptionController.text.trim(),
        aliases: [
          for (final a in _aliases)
            if (a.trim().isNotEmpty &&
                a.trim().toLowerCase() != name.toLowerCase())
              a.trim(),
        ],
        founding: _foundingController.text.trim(),
        type: _typeController.text.trim(),
        seatId: _seatId,
        motto: _mottoController.text.trim(),
        memberIds: _memberIds,
        parentId: _parentId,
        imageUrl: normalizeCatalogImageUrl(_imageUrlController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parents = _parentOptions;
    final parentValid =
        _parentId == null || parents.any((p) => p.id == _parentId);
    final seats = _seatOptions;
    final seatValid =
        _seatId == null || widget.locationNames.containsKey(_seatId);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Name',
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          _AliasesEditor(
            values: _aliases,
            onChanged: (next) => setState(() => _aliases = next),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          DropdownButtonFormField<int?>(
            key: ValueKey('org-parent-$_parentId-${parents.length}'),
            initialValue: parentValid ? _parentId : null,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Parent body',
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('None'),
              ),
              for (final p in parents)
                DropdownMenuItem<int?>(
                  value: p.id,
                  child: Text(p.name),
                ),
            ],
            onChanged: (value) => setState(() => _parentId = value),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          DropdownButtonFormField<int?>(
            key: ValueKey('org-seat-$_seatId-${seats.length}'),
            initialValue: seatValid ? _seatId : null,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Seat',
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('None'),
              ),
              for (final entry in seats)
                DropdownMenuItem<int?>(
                  value: entry.key,
                  child: Text(entry.value),
                ),
            ],
            onChanged: (value) => setState(() => _seatId = value),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          MarkdownFormField(
            controller: _typeController,
            label: 'Type',
            minLines: 1,
            maxLines: 4,
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          MarkdownFormField(
            controller: _foundingController,
            label: 'Founding',
            minLines: 2,
            maxLines: 6,
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          MarkdownFormField(
            controller: _mottoController,
            label: 'Motto',
            minLines: 1,
            maxLines: 4,
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          catalogMultiPickTile(
            context: context,
            label: 'Members',
            labels: catalogSelectionLabels(
              selected: _memberIds.toSet(),
              namesById: widget.characterNames,
            ),
            onTap: () => pickCatalogIds(
              context: context,
              title: 'Members',
              options: catalogPicklistOptions(widget.characterNames),
              selected: _memberIds.toSet(),
              onDone: (next) => setState(() => _memberIds = next.toList()),
            ),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _imageUrlController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Image URL',
              hintText: 'https://… or Google Drive share link',
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            validator: validateOptionalHttpUrl,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          MarkdownFormField(
            controller: _descriptionController,
            label: 'Description',
            minLines: 4,
            maxLines: 12,
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.initial == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }
}

class _AliasesEditor extends StatefulWidget {
  const _AliasesEditor({
    required this.values,
    required this.onChanged,
  });

  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_AliasesEditor> createState() => _AliasesEditorState();
}

class _AliasesEditorState extends State<_AliasesEditor> {
  late final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final exists = widget.values.any(
      (v) => v.toLowerCase() == text.toLowerCase(),
    );
    if (!exists) {
      widget.onChanged([...widget.values, text]);
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Aliases',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Other names this organisation is known by',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        if (widget.values.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.values.length; i++)
                InputChip(
                  label: Text(widget.values[i]),
                  onDeleted: () {
                    final next = [...widget.values]..removeAt(i);
                    widget.onChanged(next);
                  },
                ),
            ],
          ),
        if (widget.values.isNotEmpty) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Add alias',
                ),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              tooltip: 'Add alias',
              onPressed: _add,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}
