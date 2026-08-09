import 'package:flutter/material.dart';

import '../../../../core/ui/catalog_image_slot.dart';
import '../../../../core/ui/markdown_form_field.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../../../world/characters/data/character_model.dart';
import '../../../world/characters/ui/mtg_mana_symbol.dart';
import '../data/race_model.dart';

Future<RaceRecord?> showRaceFormSheet(
  BuildContext context, {
  RaceRecord? initial,
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<RaceRecord>(
    context,
    title: editing ? 'Edit race' : 'New race',
    child: _RaceForm(
      initial: initial,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _RaceForm extends StatefulWidget {
  const _RaceForm({
    this.initial,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final RaceRecord? initial;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_RaceForm> createState() => _RaceFormState();
}

class _RaceFormState extends State<_RaceForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late final _imageUrlController =
      TextEditingController(text: widget.initial?.imageUrl ?? '');
  late List<String> _aliases = [...?widget.initial?.aliases];
  late Set<MtgColor> _alignment = {...?widget.initial?.mtgAlignment};

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final name = _nameController.text.trim();
    Navigator.pop(
      context,
      RaceRecord(
        name: name,
        description: _descriptionController.text.trim(),
        aliases: [
          for (final a in _aliases)
            if (a.trim().isNotEmpty &&
                a.trim().toLowerCase() != name.toLowerCase())
              a.trim(),
        ],
        mtgAlignment: MtgColor.values.where(_alignment.contains).toList(),
        imageUrl: normalizeCatalogImageUrl(_imageUrlController.text),
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
          'Other names this race is known by',
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
