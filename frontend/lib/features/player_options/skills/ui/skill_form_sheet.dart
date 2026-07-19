import 'package:flutter/material.dart';

import 'package:rpg_manager/features/dm_tools/resources/ui/resource_form_helpers.dart';
import 'package:rpg_manager/features/player_options/skills/data/skill_model.dart';

Future<SkillRecord?> showSkillFormSheet(
  BuildContext context, {
  SkillRecord? initial,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<SkillRecord>(
    context,
    title: editing ? 'Edit skill' : 'New skill',
    child: _SkillForm(initial: initial),
  );
}

class _SkillForm extends StatefulWidget {
  const _SkillForm({this.initial});

  final SkillRecord? initial;

  @override
  State<_SkillForm> createState() => _SkillFormState();
}

class _SkillFormState extends State<_SkillForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initial?.name ?? '',
  );
  late String _attribute = widget.initial?.attribute ?? 'STR';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.pop(
      context,
      SkillRecord(
        name: _nameController.text.trim(),
        attribute: _attribute,
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
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          DropdownButtonFormField<String>(
            initialValue: _attribute,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Attribute',
            ),
            items: [
              for (final attribute in SkillRecord.attributes)
                DropdownMenuItem(
                  value: attribute,
                  child: Text(attribute),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _attribute = value);
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Attribute is required';
              }
              return null;
            },
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
