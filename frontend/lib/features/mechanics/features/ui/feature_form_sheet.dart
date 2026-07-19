import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../../../world/creatures/data/scaler_math.dart';
import '../data/feature_ep.dart';
import '../data/feature_model.dart';
import '../data/feature_text.dart';
import 'monstrous_trait_picker_sheet.dart';

Future<MonsterFeature?> showFeatureFormSheet(
  BuildContext context, {
  MonsterFeature? initial,
  ScalerRank? creatureRank,
  num? creatureThreat,
  int? scalerDmg,
  int? creatureLevel,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<MonsterFeature>(
    context,
    title: editing ? 'Edit feature' : 'New feature',
    child: _FeatureForm(
      initial: initial,
      creatureRank: creatureRank,
      creatureThreat: creatureThreat,
      scalerDmg: scalerDmg,
      creatureLevel: creatureLevel,
    ),
  );
}

class _FeatureForm extends StatefulWidget {
  const _FeatureForm({
    this.initial,
    this.creatureRank,
    this.creatureThreat,
    this.scalerDmg,
    this.creatureLevel,
  });

  final MonsterFeature? initial;
  final ScalerRank? creatureRank;
  final num? creatureThreat;
  final int? scalerDmg;
  final int? creatureLevel;

  @override
  State<_FeatureForm> createState() => _FeatureFormState();
}

class _FeatureFormState extends State<_FeatureForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _textController =
      TextEditingController(text: widget.initial?.text ?? '');
  late final _limitationValueController = TextEditingController(
    text: widget.initial?.limitation.value ?? '',
  );
  late final _limitationTriggerController = TextEditingController(
    text: widget.initial?.limitation.recoveryTrigger ?? '',
  );
  late final _rangeTemplateController = TextEditingController(
    text: widget.initial?.range.template ?? '',
  );
  late final _rangeDistanceController = TextEditingController(
    text: widget.initial?.range.distance ?? '',
  );
  late final _targetAllianceController = TextEditingController(
    text: widget.initial?.targets.alliance ?? '',
  );
  late final _targetAlignmentController = TextEditingController(
    text: widget.initial?.targets.alignment ?? '',
  );
  late final _targetCategoryController = TextEditingController(
    text: widget.initial?.targets.creatureCategory ?? '',
  );
  late final _limitedCountController = TextEditingController(
    text: widget.initial?.targets.limitedCount?.toString() ?? '',
  );
  late final _deferralTurnsController = TextEditingController(
    text: widget.initial?.deferral.turns?.toString() ?? '',
  );

  late FeatureCategory _category =
      widget.initial?.category ?? FeatureCategory.trait;
  late FeatureRarity _rarity =
      widget.initial?.rarity ?? FeatureRarity.common;
  late FeatureActivation _activation =
      widget.initial?.activationTime ?? FeatureActivation.none;
  late bool _hasRequirement = widget.initial?.hasRequirement ?? false;
  late FeatureLimitationType _limitationType =
      widget.initial?.limitation.type ?? FeatureLimitationType.none;
  late FeatureDefence? _defence = widget.initial?.defence;
  late FeatureRangeCategory _rangeCategory =
      widget.initial?.range.category ?? FeatureRangeCategory.self;
  late FeatureTargetQuantity _targetQuantity =
      widget.initial?.targets.quantity ?? FeatureTargetQuantity.none;
  late FeatureTargetCategory _targetCategory =
      widget.initial?.targets.category ?? FeatureTargetCategory.target;
  late FeatureDeferralType _deferralType =
      widget.initial?.deferral.type ?? FeatureDeferralType.none;
  late List<FeatureEffect> _effects = [
    ...?widget.initial?.effects.map((e) => e),
  ];
  late bool _textOverride = widget.initial?.textOverride ?? false;
  late FeatureBudgetSlot? _budgetSlot = widget.initial?.budgetSlot;

  bool get _isAttackOrUtility =>
      _category == FeatureCategory.attack ||
      _category == FeatureCategory.utility;

  bool get _showLimitation =>
      _rarity == FeatureRarity.uncommon || _rarity == FeatureRarity.rare;

  bool get _showDeferral =>
      _rarity == FeatureRarity.uncommon || _rarity == FeatureRarity.rare;

  FeatureDeferral get _deferral => FeatureDeferral(
        type: _deferralType,
        turns: int.tryParse(_deferralTurnsController.text.trim()),
      );

  MonsterFeature _buildFeature({bool forValidation = false}) {
    final limitedCount = int.tryParse(_limitedCountController.text.trim());
    final maxLimited = widget.creatureLevel == null
        ? null
        : limitedTargetMaxForLevel(widget.creatureLevel!);

    return MonsterFeature(
      id: widget.initial?.id ?? '',
      name: _nameController.text.trim(),
      category: _category,
      rarity: _rarity,
      activationTime: _activation,
      hasRequirement: _hasRequirement,
      limitation: FeatureLimitation(
        type: _limitationType,
        value: _limitationValueController.text.trim().isEmpty
            ? null
            : _limitationValueController.text.trim(),
        recoveryTrigger: _limitationTriggerController.text.trim().isEmpty
            ? null
            : _limitationTriggerController.text.trim(),
      ),
      defence: _isAttackOrUtility ? _defence : null,
      range: FeatureRange(
        category: _rangeCategory,
        template: _rangeTemplateController.text.trim(),
        distance: _rangeDistanceController.text.trim(),
      ),
      targets: FeatureTargets(
        quantity: _targetQuantity,
        limitedCount: _targetQuantity == FeatureTargetQuantity.limited
            ? (limitedCount ?? maxLimited ?? 2)
            : null,
        category: _targetCategory,
        alliance: _targetAllianceController.text.trim().isEmpty
            ? null
            : _targetAllianceController.text.trim(),
        alignment: _targetAlignmentController.text.trim().isEmpty
            ? null
            : _targetAlignmentController.text.trim(),
        creatureCategory: _targetCategoryController.text.trim().isEmpty
            ? null
            : _targetCategoryController.text.trim(),
      ),
      deferral: _deferral,
      effects: _isAttackOrUtility ? _effects : const [],
      text: _textController.text.trim(),
      textOverride: _textOverride,
      monstrousTraitId: widget.initial?.monstrousTraitId,
      budgetSlot: _budgetSlot,
      autoKey: widget.initial?.autoKey,
      effectPoints: forValidation
          ? availableEffectPoints(
              rarity: _rarity,
              activation: _activation,
              hasRequirement: _hasRequirement,
              deferral: _deferral,
            )
          : (widget.initial?.effectPoints ?? 1),
    );
  }

  FeatureEpValidation get _validation => validateFeatureEp(_buildFeature());

  @override
  void dispose() {
    _nameController.dispose();
    _textController.dispose();
    _limitationValueController.dispose();
    _limitationTriggerController.dispose();
    _rangeTemplateController.dispose();
    _rangeDistanceController.dispose();
    _targetAllianceController.dispose();
    _targetAlignmentController.dispose();
    _targetCategoryController.dispose();
    _limitedCountController.dispose();
    _deferralTurnsController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(FeatureCategory? value) {
    if (value == null) return;
    setState(() {
      _category = value;
      if (value == FeatureCategory.trait) {
        _activation = FeatureActivation.none;
        _defence = null;
        _effects = [];
        _rangeCategory = FeatureRangeCategory.self;
        _targetQuantity = FeatureTargetQuantity.none;
      }
    });
  }

  void _applyRankDefaults() {
    final rank = widget.creatureRank;
    if (rank == null) return;
    final lim = defaultLimitationForRank(
      rarity: _rarity,
      rank: rank,
      threat: widget.creatureThreat ?? 1,
    );
    setState(() {
      _limitationType = lim.type;
      _limitationValueController.text = lim.value ?? '';
      _limitationTriggerController.text = lim.recoveryTrigger ?? '';
    });
  }

  void _regenerateText() {
    final feature = _buildFeature();
    final text = generateFeatureText(feature, scalerDmg: widget.scalerDmg);
    setState(() {
      _textController.text = text;
      _textOverride = false;
    });
  }

  Future<void> _pickMonstrousTrait() async {
    final trait = await showMonstrousTraitPickerSheet(context);
    if (trait == null || !mounted) return;
    setState(() {
      _nameController.text = trait.name;
      _category = FeatureCategory.trait;
      _activation = FeatureActivation.none;
      _defence = null;
      _effects = [];
      _textController.text = trait.text;
      _textOverride = true;
      _budgetSlot = trait.budgetSlot;
    });
  }

  Future<void> _editEffect({FeatureEffect? initial, int? index}) async {
    final result = await showDialog<FeatureEffect>(
      context: context,
      builder: (ctx) => _EffectEditDialog(initial: initial),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index != null) {
        _effects = [..._effects]..[index] = result;
      } else if (_effects.length < 3) {
        _effects = [..._effects, result];
      }
    });
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final validation = _validation;
    if (!validation.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validation.message ?? 'Invalid EP budget')),
      );
      return;
    }

    final available = validation.available;
    final effects = [
      for (final e in _effects)
        e.copyWith(cost: computeEffectCost(e)),
    ];
    final feature = _buildFeature().copyWith(
      effectPoints: available,
      effects: _isAttackOrUtility ? effects : const [],
    );
    Navigator.pop(context, feature);
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
    final validation = _validation;
    final availableEp = validation.available;
    final spentEp = validation.spent;

    return PopScope(
      canPop: validation.ok,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || validation.ok) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validation.message ?? 'Fix EP budget before closing'),
          ),
        );
      },
      child: Form(
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
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            _section('Category'),
            DropdownButtonFormField<FeatureCategory>(
              initialValue: _category,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Category',
              ),
              items: [
                for (final c in FeatureCategory.values)
                  DropdownMenuItem(value: c, child: Text(c.label)),
              ],
              onChanged: _onCategoryChanged,
            ),
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            _section('Rarity & EP'),
            DropdownButtonFormField<FeatureRarity>(
              initialValue: _rarity,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Rarity',
              ),
              items: [
                for (final r in FeatureRarity.values)
                  DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _rarity = v);
              },
            ),
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            Text(
              'Available EP: $availableEp · Spent: $spentEp',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: validation.ok
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
            ),
            if (!validation.ok && validation.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  validation.message!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
                  ),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Has requirement'),
              value: _hasRequirement,
              onChanged: (v) => setState(() => _hasRequirement = v),
            ),
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            _section('Activation'),
            DropdownButtonFormField<FeatureActivation>(
              initialValue: _activation,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Activation',
              ),
              items: [
                for (final a in FeatureActivation.values)
                  DropdownMenuItem(
                    value: a,
                    enabled: _category != FeatureCategory.trait ||
                        a == FeatureActivation.none,
                    child: Text(a.label),
                  ),
              ],
              onChanged: _category == FeatureCategory.trait
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => _activation = v);
                    },
            ),
            if (_showLimitation) ...[
              const SizedBox(height: ResourceFormStyles.sectionSpacing),
              _section('Limitation'),
              DropdownButtonFormField<FeatureLimitationType>(
                initialValue: _limitationType,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Limitation type',
                ),
                items: [
                  for (final t in FeatureLimitationType.values)
                    DropdownMenuItem(value: t, child: Text(t.name)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _limitationType = v);
                },
              ),
              const SizedBox(height: ResourceFormStyles.fieldSpacing),
              TextFormField(
                controller: _limitationValueController,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Value',
                  hintText: 'Charges, recharge range, cooldown turns…',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: ResourceFormStyles.fieldSpacing),
              TextFormField(
                controller: _limitationTriggerController,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Recovery trigger',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (widget.creatureRank != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _applyRankDefaults,
                    child: const Text('Use rank defaults'),
                  ),
                ),
            ],
            if (_isAttackOrUtility) ...[
              const SizedBox(height: ResourceFormStyles.sectionSpacing),
              _section('Defence'),
              DropdownButtonFormField<FeatureDefence?>(
                initialValue: _defence,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Save / attack vs',
                ),
                items: [
                  const DropdownMenuItem<FeatureDefence?>(
                    value: null,
                    child: Text('None'),
                  ),
                  for (final d in FeatureDefence.values)
                    DropdownMenuItem(value: d, child: Text(d.label)),
                ],
                onChanged: (v) => setState(() => _defence = v),
              ),
              const SizedBox(height: ResourceFormStyles.sectionSpacing),
              _section('Range'),
              DropdownButtonFormField<FeatureRangeCategory>(
                initialValue: _rangeCategory,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Range category',
                ),
                items: [
                  for (final c in FeatureRangeCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.name)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _rangeCategory = v);
                },
              ),
              const SizedBox(height: ResourceFormStyles.fieldSpacing),
              TextFormField(
                controller: _rangeTemplateController,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Template',
                  hintText: 'cone, line, circle…',
                ),
              ),
              const SizedBox(height: ResourceFormStyles.fieldSpacing),
              TextFormField(
                controller: _rangeDistanceController,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Distance',
                  hintText: '60 ft., 15 ft. radius…',
                ),
              ),
              const SizedBox(height: ResourceFormStyles.sectionSpacing),
              _section('Targets'),
              DropdownButtonFormField<FeatureTargetQuantity>(
                initialValue: _targetQuantity,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Quantity',
                ),
                items: [
                  for (final q in FeatureTargetQuantity.values)
                    DropdownMenuItem(value: q, child: Text(q.name)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _targetQuantity = v);
                },
              ),
              if (_targetQuantity == FeatureTargetQuantity.limited) ...[
                const SizedBox(height: ResourceFormStyles.fieldSpacing),
                TextFormField(
                  controller: _limitedCountController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Limited count',
                    helperText: widget.creatureLevel == null
                        ? null
                        : 'Max ${limitedTargetMaxForLevel(widget.creatureLevel!)} at level ${widget.creatureLevel}',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
              const SizedBox(height: ResourceFormStyles.fieldSpacing),
              DropdownButtonFormField<FeatureTargetCategory>(
                initialValue: _targetCategory,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Target category',
                ),
                items: [
                  for (final c in FeatureTargetCategory.values)
                    DropdownMenuItem(value: c, child: Text(c.name)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _targetCategory = v);
                },
              ),
              const SizedBox(height: ResourceFormStyles.fieldSpacing),
              TextFormField(
                controller: _targetAllianceController,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Alliance filter',
                ),
              ),
              const SizedBox(height: ResourceFormStyles.fieldSpacing),
              TextFormField(
                controller: _targetAlignmentController,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Alignment filter',
                ),
              ),
              const SizedBox(height: ResourceFormStyles.fieldSpacing),
              TextFormField(
                controller: _targetCategoryController,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Creature category filter',
                ),
              ),
            ],
            if (_showDeferral) ...[
              const SizedBox(height: ResourceFormStyles.sectionSpacing),
              _section('Deferral'),
              DropdownButtonFormField<FeatureDeferralType>(
                initialValue: _deferralType,
                decoration: ResourceFormStyles.inputDecoration(
                  context,
                  label: 'Deferral type',
                ),
                items: [
                  for (final t in FeatureDeferralType.values)
                    DropdownMenuItem(value: t, child: Text(t.name)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _deferralType = v);
                },
              ),
              if (_deferralType != FeatureDeferralType.none) ...[
                const SizedBox(height: ResourceFormStyles.fieldSpacing),
                TextFormField(
                  controller: _deferralTurnsController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Turns',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
            if (_isAttackOrUtility) ...[
              const SizedBox(height: ResourceFormStyles.sectionSpacing),
              _section('Effects (${_effects.length}/3)'),
              for (var i = 0; i < _effects.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(_effects[i].type.name),
                    subtitle: Text(
                      'Cost: ${computeEffectCost(_effects[i])} EP · '
                      '${_effects[i].duration.name}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editEffect(
                            initial: _effects[i],
                            index: i,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() => _effects = [..._effects]..removeAt(i));
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _effects.length >= 3
                      ? null
                      : () => _editEffect(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add effect'),
                ),
              ),
            ],
            const SizedBox(height: ResourceFormStyles.sectionSpacing),
            _section('Rules text'),
            TextFormField(
              controller: _textController,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Text',
                helperText: _textOverride ? 'Manual override' : 'Generated',
              ),
              minLines: 3,
              maxLines: 8,
              onChanged: (_) {
                if (!_textOverride) setState(() => _textOverride = true);
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _regenerateText,
                child: const Text('Regenerate text'),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _pickMonstrousTrait,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('From Monstrous Trait…'),
              ),
            ),
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            DropdownButtonFormField<FeatureBudgetSlot?>(
              initialValue: _budgetSlot,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Budget slot (optional)',
              ),
              items: [
                const DropdownMenuItem<FeatureBudgetSlot?>(
                  value: null,
                  child: Text('None'),
                ),
                for (final s in FeatureBudgetSlot.values)
                  DropdownMenuItem(value: s, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() => _budgetSlot = v),
            ),
            const SizedBox(height: ResourceFormStyles.sectionSpacing),
            FilledButton(
              onPressed: validation.ok ? _submit : null,
              child: Text(widget.initial == null ? 'Create' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EffectEditDialog extends StatefulWidget {
  const _EffectEditDialog({this.initial});

  final FeatureEffect? initial;

  @override
  State<_EffectEditDialog> createState() => _EffectEditDialogState();
}

class _EffectEditDialogState extends State<_EffectEditDialog> {
  late FeatureEffectType _type =
      widget.initial?.type ?? FeatureEffectType.damage;
  late FeatureEffectDuration _duration =
      widget.initial?.duration ?? FeatureEffectDuration.instant;
  late final _damageEpController = TextEditingController(
    text: '${widget.initial?.payload['damageEp'] ?? 1}',
  );
  late final _deliveryController = TextEditingController(
    text: widget.initial?.payload['delivery'] as String? ?? 'area',
  );
  late final _damageTypesController = TextEditingController(
    text: ((widget.initial?.payload['damageTypes'] as List?) ?? const [])
        .join(', '),
  );
  late final _conditionController = TextEditingController(
    text: widget.initial?.payload['condition'] as String? ?? '',
  );
  late FeatureRarity _conditionRarity = FeatureRarityApi.fromJson(
    widget.initial?.payload['conditionRarity'] as String?,
  );
  late final _extraConditionsController = TextEditingController(
    text: '${widget.initial?.payload['extraConditions'] ?? 0}',
  );
  late final _terrainModifierController = TextEditingController(
    text: widget.initial?.payload['modifier'] as String? ?? '',
  );
  late FeatureRarity _terrainRarity = FeatureRarityApi.fromJson(
    widget.initial?.payload['terrainRarity'] as String?,
  );
  late final _extraModifiersController = TextEditingController(
    text: '${widget.initial?.payload['extraModifiers'] ?? 0}',
  );
  late final _resourceController = TextEditingController(
    text: widget.initial?.payload['resource'] as String? ?? '',
  );
  late FeatureRarity _resourceRarity = FeatureRarityApi.fromJson(
    widget.initial?.payload['resourceRarity'] as String?,
  );
  late final _extraResourcesController = TextEditingController(
    text: '${widget.initial?.payload['extraResources'] ?? 0}',
  );
  late final _movementEpController = TextEditingController(
    text: '${widget.initial?.payload['movementEp'] ?? 1}',
  );
  late final _movementKindController = TextEditingController(
    text: widget.initial?.payload['movementKind'] as String? ?? 'push',
  );
  late final _boonController = TextEditingController(
    text: widget.initial?.payload['boon'] as String? ?? '',
  );
  late FeatureRarity _boonRarity = FeatureRarityApi.fromJson(
    widget.initial?.payload['boonRarity'] as String?,
  );
  late final _extraBoonsController = TextEditingController(
    text: '${widget.initial?.payload['extraBoons'] ?? 0}',
  );
  late bool _multiTarget = widget.initial?.payload['multiTarget'] == true;
  late bool _extraSave = widget.initial?.payload['extraSave'] == true;

  @override
  void dispose() {
    _damageEpController.dispose();
    _deliveryController.dispose();
    _damageTypesController.dispose();
    _conditionController.dispose();
    _extraConditionsController.dispose();
    _terrainModifierController.dispose();
    _extraModifiersController.dispose();
    _resourceController.dispose();
    _extraResourcesController.dispose();
    _movementEpController.dispose();
    _movementKindController.dispose();
    _boonController.dispose();
    _extraBoonsController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _payload() {
    return switch (_type) {
      FeatureEffectType.damage => {
          'damageEp': int.tryParse(_damageEpController.text.trim()) ?? 1,
          'delivery': _deliveryController.text.trim().isEmpty
              ? 'area'
              : _deliveryController.text.trim(),
          'damageTypes': _damageTypesController.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
        },
      FeatureEffectType.condition => {
          'condition': _conditionController.text.trim(),
          'conditionRarity': _conditionRarity.name,
          'extraConditions':
              int.tryParse(_extraConditionsController.text.trim()) ?? 0,
          'multiTarget': _multiTarget,
          'extraSave': _extraSave,
        },
      FeatureEffectType.terrain => {
          'modifier': _terrainModifierController.text.trim(),
          'terrainRarity': _terrainRarity.name,
          'extraModifiers':
              int.tryParse(_extraModifiersController.text.trim()) ?? 0,
        },
      FeatureEffectType.resource => {
          'resource': _resourceController.text.trim(),
          'resourceRarity': _resourceRarity.name,
          'extraResources':
              int.tryParse(_extraResourcesController.text.trim()) ?? 0,
          'multiTarget': _multiTarget,
          'extraSave': _extraSave,
        },
      FeatureEffectType.movement => {
          'movementEp': int.tryParse(_movementEpController.text.trim()) ?? 1,
          'movementKind': _movementKindController.text.trim().isEmpty
              ? 'push'
              : _movementKindController.text.trim(),
        },
      FeatureEffectType.empower => {
          'boon': _boonController.text.trim(),
          'boonRarity': _boonRarity.name,
          'extraBoons': int.tryParse(_extraBoonsController.text.trim()) ?? 0,
          'multiTarget': _multiTarget,
        },
    };
  }

  FeatureEffect _buildEffect() {
    final effect = FeatureEffect(
      type: _type,
      cost: 0,
      duration: _duration,
      payload: _payload(),
    );
    return effect.copyWith(cost: computeEffectCost(effect));
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildEffect();
    return AlertDialog(
      title: Text(widget.initial == null ? 'Add effect' : 'Edit effect'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<FeatureEffectType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: [
                for (final t in FeatureEffectType.values)
                  DropdownMenuItem(value: t, child: Text(t.name)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _type = v);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FeatureEffectDuration>(
              initialValue: _duration,
              decoration: const InputDecoration(labelText: 'Duration'),
              items: [
                for (final d in FeatureEffectDuration.values)
                  DropdownMenuItem(value: d, child: Text(d.name)),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _duration = v);
              },
            ),
            const SizedBox(height: 12),
            ...switch (_type) {
              FeatureEffectType.damage => [
                  TextField(
                    controller: _damageEpController,
                    decoration: const InputDecoration(labelText: 'Damage EP'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _deliveryController,
                    decoration: const InputDecoration(
                      labelText: 'Delivery',
                      hintText: 'area, aimedSingle, aimedMulti',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _damageTypesController,
                    decoration: const InputDecoration(
                      labelText: 'Damage types',
                      hintText: 'fire, poison…',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              FeatureEffectType.condition => [
                  TextField(
                    controller: _conditionController,
                    decoration: const InputDecoration(labelText: 'Condition'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<FeatureRarity>(
                    initialValue: _conditionRarity,
                    decoration: const InputDecoration(labelText: 'Rarity'),
                    items: [
                      for (final r in FeatureRarity.values)
                        DropdownMenuItem(value: r, child: Text(r.label)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _conditionRarity = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _extraConditionsController,
                    decoration: const InputDecoration(
                      labelText: 'Extra conditions',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Multi-target'),
                    value: _multiTarget,
                    onChanged: (v) => setState(() => _multiTarget = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Extra save (−1 EP)'),
                    value: _extraSave,
                    onChanged: (v) => setState(() => _extraSave = v),
                  ),
                ],
              FeatureEffectType.terrain => [
                  TextField(
                    controller: _terrainModifierController,
                    decoration: const InputDecoration(labelText: 'Modifier'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<FeatureRarity>(
                    initialValue: _terrainRarity,
                    decoration: const InputDecoration(labelText: 'Rarity'),
                    items: [
                      for (final r in FeatureRarity.values)
                        DropdownMenuItem(value: r, child: Text(r.label)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _terrainRarity = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _extraModifiersController,
                    decoration: const InputDecoration(
                      labelText: 'Extra modifiers',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              FeatureEffectType.resource => [
                  TextField(
                    controller: _resourceController,
                    decoration: const InputDecoration(labelText: 'Resource'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<FeatureRarity>(
                    initialValue: _resourceRarity,
                    decoration: const InputDecoration(labelText: 'Rarity'),
                    items: [
                      for (final r in FeatureRarity.values)
                        DropdownMenuItem(value: r, child: Text(r.label)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _resourceRarity = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _extraResourcesController,
                    decoration: const InputDecoration(
                      labelText: 'Extra resources',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Multi-target'),
                    value: _multiTarget,
                    onChanged: (v) => setState(() => _multiTarget = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Extra save (−1 EP)'),
                    value: _extraSave,
                    onChanged: (v) => setState(() => _extraSave = v),
                  ),
                ],
              FeatureEffectType.movement => [
                  TextField(
                    controller: _movementEpController,
                    decoration: const InputDecoration(labelText: 'Movement EP'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _movementKindController,
                    decoration: const InputDecoration(
                      labelText: 'Movement kind',
                      hintText: 'push, pull, slide…',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              FeatureEffectType.empower => [
                  TextField(
                    controller: _boonController,
                    decoration: const InputDecoration(labelText: 'Boon'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<FeatureRarity>(
                    initialValue: _boonRarity,
                    decoration: const InputDecoration(labelText: 'Rarity'),
                    items: [
                      for (final r in FeatureRarity.values)
                        DropdownMenuItem(value: r, child: Text(r.label)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _boonRarity = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _extraBoonsController,
                    decoration: const InputDecoration(labelText: 'Extra boons'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Multi-target'),
                    value: _multiTarget,
                    onChanged: (v) => setState(() => _multiTarget = v),
                  ),
                ],
            },
            const SizedBox(height: 12),
            Text('Computed cost: ${preview.cost} EP'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, preview),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
