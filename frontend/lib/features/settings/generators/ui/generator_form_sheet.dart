import 'package:flutter/material.dart';

import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/generator_model.dart';

Future<GeneratorRecord?> showGeneratorFormSheet(
  BuildContext context, {
  GeneratorRecord? initial,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<GeneratorRecord>(
    context,
    title: editing ? 'Edit generator' : 'New generator',
    child: _GeneratorForm(
      initial: initial ??
          GeneratorRecord(
            name: '',
            tablesDocument: GeneratorRecord.emptyTablesDocument,
            processDocument: GeneratorRecord.emptyProcessDocument,
          ),
    ),
  );
}

class _GeneratorForm extends StatefulWidget {
  const _GeneratorForm({required this.initial});

  final GeneratorRecord initial;

  @override
  State<_GeneratorForm> createState() => _GeneratorFormState();
}

class _GeneratorFormState extends State<_GeneratorForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.initial.name);
  late final _tablesController = TextEditingController(
    text: GeneratorRecord.encodePretty(widget.initial.tablesDocument),
  );
  late final _processController = TextEditingController(
    text: GeneratorRecord.encodePretty(widget.initial.processDocument),
  );
  bool _submitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _tablesController.dispose();
    _processController.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _submitted = true);
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    late final Map<String, dynamic> tables;
    late final Map<String, dynamic> process;
    try {
      tables = GeneratorRecord.decodeObject(_tablesController.text, 'Tables');
      process =
          GeneratorRecord.decodeObject(_processController.text, 'Process');
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    final payloadName = GeneratorRecord.nameFromPayload(tables);
    final payloadProcess = GeneratorRecord.processDocumentFromPayload(tables);
    final draft = GeneratorRecord(
      name: payloadName ?? _nameController.text.trim(),
      tablesDocument: GeneratorRecord.normalizeTablesDocument(tables),
      processDocument: payloadProcess ?? process,
    );
    final configError = draft.validateConfig();
    if (configError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(configError)),
      );
      return;
    }

    Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
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
            'Tables JSON',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _tablesController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'tables document',
            ),
            maxLines: 8,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Tables JSON is required';
              }
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          Text(
            'Process JSON',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _processController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'process document',
            ),
            maxLines: 8,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Process JSON is required';
              }
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: _submit,
              child: Text(
                widget.initial.name.isEmpty ? 'Create' : 'Save',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
