import 'package:flutter/material.dart';

import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/class_model.dart';

Future<ClassRecord?> showClassFormSheet(
  BuildContext context, {
  ClassRecord? initial,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<ClassRecord>(
    context,
    title: editing ? 'Edit class' : 'New class',
    child: _ClassForm(initial: initial),
  );
}

class _ClassForm extends StatefulWidget {
  const _ClassForm({this.initial});

  final ClassRecord? initial;

  @override
  State<_ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends State<_ClassForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late bool _isCaster = widget.initial?.isCaster ?? false;

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
    Navigator.pop(
      context,
      ClassRecord(
        name: _nameController.text.trim(),
        isCaster: _isCaster,
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
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Spellcaster'),
            subtitle: const Text('Can appear on spell class lists'),
            value: _isCaster,
            onChanged: (value) => setState(() => _isCaster = value),
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
