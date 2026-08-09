import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../../core/ui/multi_picklist_sheet.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../dm_tools/pdf_extract/data/anthropic_key_store.dart';
import '../../../dm_tools/pdf_extract/data/extract_api.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../../../world/ui/world_form_helpers.dart';
import '../data/class_model.dart';
import 'class_ai_process_pane.dart';
import 'class_features_editor.dart';

Future<ClassRecord?> showClassFormSheet(
  BuildContext context, {
  required AuthController auth,
  ClassRecord? initial,
  List<String> skillNames = const [],
  CatalogLinkSearch? searchLinks,
  CatalogAutoLinkLoader? loadAutoLinkTargets,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<ClassRecord>(
    context,
    title: editing ? 'Edit class' : 'New class',
    child: _ClassForm(
      auth: auth,
      initial: initial,
      skillNames: skillNames,
      searchLinks: searchLinks,
      loadAutoLinkTargets: loadAutoLinkTargets,
    ),
  );
}

class _ClassForm extends StatefulWidget {
  const _ClassForm({
    required this.auth,
    this.initial,
    required this.skillNames,
    this.searchLinks,
    this.loadAutoLinkTargets,
  });

  final AuthController auth;
  final ClassRecord? initial;
  final List<String> skillNames;
  final CatalogLinkSearch? searchLinks;
  final CatalogAutoLinkLoader? loadAutoLinkTargets;

  @override
  State<_ClassForm> createState() => _ClassFormState();
}

class _ClassFormState extends State<_ClassForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _extractApi = ExtractApi();
  final _keyStore = AnthropicKeyStore();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _descriptionController =
      TextEditingController(text: widget.initial?.description ?? '');
  late final _hitDieController =
      TextEditingController(text: widget.initial?.hitDie ?? 'd8');
  late final _skillCountController = TextEditingController(
    text: '${widget.initial?.skillChoiceCount ?? 0}',
  );
  final _processController = TextEditingController();

  late Set<String> _primaryAbilities = {
    ...?widget.initial?.primaryAbilities,
  };
  late Set<String> _savingThrows = {
    ...?widget.initial?.savingThrowProficiencies,
  };
  late List<String> _armor = [...?widget.initial?.armorProficiencies];
  late List<String> _weapons = [...?widget.initial?.weaponProficiencies];
  late List<String> _tools = [...?widget.initial?.toolProficiencies];
  late List<String> _skillChoices = [...?widget.initial?.skillChoices];
  late List<ClassFeature> _features = flattenClassFeaturesByLevel(
    widget.initial?.featuresByLevel ?? const {},
  );
  late int _subclassChosenAtLevel =
      widget.initial?.subclassChosenAtLevel.clamp(1, 20) ?? 3;
  late bool _hasSpellcasting = widget.initial?.isCaster ?? false;
  late String _castAbility =
      widget.initial?.spellcasting?.ability ?? 'INT';
  late SpellcastingType _castType =
      widget.initial?.spellcasting?.type ?? SpellcastingType.full;
  late bool _preparesSpells =
      widget.initial?.spellcasting?.preparesSpells ?? true;
  late Map<int, SpellSlotTable> _slotsByLevel = {
    ...?widget.initial?.spellcasting?.slotsByLevel,
  };

  TabController? _tabController;
  bool _processing = false;
  int _formEpoch = 0;

  bool get _showProcessTab => widget.auth.user?.aiIntegration == true;

  @override
  void initState() {
    super.initState();
    if (_showProcessTab) {
      _tabController = TabController(length: 2, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _hitDieController.dispose();
    _skillCountController.dispose();
    _processController.dispose();
    super.dispose();
  }

  Map<int, List<ClassFeature>> _groupFeatures(List<ClassFeature> features) {
    return groupClassFeaturesByLevel(features);
  }

  ClassRecord _snapshot() {
    final skillCount = int.tryParse(_skillCountController.text.trim()) ?? 0;
    SpellcastingInfo? casting;
    if (_hasSpellcasting) {
      casting = SpellcastingInfo(
        ability: _castAbility,
        type: _castType == SpellcastingType.none
            ? SpellcastingType.full
            : _castType,
        slotsByLevel: Map<int, SpellSlotTable>.from(_slotsByLevel),
        preparesSpells: _preparesSpells,
      );
    }
    return ClassRecord(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      hitDie: _hitDieController.text.trim().isEmpty
          ? 'd8'
          : _hitDieController.text.trim(),
      primaryAbilities:
          kClassAbilityLabels.where(_primaryAbilities.contains).toList(),
      savingThrowProficiencies:
          kClassAbilityLabels.where(_savingThrows.contains).toList(),
      armorProficiencies: _armor,
      weaponProficiencies: _weapons,
      toolProficiencies: _tools,
      skillChoiceCount: skillCount.clamp(0, 20),
      skillChoices: _skillChoices,
      featuresByLevel: _groupFeatures(_features),
      subclassChosenAtLevel: _subclassChosenAtLevel,
      spellcasting: casting,
      isCaster: _hasSpellcasting,
    );
  }

  void _applyRecord(ClassRecord record) {
    _nameController.text = record.name;
    _descriptionController.text = record.description;
    _hitDieController.text = record.hitDie;
    _skillCountController.text = '${record.skillChoiceCount}';
    setState(() {
      _formEpoch++;
      _primaryAbilities = {...record.primaryAbilities};
      _savingThrows = {...record.savingThrowProficiencies};
      _armor = [...record.armorProficiencies];
      _weapons = [...record.weaponProficiencies];
      _tools = [...record.toolProficiencies];
      _skillChoices = [...record.skillChoices];
      _features = flattenClassFeaturesByLevel(record.featuresByLevel);
      _subclassChosenAtLevel = record.subclassChosenAtLevel.clamp(1, 20);
      _hasSpellcasting = record.isCaster;
      _castAbility = record.spellcasting?.ability ?? 'INT';
      _castType = record.spellcasting?.type ?? SpellcastingType.full;
      _preparesSpells = record.spellcasting?.preparesSpells ?? true;
      _slotsByLevel = {...?record.spellcasting?.slotsByLevel};
    });
  }

  Future<void> _process() async {
    final prompt = _processController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a prompt or paste source text')),
      );
      return;
    }
    final apiKey = (await _keyStore.read())?.trim() ?? '';
    if (apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your Anthropic API key in Preferences.'),
        ),
      );
      return;
    }
    setState(() => _processing = true);
    try {
      final token = await widget.auth.requireAccessToken();
      if (token == null) return;
      final payload = await _extractApi.processClass(
        accessToken: token,
        anthropicApiKey: apiKey,
        kind: 'classes',
        prompt: prompt,
        current: _snapshot().toJson(),
      );
      if (!mounted) return;
      _applyRecord(ClassRecord.fromJson(payload));
      _tabController?.animateTo(0);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not process class')),
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.pop(context, _snapshot());
  }

  Future<void> _pickSkills() async {
    final options = [
      for (final name in widget.skillNames)
        PicklistOption(id: name, label: name),
    ];
    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No skills in catalog yet')),
      );
      return;
    }
    final selected = await showMultiPicklistSheet(
      context,
      title: 'Skill choices',
      options: options,
      selected: _skillChoices.toSet(),
    );
    if (selected == null) return;
    setState(() {
      _skillChoices = [
        for (final name in widget.skillNames)
          if (selected.contains(name)) name,
        for (final name in selected)
          if (!widget.skillNames.contains(name)) name,
      ];
    });
  }

  Widget _buildEditFields(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        key: ValueKey('class-edit-$_formEpoch'),
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
          MarkdownFormField(
            controller: _descriptionController,
            label: 'Description',
            minLines: 4,
            maxLines: 12,
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _hitDieController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Hit die',
              hintText: 'd8',
            ),
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          Text(
            'Primary abilities',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _AbilityChipRow(
            selected: _primaryAbilities,
            onChanged: (next) => setState(() => _primaryAbilities = next),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          Text(
            'Saving throw proficiencies',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          _AbilityChipRow(
            selected: _savingThrows,
            onChanged: (next) => setState(() => _savingThrows = next),
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          _StringListEditor(
            label: 'Armor proficiencies',
            values: _armor,
            onChanged: (next) => setState(() => _armor = next),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          _StringListEditor(
            label: 'Weapon proficiencies',
            values: _weapons,
            onChanged: (next) => setState(() => _weapons = next),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          _StringListEditor(
            label: 'Tool proficiencies',
            values: _tools,
            onChanged: (next) => setState(() => _tools = next),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _skillCountController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Skill choice count',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          catalogMultiPickTile(
            context: context,
            label: 'Skill choices',
            labels: _skillChoices,
            onTap: _pickSkills,
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          ClassFeaturesEditor(
            title: 'Class features',
            features: _features,
            searchLinks: widget.searchLinks,
            loadAutoLinkTargets: widget.loadAutoLinkTargets,
            onChanged: (next) => setState(() => _features = next),
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          Text(
            'Subclass selection',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _subclassChosenAtLevel,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Subclass chosen at level',
              helperText: 'Subclasses are managed as their own records',
            ),
            items: [
              for (var level = 1; level <= 20; level++)
                DropdownMenuItem(value: level, child: Text('$level')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _subclassChosenAtLevel = value);
            },
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Spellcaster'),
            subtitle: const Text('Appears on spell class lists'),
            value: _hasSpellcasting,
            onChanged: (value) => setState(() => _hasSpellcasting = value),
          ),
          if (_hasSpellcasting) ...[
            DropdownButtonFormField<String>(
              initialValue: _castAbility,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Spellcasting ability',
              ),
              items: [
                for (final a in kClassAbilityLabels)
                  DropdownMenuItem(value: a, child: Text(a)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _castAbility = value);
              },
            ),
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            DropdownButtonFormField<SpellcastingType>(
              initialValue: _castType == SpellcastingType.none
                  ? SpellcastingType.full
                  : _castType,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Casting type',
              ),
              items: [
                for (final t in SpellcastingType.values)
                  if (t != SpellcastingType.none)
                    DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _castType = value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Prepares spells'),
              subtitle: Text(
                _preparesSpells ? 'Prepared caster' : 'Known spells',
              ),
              value: _preparesSpells,
              onChanged: (value) => setState(() => _preparesSpells = value),
            ),
            _SpellSlotsEditor(
              slotsByLevel: _slotsByLevel,
              onChanged: (next) => setState(() => _slotsByLevel = next),
            ),
          ],
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.initial == null ? 'Create' : 'Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showProcessTab || _tabController == null) {
      return _buildEditFields(context);
    }
    return AnimatedBuilder(
      animation: _tabController!,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Edit'),
                Tab(text: 'Process'),
              ],
            ),
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            if (_tabController!.index == 0)
              _buildEditFields(context)
            else
              ClassAiProcessPane(
                controller: _processController,
                processing: _processing,
                onProcess: _process,
              ),
          ],
        );
      },
    );
  }
}

