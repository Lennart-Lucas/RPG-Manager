import 'package:flutter/material.dart';

import '../../dm_tools/resources/ui/resource_form_helpers.dart';

Future<String?> showNameRecordFormSheet(
  BuildContext context, {
  required String singularLabel,
  String? initialName,
}) {
  final editing = initialName != null;
  return showAdaptiveResourceForm<String>(
    context,
    title: editing
        ? 'Edit ${singularLabel.toLowerCase()}'
        : 'New ${singularLabel.toLowerCase()}',
    child: _NameRecordForm(initialName: initialName ?? ''),
  );
}

class _NameRecordForm extends StatefulWidget {
  const _NameRecordForm({required this.initialName});

  final String initialName;

  @override
  State<_NameRecordForm> createState() => _NameRecordFormState();
}

class _NameRecordFormState extends State<_NameRecordForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    Navigator.pop(context, _nameController.text.trim());
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
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            onFieldSubmitted: (_) => _submit(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.initialName.isEmpty ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }
}
