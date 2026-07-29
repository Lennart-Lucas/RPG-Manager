import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../../ui/world_form_helpers.dart';
import '../data/organisation_model.dart';

Future<OrganisationRecord?> showOrganisationFormSheet(
  BuildContext context, {
  OrganisationRecord? initial,
  required Map<int, String> characterNames,
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
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _OrganisationForm extends StatefulWidget {
  const _OrganisationForm({
    this.initial,
    required this.characterNames,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final OrganisationRecord? initial;
  final Map<int, String> characterNames;
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
  late List<int> _memberIds = [...?widget.initial?.memberIds];

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
      OrganisationRecord(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        memberIds: _memberIds,
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