class _AbilityChipRow extends StatelessWidget {
  const _AbilityChipRow({
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final ability in kClassAbilityLabels)
          FilterChip(
            label: Text(ability),
            selected: selected.contains(ability),
            onSelected: (value) {
              final next = {...selected};
              if (value) {
                next.add(ability);
              } else {
                next.remove(ability);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}

class _StringListEditor extends StatefulWidget {
  const _StringListEditor({
    required this.label,
    required this.values,
    required this.onChanged,
  });

  final String label;
  final List<String> values;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_StringListEditor> createState() => _StringListEditorState();
}

class _StringListEditorState extends State<_StringListEditor> {
  late final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _add() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (widget.values.contains(text)) {
      _controller.clear();
      return;
    }
    widget.onChanged([...widget.values, text]);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 8),
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
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Add',
                ),
                onSubmitted: (_) => _add(),
              ),
            ),
            IconButton(
              onPressed: _add,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }
}

class _SpellSlotsEditor extends StatelessWidget {
  const _SpellSlotsEditor({
    required this.slotsByLevel,
    required this.onChanged,
  });

  final Map<int, SpellSlotTable> slotsByLevel;
  final ValueChanged<Map<int, SpellSlotTable>> onChanged;

  @override
  Widget build(BuildContext context) {
    final levels = slotsByLevel.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Spell slots by level',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        for (final level in levels)
          Card(
            margin: const EdgeInsets.only(top: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Character level $level',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          final next = Map<int, SpellSlotTable>.from(
                            slotsByLevel,
                          )..remove(level);
                          onChanged(next);
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue:
                              '${slotsByLevel[level]?.cantripsKnown ?? 0}',
                          decoration: ResourceFormStyles.inputDecoration(
                            context,
                            label: 'Cantrips',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            final table = slotsByLevel[level] ??
                                const SpellSlotTable();
                            final next = Map<int, SpellSlotTable>.from(
                              slotsByLevel,
                            );
                            next[level] = table.copyWith(
                              cantripsKnown: int.tryParse(value) ?? 0,
                            );
                            onChanged(next);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue:
                              '${slotsByLevel[level]?.spellsKnownOrPrepared ?? 0}',
                          decoration: ResourceFormStyles.inputDecoration(
                            context,
                            label: 'Known/prepared',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (value) {
                            final table = slotsByLevel[level] ??
                                const SpellSlotTable();
                            final next = Map<int, SpellSlotTable>.from(
                              slotsByLevel,
                            );
                            next[level] = table.copyWith(
                              spellsKnownOrPrepared: int.tryParse(value) ?? 0,
                            );
                            onChanged(next);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: (slotsByLevel[level]?.slotsByCircle ??
                            const <int>[])
                        .join(', '),
                    decoration: ResourceFormStyles.inputDecoration(
                      context,
                      label: 'Slots by circle',
                      hintText: '4, 2, 0',
                    ),
                    onChanged: (value) {
                      final slots = <int>[
                        for (final part in value.split(','))
                          if (part.trim().isNotEmpty)
                            int.tryParse(part.trim()) ?? 0,
                      ];
                      final table =
                          slotsByLevel[level] ?? const SpellSlotTable();
                      final next =
                          Map<int, SpellSlotTable>.from(slotsByLevel);
                      next[level] = table.copyWith(slotsByCircle: slots);
                      onChanged(next);
                    },
                  ),
                ],
              ),
            ),
          ),
        TextButton.icon(
          onPressed: () {
            var nextLevel = 1;
            while (slotsByLevel.containsKey(nextLevel) && nextLevel <= 20) {
              nextLevel++;
            }
            if (nextLevel > 20) return;
            onChanged({
              ...slotsByLevel,
              nextLevel: const SpellSlotTable(),
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Add slot row'),
        ),
      ],
    );
  }
}
