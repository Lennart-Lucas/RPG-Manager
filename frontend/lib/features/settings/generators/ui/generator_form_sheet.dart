import 'package:flutter/material.dart';

import '../../../catalog/data/catalog_kind.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/generator_applies_to.dart';
import '../data/generator_model.dart';
import '../data/generator_record_mapping.dart';

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
            recordMappingDocument:
                GeneratorRecord.emptyRecordMappingDocument,
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
  late final _mappingController = TextEditingController(
    text: GeneratorRecord.encodePretty(
      widget.initial.recordMappingDocument ??
          GeneratorRecord.emptyRecordMappingDocument,
    ),
  );
  bool _submitted = false;
  CatalogKind? _appliesToKind;

  @override
  void initState() {
    super.initState();
    _appliesToKind = widget.initial.appliesTo?.kind;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tablesController.dispose();
    _processController.dispose();
    _mappingController.dispose();
    super.dispose();
  }

  GeneratorAppliesTo? _buildAppliesTo() {
    final kind = _appliesToKind;
    if (kind == null) return null;
    return GeneratorAppliesTo(kind: kind);
  }

  void _formatField(TextEditingController controller, String label) {
    try {
      final decoded = GeneratorRecord.decodeObject(controller.text, label);
      controller.text = GeneratorRecord.encodePretty(decoded);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Formatted $label JSON')),
      );
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  void _validateDraft() {
    try {
      final draft = _buildDraft();
      final error = draft.validateConfig();
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Config looks valid')),
      );
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  GeneratorRecord _buildDraft() {
    final tables =
        GeneratorRecord.decodeObject(_tablesController.text, 'Tables');
    final process =
        GeneratorRecord.decodeObject(_processController.text, 'Process');
    final mapping = GeneratorRecord.decodeObject(
      _mappingController.text,
      'Record mapping',
    );
    GeneratorRecordMapping.fromJson(mapping);

    final payloadName = GeneratorRecord.nameFromPayload(tables);
    final payloadProcess = GeneratorRecord.processDocumentFromPayload(tables);
    final payloadMapping = GeneratorRecord.recordMappingFromPayload(tables);
    final fromEditor = GeneratorRecordMapping.fromJson(mapping);
    final fromTables = GeneratorRecordMapping.fromJson(payloadMapping);
    final resolvedMapping = fromEditor.hasBindings
        ? mapping
        : (fromTables.hasBindings
            ? payloadMapping!
            : (payloadMapping ?? mapping));
    return GeneratorRecord(
      name: payloadName ?? _nameController.text.trim(),
      tablesDocument: GeneratorRecord.normalizeTablesDocument(tables),
      processDocument: payloadProcess ?? process,
      recordMappingDocument: resolvedMapping,
      appliesTo: _buildAppliesTo(),
    );
  }

  void _submit() {
    setState(() => _submitted = true);
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    late final GeneratorRecord draft;
    try {
      draft = _buildDraft();
    } on FormatException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    }

    final configError = draft.validateConfig();
    if (configError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(configError)),
      );
      return;
    }

    Navigator.pop(context, draft);
  }

  Widget _jsonToolbar({
    required String label,
    required TextEditingController controller,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        TextButton(
          onPressed: () => _formatField(controller, label),
          child: const Text('Format'),
        ),
      ],
    );
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
          DropdownButtonFormField<CatalogKind?>(
            key: ValueKey('applies-to-${_appliesToKind?.apiValue ?? 'none'}'),
            initialValue: _appliesToKind,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Offer on create as',
            ),
            items: [
              const DropdownMenuItem<CatalogKind?>(
                value: null,
                child: Text('None (Settings only)'),
              ),
              for (final kind in GeneratorAppliesTo.createTargetKinds)
                DropdownMenuItem<CatalogKind?>(
                  value: kind,
                  child: Text(kind.displayLabel),
                ),
            ],
            onChanged: (value) => setState(() => _appliesToKind = value),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          _jsonToolbar(label: 'Tables JSON', controller: _tablesController),
          const SizedBox(height: 6),
          TextFormField(
            controller: _tablesController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'tables document',
            ),
            maxLines: 12,
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
          _jsonToolbar(label: 'Process JSON', controller: _processController),
          const SizedBox(height: 6),
          TextFormField(
            controller: _processController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'process document',
            ),
            maxLines: 12,
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
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          _jsonToolbar(
            label: 'Record mapping JSON',
            controller: _mappingController,
          ),
          const SizedBox(height: 6),
          Text(
            'Shape: { "version": 1, "bindings": [ { "matchType", "kind", '
            '"nameFrom", "fields": [ … ] } ] }. '
            'Used by Apply to create catalog records from results.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _mappingController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'recordMapping document',
            ),
            maxLines: 14,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Record mapping JSON is required (use empty bindings)';
              }
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          Row(
            children: [
              OutlinedButton(
                onPressed: _validateDraft,
                child: const Text('Validate'),
              ),
              const Spacer(),
              FilledButton(
                onPressed: _submit,
                child: Text(
                  widget.initial.name.isEmpty ? 'Create' : 'Save',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
