import 'package:flutter/material.dart';

import '../../../../core/ui/catalog_image_slot.dart';
import '../../../../core/ui/markdown_form_field.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../../ui/overview_sections.dart';
import '../../ui/overview_sections_editor.dart';
import '../data/character_model.dart';
import 'mtg_mana_symbol.dart';

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
  late final _imageUrlController =
      TextEditingController(text: widget.initial?.imageUrl ?? '');
  late int? _raceId = widget.initial?.raceId;
  late Set<MtgColor> _alignment = {...?widget.initial?.mtgAlignment};
  late List<String> _aliases = [...?widget.initial?.aliases];
  late List<OverviewSection> _overviewSections = [
    ...?widget.initial?.overviewSections,
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _playerController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.pop(
      context,
      CharacterRecord(
        name: _nameController.text.trim(),
        aliases: [
          for (final a in _aliases)
            if (a.trim().isNotEmpty &&
                a.trim().toLowerCase() !=
                    _nameController.text.trim().toLowerCase())
              a.trim(),
        ],
        raceId: _raceId,
        mtgAlignment: MtgColor.values.where(_alignment.contains).toList(),
        playerName: _playerController.text.trim(),
        description: _descriptionController.text.trim(),
        imageUrl: normalizeCatalogImageUrl(_imageUrlController.text),
        overviewSections: normalizeOverviewSections(_overviewSections),
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
          _AliasesEditor(
            values: _aliases,
            onChanged: (next) => setState(() => _aliases = next),
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
            'Alignment',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick one or more mana colors',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in MtgColor.values)
                Tooltip(
                  message: color.displayName,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () {
                      setState(() {
                        if (_alignment.contains(color)) {
                          _alignment = {..._alignment}..remove(color);
                        } else {
                          _alignment = {..._alignment, color};
                        }
                      });
                    },
                    child: MtgManaSymbol(
                      color: color,
                      size: 40,
                      selected: _alignment.contains(color),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _imageUrlController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Image URL',
              hintText: 'https://… or Google Drive share link',
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
            validator: validateOptionalHttpUrl,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          OverviewSectionsEditor(
            sections: _overviewSections,
            onChanged: (next) => setState(() => _overviewSections = next),
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
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

class _AliasesEditor extends StatefulWidget {
  const _AliasesEditor({
    required this.values,
    required this.onChanged,
  });

  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_AliasesEditor> createState() => _AliasesEditorState();
}

class _AliasesEditorState extends State<_AliasesEditor> {
  late final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final exists = widget.values.any(
      (v) => v.toLowerCase() == text.toLowerCase(),
    );
    if (!exists) {
      widget.onChanged([...widget.values, text]);
    }
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Aliases',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Other names this character is known by',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        if (widget.values.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < widget.values.length; i++)
                InputChip(
                  label: Text(widget.values[i]),
                  onDeleted: () {
                    final next = [...widget.values]..removeAt(i);
                    widget.onChanged(next);
                  },
                ),
            ],
          ),
        if (widget.values.isNotEmpty) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Add alias',
                ),
                textCapitalization: TextCapitalization.words,
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              tooltip: 'Add alias',
              onPressed: _add,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}
