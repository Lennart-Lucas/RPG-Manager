import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/class_model.dart';
import '../data/subclass_model.dart';
import 'class_features_editor.dart';

Future<SubclassRecord?> showSubclassFormSheet(
  BuildContext context, {
  SubclassRecord? initial,
  required List<CatalogItem> parentClasses,
  int? preferredParentClassId,
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<SubclassRecord>(
    context,
    title: editing ? 'Edit subclass' : 'New subclass',
    child: _SubclassForm(
      initial: initial,
      parentClasses: parentClasses,
      preferredParentClassId: preferredParentClassId,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _SubclassForm extends StatefulWidget {
  const _SubclassForm({
    this.initial,
    required this.parentClasses,
    this.preferredParentClassId,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final SubclassRecord? initial;
  final List<CatalogItem> parentClasses;
  final int? preferredParentClassId;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_SubclassForm> createState() => _SubclassFormState();
}

class _SubclassFormState extends State<_SubclassForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late int? _parentClassId = widget.initial?.parentClassId != null &&
          widget.initial!.parentClassId > 0
      ? widget.initial!.parentClassId
      : widget.preferredParentClassId;
  late List<ClassFeature> _features = flattenClassFeaturesByLevel(
    widget.initial?.featuresByLevel ?? const {},
    minLevel: _minFeatureLevelFor(_parentClassId),
  );

  int _minFeatureLevelFor(int? parentClassId) {
    if (parentClassId == null || parentClassId <= 0) return 1;
    for (final parent in widget.parentClasses) {
      if (parent.id != parentClassId) continue;
      return ClassRecord.fromCatalogPayload(
        name: parent.name,
        payload: parent.payload,
      ).subclassChosenAtLevel.clamp(1, 20);
    }
    return 1;
  }

  int get _minFeatureLevel => _minFeatureLevelFor(_parentClassId);

  void _setParentClassId(int? parentClassId) {
    final minLevel = _minFeatureLevelFor(parentClassId);
    setState(() {
      _parentClassId = parentClassId;
      _features = sortClassFeaturesByLevel([
        for (final f in _features)
          f.copyWith(level: f.level < minLevel ? minLevel : f.level),
      ]);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final parentId = _parentClassId;
    if (parentId == null || parentId <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a parent class')),
      );
      return;
    }
    Navigator.pop(
      context,
      SubclassRecord(
        name: _nameController.text.trim(),
        parentClassId: parentId,
        description: _descriptionController.text.trim(),
        featuresByLevel: groupClassFeaturesByLevel(
          _features,
          minLevel: _minFeatureLevel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parents = [...widget.parentClasses]
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    final minFeatureLevel = _minFeatureLevel;
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
            autofocus: widget.initial == null,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
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
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          DropdownButtonFormField<int>(
            initialValue: parents.any((p) => p.id == _parentClassId)
                ? _parentClassId
                : null,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Parent class',
              helperText: parents.isEmpty
                  ? 'Create a class first'
                  : 'Features start at subclass level $minFeatureLevel',
            ),
            items: [
              for (final parent in parents)
                DropdownMenuItem(
                  value: parent.id,
                  child: Text(parent.name),
                ),
            ],
            onChanged: parents.isEmpty ? null : _setParentClassId,
            validator: (value) {
              if (value == null) return 'Parent class is required';
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          ClassFeaturesEditor(
            title: 'Subclass features',
            features: _features,
            minLevel: minFeatureLevel,
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
            onChanged: (next) => setState(() => _features = next),
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
