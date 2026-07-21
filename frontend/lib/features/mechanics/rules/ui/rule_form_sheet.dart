import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/rule_model.dart';

Future<RuleRecord?> showRuleFormSheet(
  BuildContext context, {
  RuleRecord? initial,
  int? editingItemId,
  List<CatalogItem> siblingRules = const [],
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<RuleRecord>(
    context,
    title: editing ? 'Edit rule' : 'New rule',
    child: _RuleForm(
      initial: initial,
      editingItemId: editingItemId,
      siblingRules: siblingRules,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _RuleForm extends StatefulWidget {
  const _RuleForm({
    this.initial,
    this.editingItemId,
    required this.siblingRules,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final RuleRecord? initial;
  final int? editingItemId;
  final List<CatalogItem> siblingRules;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_RuleForm> createState() => _RuleFormState();
}

class _RuleFormState extends State<_RuleForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _bodyController =
      TextEditingController(text: widget.initial?.body ?? '');
  late int? _parentRuleId = widget.initial?.parentRuleId;

  @override
  void dispose() {
    _nameController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  List<CatalogItem> get _parentOptions {
    return widget.siblingRules
        .where((r) => r.id != widget.editingItemId)
        .toList()
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.pop(
      context,
      RuleRecord(
        name: _nameController.text.trim(),
        parentRuleId: _parentRuleId,
        body: _bodyController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parents = _parentOptions;
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
          DropdownButtonFormField<int?>(
            initialValue: _parentRuleId,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Parent rule',
              hintText: 'Optional',
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('None'),
              ),
              for (final rule in parents)
                DropdownMenuItem<int?>(
                  value: rule.id,
                  child: Text(rule.name),
                ),
            ],
            onChanged: (value) => setState(() => _parentRuleId = value),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          MarkdownFormField(
            controller: _bodyController,
            label: 'Body',
            hintText: 'Markdown content for this rule',
            minLines: 16,
            maxLines: 48,
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
