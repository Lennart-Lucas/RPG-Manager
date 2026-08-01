import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/location_model.dart';

Future<LocationRecord?> showLocationFormSheet(
  BuildContext context, {
  LocationRecord? initial,
  required List<CatalogItem> allLocations,
  int? editingItemId,
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<LocationRecord>(
    context,
    title: editing ? 'Edit location' : 'New location',
    child: _LocationForm(
      initial: initial,
      allLocations: allLocations,
      editingItemId: editingItemId,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _LocationForm extends StatefulWidget {
  const _LocationForm({
    this.initial,
    required this.allLocations,
    this.editingItemId,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final LocationRecord? initial;
  final List<CatalogItem> allLocations;
  final int? editingItemId;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_LocationForm> createState() => _LocationFormState();
}

class _LocationFormState extends State<_LocationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late LocationType _type = widget.initial?.type ?? LocationType.site;
  late int? _parentId = widget.initial?.parentId;
  String? _parentError;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  LocationRecord? _parentRecord(int? id) {
    if (id == null) return null;
    for (final item in widget.allLocations) {
      if (item.id == id) {
        return LocationRecord.fromCatalogPayload(
          name: item.name,
          payload: item.payload,
        );
      }
    }
    return null;
  }

  List<CatalogItem> get _parentCandidates {
    final allowed = _type.allowedParentTypes;
    if (allowed.isEmpty) return const [];
    return [
      for (final item in widget.allLocations)
        if (item.id != widget.editingItemId)
          if (allowed.contains(
            LocationRecord.fromCatalogPayload(
              name: item.name,
              payload: item.payload,
            ).type,
          ))
            item,
    ];
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final initial = widget.initial;
    final draft = LocationRecord(
      name: _nameController.text.trim(),
      type: _type,
      parentId: _type.allowedParentTypes.isEmpty ? null : _parentId,
      description: _descriptionController.text.trim(),
      // Preserve legacy overview fields not shown in the form.
      population: initial?.population ?? '',
      government: initial?.government ?? '',
      ruler: initial?.ruler ?? '',
      alignment: initial?.alignment ?? '',
      religions: initial?.religions ?? '',
      languages: initial?.languages ?? '',
      exports: initial?.exports ?? '',
      imports: initial?.imports ?? '',
      defenses: initial?.defenses ?? '',
      history: initial?.history ?? '',
      mapNotes: initial?.mapNotes ?? '',
    );
    final err = draft.validateParent(_parentRecord(draft.parentId));
    if (err != null) {
      setState(() => _parentError = err);
      return;
    }
    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    final parents = _parentCandidates;
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
          DropdownButtonFormField<LocationType>(
            initialValue: _type,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Type',
            ),
            items: [
              for (final t in LocationType.values)
                DropdownMenuItem(value: t, child: Text(t.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _type = value;
                _parentError = null;
                if (value.allowedParentTypes.isEmpty) {
                  _parentId = null;
                } else if (_parentId != null &&
                    !parents.any((p) => p.id == _parentId)) {
                  _parentId = null;
                }
              });
            },
          ),
          if (_type.allowedParentTypes.isNotEmpty) ...[
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            DropdownButtonFormField<int?>(
              key: ValueKey('parent-${_type.apiValue}'),
              initialValue: parents.any((p) => p.id == _parentId)
                  ? _parentId
                  : null,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Parent',
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
              onChanged: (value) {
                setState(() {
                  _parentId = value;
                  _parentError = null;
                });
              },
            ),
            if (_parentError != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _parentError!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          MarkdownFormField(
            controller: _descriptionController,
            label: 'Description',
            minLines: 3,
            maxLines: 10,
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
