import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/transformation_model.dart';

Future<TransformationRecord?> showTransformationFormSheet(
  BuildContext context, {
  TransformationRecord? initial,
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<TransformationRecord>(
    context,
    title: editing ? 'Edit transformation' : 'New transformation',
    child: _TransformationForm(
      initial: initial,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _TransformationForm extends StatefulWidget {
  const _TransformationForm({
    this.initial,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final TransformationRecord? initial;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_TransformationForm> createState() => _TransformationFormState();
}

class _TransformationFormState extends State<_TransformationForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _roleplayController =
      TextEditingController(text: widget.initial?.prereqRoleplay ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late final _scoreController = TextEditingController(
    text: '${widget.initial?.prereqAbility.score ?? 13}',
  );
  late AbilityAttribute _attribute =
      widget.initial?.prereqAbility.attribute ?? AbilityAttribute.str;
  late List<TransformationFeature> _features = [
    ...?widget.initial?.features,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _roleplayController.dispose();
    _descriptionController.dispose();
    _scoreController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final score = int.tryParse(_scoreController.text.trim()) ?? 13;
    Navigator.pop(
      context,
      TransformationRecord(
        name: _nameController.text.trim(),
        prereqAbility: TransformationPrereqAbility(
          attribute: _attribute,
          score: score.clamp(1, 30),
        ),
        prereqRoleplay: _roleplayController.text.trim(),
        description: _descriptionController.text.trim(),
        features: _features
            .where((f) => f.name.trim().isNotEmpty || f.description.trim().isNotEmpty)
            .map(
              (f) => TransformationFeature(
                name: f.name.trim(),
                kind: f.kind,
                level: f.level.clamp(1, 4),
                description: f.description.trim(),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          Text(
            'Ability prerequisite',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<AbilityAttribute>(
                  initialValue: _attribute,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Attribute',
                  ),
                  items: [
                    for (final a in AbilityAttribute.values)
                      DropdownMenuItem(value: a, child: Text(a.label)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _attribute = value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: TextFormField(
                  controller: _scoreController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Score',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    final n = int.tryParse(value?.trim() ?? '');
                    if (n == null || n < 1 || n > 30) {
                      return '1–30';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _roleplayController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Roleplay prerequisite',
            ),
            maxLines: 2,
          ),
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
          Text(
            'Features',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          for (var i = 0; i < _features.length; i++)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: _features[i].name,
                            decoration: ResourceFormStyles.inputDecoration(
                              context,
                              label: 'Feature name',
                            ),
                            onChanged: (value) {
                              final next = [..._features];
                              next[i] = next[i].copyWith(name: value);
                              setState(() => _features = next);
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(
                              () => _features = [..._features]..removeAt(i),
                            );
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<
                              TransformationFeatureKind>(
                            initialValue: _features[i].kind,
                            decoration: ResourceFormStyles.inputDecoration(
                              context,
                              label: 'Kind',
                            ),
                            items: [
                              for (final k in TransformationFeatureKind.values)
                                DropdownMenuItem(
                                  value: k,
                                  child: Text(k.label),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              final next = [..._features];
                              next[i] = next[i].copyWith(kind: value);
                              setState(() => _features = next);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: _features[i].level.clamp(1, 4),
                            decoration: ResourceFormStyles.inputDecoration(
                              context,
                              label: 'Level',
                            ),
                            items: [
                              for (var level = 1; level <= 4; level++)
                                DropdownMenuItem(
                                  value: level,
                                  child: Text('$level'),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              final next = [..._features];
                              next[i] = next[i].copyWith(level: value);
                              setState(() => _features = next);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    MarkdownFormField(
                      key: ValueKey('feature-desc-$i-${_features[i].name}'),
                      initialValue: _features[i].description,
                      label: 'Feature description',
                      minLines: 2,
                      maxLines: 6,
                      searchLinks: widget.searchLinks,
                      loadAutoLinkTargets: widget.loadAutoLinkTargets,
                      onChanged: (value) {
                        final next = [..._features];
                        next[i] = next[i].copyWith(description: value);
                        _features = next;
                      },
                    ),
                  ],
                ),
              ),
            ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _features = [
                  ..._features,
                  const TransformationFeature(name: ''),
                ];
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add feature'),
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
