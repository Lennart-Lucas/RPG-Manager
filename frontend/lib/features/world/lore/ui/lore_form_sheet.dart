import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/lore_model.dart';

Future<LoreRecord?> showLoreFormSheet(
  BuildContext context, {
  LoreRecord? initial,
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<LoreRecord>(
    context,
    title: editing ? 'Edit lore' : 'New lore',
    child: _LoreForm(
      initial: initial,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _LoreForm extends StatefulWidget {
  const _LoreForm({
    this.initial,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final LoreRecord? initial;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_LoreForm> createState() => _LoreFormState();
}

class _LoreFormState extends State<_LoreForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.pop(
      context,
      LoreRecord(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
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
