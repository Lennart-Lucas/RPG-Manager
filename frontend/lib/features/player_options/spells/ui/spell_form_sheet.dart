import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/data/resource_models.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../data/spell_ai_template.dart';
import '../data/spell_model.dart';

Future<Spell?> showSpellFormSheet(
  BuildContext context, {
  Spell? initial,
  required List<CatalogItem> casterClasses,
  required List<CatalogItem> spellTags,
  required List<ResourceFile> resourceFiles,
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
  bool aiIntegrationEnabled = false,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<Spell>(
    context,
    title: editing ? 'Edit spell' : 'New spell',
    child: _SpellForm(
      initial: initial,
      casterClasses: casterClasses,
      spellTags: spellTags,
      resourceFiles: resourceFiles,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
      aiIntegrationEnabled: aiIntegrationEnabled,
    ),
  );
}

class _SpellForm extends StatefulWidget {
  const _SpellForm({
    this.initial,
    required this.casterClasses,
    required this.spellTags,
    required this.resourceFiles,
    this.searchLinks,
    this.loadAutoLinkTargets,
    this.aiIntegrationEnabled = false,
  });

  final Spell? initial;
  final List<CatalogItem> casterClasses;
  final List<CatalogItem> spellTags;
  final List<ResourceFile> resourceFiles;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;
  final bool aiIntegrationEnabled;

  @override
  State<_SpellForm> createState() => _SpellFormState();
}

class _SpellFormState extends State<_SpellForm> {
  static const _castingTimeOptions = <String>[
    'action',
    'bonus action',
    'reaction',
    'minute',
    'hour',
  ];

  static const _rangedDistances = <int>[30, 60, 90, 120, 150, 300, 500];

  final _formKey = GlobalKey<FormState>();

  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late final _reactionTriggerController = TextEditingController(
    text: widget.initial?.castingTime.reactionTrigger ?? '',
  );
  late final _castAmountController = TextEditingController(
    text: '${widget.initial?.castingTime.amount ?? 1}',
  );
  late final _materialDescriptionController = TextEditingController(
    text: widget.initial?.components.materialDescription ?? '',
  );
  late final _materialCostController = TextEditingController(
    text: widget.initial?.components.materialCostGp?.toString() ?? '',
  );
  late final _durationSpecialController = TextEditingController(
    text: widget.initial?.duration.special ?? '',
  );
  late final _higherLevelsController = TextEditingController(
    text: widget.initial?.higherLevels?.description ?? '',
  );
  late final _sourcePageController = TextEditingController(
    text: widget.initial?.sourcePage?.toString() ?? '',
  );

  late int _level = widget.initial?.level ?? 1;
  late SpellSchool _school = widget.initial?.school ?? SpellSchool.evocation;
  late String _castingTimeUnit = _resolveCastingTimeUnit(
    widget.initial?.castingTime.unit,
  );
  late String _rangeKey = _resolveRangeKey(widget.initial?.range);
  late bool _verbal = widget.initial?.components.verbal ?? true;
  late bool _somatic = widget.initial?.components.somatic ?? true;
  late bool _material = widget.initial?.components.material ?? false;
  late bool _materialConsumed =
      widget.initial?.components.materialConsumed ?? false;
  late DurationType _durationType =
      _resolveDurationType(widget.initial?.duration.type);
  late bool _concentration = widget.initial?.duration.concentration ?? false;
  late final Set<int> _classIds = {...(widget.initial?.classIds ?? const [])};
  late final Set<int> _tagIds = {...(widget.initial?.tagIds ?? const [])};
  late int? _sourceFileId = widget.initial?.sourceFileId;
  int _dropdownEpoch = 0;

  bool get _castingTimeAllowsCustomAmount =>
      _castingTimeUnit == 'minute' || _castingTimeUnit == 'hour';
  bool get _showAiTemplateActions => !widget.aiIntegrationEnabled;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _reactionTriggerController.dispose();
    _castAmountController.dispose();
    _materialDescriptionController.dispose();
    _materialCostController.dispose();
    _durationSpecialController.dispose();
    _higherLevelsController.dispose();
    _sourcePageController.dispose();
    super.dispose();
  }

  static String _resolveCastingTimeUnit(String? unit) {
    final normalized = unit?.trim().toLowerCase();
    if (normalized != null && _castingTimeOptions.contains(normalized)) {
      return normalized;
    }
    return 'action';
  }

  static DurationType _resolveDurationType(DurationType? type) {
    if (type != null && DurationType.values.contains(type)) {
      return type;
    }
    return DurationType.instantaneous;
  }

  static String _resolveRangeKey(SpellRange? range) {
    if (range == null) return 'self';
    switch (range.type) {
      case RangeType.self:
        return 'self';
      case RangeType.touch:
        return 'touch';
      case RangeType.ranged:
        final feet = range.distanceFeet;
        if (feet != null && _rangedDistances.contains(feet)) {
          return 'ranged:$feet';
        }
        return 'ranged:30';
      case RangeType.sight:
      case RangeType.unlimited:
      case RangeType.special:
        return 'self';
    }
  }

  SpellRange _buildRange() {
    if (_rangeKey == 'self') return const SpellRange.self();
    if (_rangeKey == 'touch') return const SpellRange.touch();
    final feet = int.parse(_rangeKey.split(':').last);
    return SpellRange(type: RangeType.ranged, distanceFeet: feet);
  }

  Future<void> _copyAiTemplate() async {
    await Clipboard.setData(
      ClipboardData(
        text: buildSpellAiClipboardText(
          casterClasses: widget.casterClasses,
          spellTags: widget.spellTags,
        ),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Template copied')),
    );
  }

  Future<void> _pasteAiTemplate() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }
    try {
      final template = parseSpellAiTemplate(
        clipboardText: text,
        casterClasses: widget.casterClasses,
        spellTags: widget.spellTags,
      );
      setState(() {
        _nameController.text = template.name;
        _level = template.level;
        _school = template.school;
        _castAmountController.text = '${template.castAmount}';
        _castingTimeUnit = template.castUnit;
        _reactionTriggerController.text = template.reactionTrigger ?? '';
        _rangeKey = template.rangeKey;
        _verbal = template.verbal;
        _somatic = template.somatic;
        _material = template.material;
        _materialDescriptionController.text =
            template.materialDescription ?? '';
        _materialCostController.text =
            template.materialCostGp?.toString() ?? '';
        _materialConsumed = template.materialConsumed;
        _durationType = template.durationType;
        _concentration = template.concentration;
        _durationSpecialController.text = template.durationSpecial ?? '';
        _classIds
          ..clear()
          ..addAll(template.classIds);
        _tagIds
          ..clear()
          ..addAll(template.tagIds);
        _descriptionController.text = template.description;
        _higherLevelsController.text = template.higherLevels;
        _sourcePageController.text = template.sourcePage?.toString() ?? '';
        _dropdownEpoch++;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Template applied')),
      );
    } on SpellAiTemplateException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not apply template')),
      );
    }
  }

  int? _parseInt(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  double? _parseDouble(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return double.tryParse(trimmed);
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    if (widget.casterClasses.isNotEmpty && _classIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one class')),
      );
      return;
    }

    final name = _nameController.text.trim();
    final id = widget.initial?.id ?? Spell.slugify(name);

    final range = _buildRange();

    final components = SpellComponents(
      verbal: _verbal,
      somatic: _somatic,
      material: _material,
      materialDescription: _material
          ? _materialDescriptionController.text.trim().nullIfEmpty
          : null,
      materialCostGp:
          _material ? _parseDouble(_materialCostController.text) : null,
      materialConsumed: _material && _materialConsumed,
    );

    final duration = SpellDuration(
      type: _durationType,
      concentration: _concentration,
      special: _durationType == DurationType.special
          ? _durationSpecialController.text.trim().nullIfEmpty
          : null,
    );

    final higherDesc = _higherLevelsController.text.trim();
    final higherLevels =
        higherDesc.isEmpty ? null : SpellScaling(description: higherDesc);

    final classIds = _classIds.toList()..sort();
    final tagIds = _tagIds.toList()..sort();

    final spell = Spell(
      id: id,
      name: name,
      level: _level,
      school: _school,
      castingTime: CastingTime(
        amount: _castingTimeAllowsCustomAmount
            ? (_parseInt(_castAmountController.text) ?? 1)
            : 1,
        unit: _castingTimeUnit,
        reactionTrigger: _castingTimeUnit == 'reaction'
            ? _reactionTriggerController.text.trim().nullIfEmpty
            : null,
      ),
      range: range,
      components: components,
      duration: duration,
      classIds: classIds,
      tagIds: tagIds,
      description: _descriptionController.text.trim(),
      higherLevels: higherLevels,
      damage: widget.initial?.damage,
      savingThrow: widget.initial?.savingThrow ?? SavingThrowAbility.none,
      attackType: widget.initial?.attackType ?? SpellAttackType.none,
      sourceFileId: _sourceFileId,
      sourcePage: _parseInt(_sourcePageController.text),
    );

    Navigator.pop(context, spell);
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

  Widget _schoolDropdownItem(SpellSchool school) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Center(child: school.buildIcon(size: 18)),
        ),
        const SizedBox(width: 8),
        Text(school.label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _durationType = _resolveDurationType(_durationType);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _section('Basics'),
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
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: ValueKey('level-$_dropdownEpoch'),
                  initialValue: _level,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Level',
                  ),
                  items: [
                    for (var level = 0; level <= 9; level++)
                      DropdownMenuItem(
                        value: level,
                        child: Text(
                          level == 0 ? 'Cantrip' : 'Level $level',
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _level = value);
                  },
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: DropdownButtonFormField<SpellSchool>(
                  key: ValueKey('school-$_dropdownEpoch'),
                  initialValue: _school,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'School',
                  ),
                  items: [
                    for (final school in SpellSchool.values)
                      DropdownMenuItem(
                        value: school,
                        child: _schoolDropdownItem(school),
                      ),
                  ],
                  selectedItemBuilder: (context) {
                    return [
                      for (final school in SpellSchool.values)
                        _schoolDropdownItem(school),
                    ];
                  },
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _school = value);
                  },
                ),
              ),
            ],
          ),
          _section('Casting time'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _castAmountController,
                  enabled: _castingTimeAllowsCustomAmount,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Amount',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (!_castingTimeAllowsCustomAmount) return null;
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    final amount = int.tryParse(value.trim());
                    if (amount == null || amount < 1) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('cast-unit-$_dropdownEpoch'),
                  initialValue: _castingTimeUnit,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Unit',
                  ),
                  items: [
                    for (final option in _castingTimeOptions)
                      DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      _castingTimeUnit = value;
                      if (!_castingTimeAllowsCustomAmount) {
                        _castAmountController.text = '1';
                      } else if (_castAmountController.text.trim().isEmpty) {
                        _castAmountController.text = '1';
                      }
                      if (_castingTimeUnit != 'reaction') {
                        _reactionTriggerController.clear();
                      }
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _reactionTriggerController,
            enabled: _castingTimeUnit == 'reaction',
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Reaction trigger',
              hintText: 'Optional',
            ),
          ),
          _section('Range'),
          DropdownButtonFormField<String>(
            key: ValueKey('range-$_dropdownEpoch'),
            initialValue: _rangeKey,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Range',
            ),
            items: [
              const DropdownMenuItem(value: 'self', child: Text('Self')),
              const DropdownMenuItem(value: 'touch', child: Text('Touch')),
              for (final feet in _rangedDistances)
                DropdownMenuItem(
                  value: 'ranged:$feet',
                  child: Text('$feet feet'),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _rangeKey = value);
            },
          ),
          _section('Components'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('Verbal (V)'),
                selected: _verbal,
                onSelected: (selected) => setState(() => _verbal = selected),
              ),
              FilterChip(
                label: const Text('Somatic (S)'),
                selected: _somatic,
                onSelected: (selected) => setState(() => _somatic = selected),
              ),
              FilterChip(
                label: const Text('Material (M)'),
                selected: _material,
                onSelected: (selected) {
                  setState(() {
                    _material = selected;
                    if (!selected) {
                      _materialDescriptionController.clear();
                      _materialCostController.clear();
                      _materialConsumed = false;
                    }
                  });
                },
              ),
            ],
          ),
          if (_material) ...[
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            TextFormField(
              controller: _materialDescriptionController,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Material description',
              ),
            ),
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            TextFormField(
              controller: _materialCostController,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Material cost (gp)',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Material consumed'),
              value: _materialConsumed,
              onChanged: (value) => setState(() => _materialConsumed = value),
            ),
          ],
          _section('Duration'),
          DropdownButtonFormField<DurationType>(
            key: ValueKey('duration-$_dropdownEpoch-$_durationType'),
            initialValue: _durationType,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Duration',
            ),
            items: [
              for (final type in DurationType.values)
                DropdownMenuItem(value: type, child: Text(type.label)),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _durationType = value;
                if (_durationType != DurationType.special) {
                  _durationSpecialController.clear();
                }
              });
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Concentration'),
            value: _concentration,
            onChanged: (value) => setState(() => _concentration = value),
          ),
          if (_durationType == DurationType.special) ...[
            TextFormField(
              controller: _durationSpecialController,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Special duration',
              ),
              validator: (value) {
                if (_durationType != DurationType.special) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }
                return null;
              },
            ),
          ],
          _section('Classes'),
          if (widget.casterClasses.isEmpty)
            Text(
              'Add spellcaster classes first',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final casterClass in widget.casterClasses)
                  FilterChip(
                    label: Text(casterClass.name),
                    selected: _classIds.contains(casterClass.id),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _classIds.add(casterClass.id);
                        } else {
                          _classIds.remove(casterClass.id);
                        }
                      });
                    },
                  ),
              ],
            ),
          _section('Spell tags'),
          if (widget.spellTags.isEmpty)
            Text(
              'Add spell tags first',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final tag in widget.spellTags)
                  FilterChip(
                    label: Text(tag.name),
                    selected: _tagIds.contains(tag.id),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _tagIds.add(tag.id);
                        } else {
                          _tagIds.remove(tag.id);
                        }
                      });
                    },
                  ),
              ],
            ),
          _section('Description'),
          MarkdownFormField(
            controller: _descriptionController,
            label: 'Description',
            minLines: 4,
            maxLines: 10,
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Description is required';
              }
              return null;
            },
          ),
          _section('At higher levels'),
          MarkdownFormField(
            controller: _higherLevelsController,
            label: 'Higher-level text',
            minLines: 2,
            maxLines: 6,
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
          if (_showAiTemplateActions)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyAiTemplate,
                    icon: const Icon(Icons.copy_outlined, size: 18),
                    label: const Text('Copy template'),
                  ),
                ),
                const SizedBox(width: ResourceFormStyles.fieldSpacing),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pasteAiTemplate,
                    icon: const Icon(Icons.content_paste_outlined, size: 18),
                    label: const Text('Paste template'),
                  ),
                ),
                const SizedBox(width: ResourceFormStyles.fieldSpacing),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(widget.initial == null ? 'Create' : 'Save'),
                  ),
                ),
              ],
            )
          else
            FilledButton(
              onPressed: _submit,
              child: Text(widget.initial == null ? 'Create' : 'Save'),
            ),
        ],
      ),
    );
  }
}

extension on String {
  String? get nullIfEmpty {
    final trimmed = trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
