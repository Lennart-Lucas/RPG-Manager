import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/character_model.dart';

Future<CharacterRecord?> showCharacterFormSheet(
  BuildContext context, {
  CharacterRecord? initial,
  required List<CatalogItem> races,
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<CharacterRecord>(
    context,
    title: editing ? 'Edit character' : 'New character',
    child: _CharacterForm(
      initial: initial,
      races: races,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _CharacterForm extends StatefulWidget {
  const _CharacterForm({
    this.initial,
    required this.races,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final CharacterRecord? initial;
  final List<CatalogItem> races;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_CharacterForm> createState() => _CharacterFormState();
}

class _CharacterFormState extends State<_CharacterForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _playerController =
      TextEditingController(text: widget.initial?.playerName ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late int? _raceId = widget.initial?.raceId;
  late Set<MtgColor> _alignment = {...?widget.initial?.mtgAlignment};

  @override
  void dispose() {
    _nameController.dispose();
    _playerController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.pop(
      context,
      CharacterRecord(
        name: _nameController.text.trim(),
        raceId: _raceId,
        mtgAlignment: MtgColor.values.where(_alignment.contains).toList(),
        playerName: _playerController.text.trim(),
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
          DropdownButtonFormField<int?>(
            initialValue: _raceId,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Race',
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('None'),
              ),
              for (final race in widget.races)
                DropdownMenuItem<int?>(
                  value: race.id,
                  child: Text(race.name),
                ),
            ],
            onChanged: (value) => setState(() => _raceId = value),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _playerController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Player name',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          Text(
            'MTG alignment',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final color in MtgColor.values)
                FilterChip(
                  label: Text(
                    color.label,
                    style: TextStyle(
                      color: Color(color.onColorArgb),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  selected: _alignment.contains(color),
                  backgroundColor: Color(color.colorArgb).withValues(alpha: 0.55),
                  selectedColor: Color(color.colorArgb),
                  checkmarkColor: Color(color.onColorArgb),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _alignment = {..._alignment, color};
                      } else {
                        _alignment = {..._alignment}..remove(color);
                      }
                    });
                  },
                ),
            ],
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
