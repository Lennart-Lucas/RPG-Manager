import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../dm_tools/resources/data/resource_models.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/item_model.dart';

Future<Item?> showItemFormSheet(
  BuildContext context, {
  Item? initial,
  required List<ResourceFile> resourceFiles,
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<Item>(
    context,
    title: editing ? 'Edit item' : 'New item',
    child: _ItemForm(
      initial: initial,
      resourceFiles: resourceFiles,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _ItemForm extends StatefulWidget {
  const _ItemForm({
    this.initial,
    required this.resourceFiles,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final Item? initial;
  final List<ResourceFile> resourceFiles;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  final _formKey = GlobalKey<FormState>();

  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late final _typeReferenceController =
      TextEditingController(text: widget.initial?.typeReference ?? '');
  late final _sourcePageController = TextEditingController(
    text: widget.initial?.sourcePage?.toString() ?? '',
  );

  late ItemType _itemType = widget.initial?.itemType ?? ItemType.equipment;
  late ItemRarity _rarity = widget.initial?.rarity ?? ItemRarity.common;
  late bool _magic = widget.initial?.magic ?? false;
  late bool _consumable = widget.initial?.consumable ?? false;
  late bool _requiresAttunement = widget.initial?.requiresAttunement ?? false;
  late int? _sourceFileId = widget.initial?.sourceFileId;

  bool get _showTypeReference =>
      _itemType == ItemType.armor || _itemType == ItemType.weapon;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _typeReferenceController.dispose();
    _sourcePageController.dispose();
    super.dispose();
  }

  int? _parseInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final name = _nameController.text.trim();
    final typeReference = _showTypeReference
        ? _typeReferenceController.text.trim()
        : '';

    final item = Item(
      id: widget.initial?.id ?? Item.slugify(name),
      name: name,
      description: _descriptionController.text.trim(),
      itemType: _itemType,
      rarity: _rarity,
      magic: _magic,
      consumable: _consumable,
      requiresAttunement: _magic && _requiresAttunement,
      typeReference: typeReference,
      sourceFileId: _sourceFileId,
      sourcePage: _parseInt(_sourcePageController.text),
    );

    Navigator.pop(context, item);
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section('Item'),
          TextFormField(
            controller: _nameController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Name',
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: widget.initial == null,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          DropdownButtonFormField<ItemType>(
            initialValue: _itemType,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Item type',
            ),
            items: [
              for (final type in ItemType.values)
                DropdownMenuItem(
                  value: type,
                  child: Text(type.label),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _itemType = value;
                if (!_showTypeReference) {
                  _typeReferenceController.clear();
                }
              });
            },
          ),
          if (_showTypeReference) ...[
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            TextFormField(
              controller: _typeReferenceController,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Reference',
                hintText: 'e.g. [[items/example|Longsword]]',
              ),
              minLines: 1,
              maxLines: 4,
            ),
          ],
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          DropdownButtonFormField<ItemRarity>(
            initialValue: _rarity,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Rarity',
            ),
            items: [
              for (final rarity in ItemRarity.values)
                DropdownMenuItem(
                  value: rarity,
                  child: Text(rarity.label),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _rarity = value);
            },
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Magic'),
            value: _magic,
            onChanged: (value) {
              setState(() {
                _magic = value;
                if (!value) _requiresAttunement = false;
              });
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Requires attunement'),
            value: _requiresAttunement,
            onChanged: _magic
                ? (value) => setState(() => _requiresAttunement = value)
                : null,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Consumable'),
            value: _consumable,
            onChanged: (value) => setState(() => _consumable = value),
          ),
          _section('Description'),
          MarkdownFormField(
            controller: _descriptionController,
            label: 'Description',
            hintText:
                'Describe the item ([[${CatalogKind.items.apiValue}/name]])',
            minLines: 4,
            maxLines: 10,
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int?>(
                  initialValue: _sourceFileId,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Source',
                    helperText: widget.resourceFiles.isEmpty
                        ? 'No resource files available'
                        : null,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None'),
                    ),
                    for (final file in widget.resourceFiles)
                      DropdownMenuItem<int?>(
                        value: file.id,
                        child: Text(file.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _sourceFileId = value),
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: TextFormField(
                  controller: _sourcePageController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Page',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
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
