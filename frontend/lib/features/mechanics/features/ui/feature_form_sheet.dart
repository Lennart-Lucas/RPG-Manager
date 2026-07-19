import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../dm_tools/resources/ui/resource_form_helpers.dart';
import '../../../world/creatures/data/scaler_math.dart';
import '../../../world/ui/world_form_helpers.dart';
import '../data/feature_display.dart';
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
  int? scalerAtk,
  int? scalerDc,
  AuthController? auth,
}) {
  final editing = initial != null;
  final title = editing ? 'Edit feature' : 'New feature';
  final width = MediaQuery.sizeOf(context).width;
  final form = _FeatureForm(
    initial: initial,
    creatureRank: creatureRank,
    creatureThreat: creatureThreat,
    scalerDmg: scalerDmg,
    scalerAtk: scalerAtk,
    scalerDc: scalerDc,
    auth: auth,
  );

  if (width >= 1000) {
    return showDialog<MonsterFeature>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 860),
          child: _FeatureFormScaffold(
            title: title,
            compact: false,
            child: form,
          ),
        ),
      ),
    );
  }

  if (width < 720) {
    return showModalBottomSheet<MonsterFeature>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: _FeatureFormScaffold(
          title: title,
          compact: true,
          child: form,
        ),
      ),
    );
  }

  return showDialog<MonsterFeature>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: _FeatureFormScaffold(
          title: title,
          compact: false,
          child: form,
        ),
      ),
    ),
  );
}

/// Title + expanded body (no outer scroll) so the form can show a side preview.
class _FeatureFormScaffold extends StatelessWidget {
  const _FeatureFormScaffold({
    required this.title,
    required this.compact,
    required this.child,
  });

  final String title;
  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: !compact,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _FeatureForm extends StatefulWidget {
  const _FeatureForm({
    this.initial,
    this.creatureRank,
    this.creatureThreat,
    this.scalerDmg,
    this.scalerAtk,
    this.scalerDc,
    this.auth,
  });

  final MonsterFeature? initial;
  final ScalerRank? creatureRank;
  final num? creatureThreat;
  final int? scalerDmg;
  final int? scalerAtk;
  final int? scalerDc;
  final AuthController? auth;

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
  late final _rangeFeetController = TextEditingController(
    text: widget.initial?.range.feet?.toString() ?? '',
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
  late FeatureDelivery _delivery =
      widget.initial?.delivery ?? FeatureDelivery.weapon;
  late bool _hasRequirement = widget.initial?.hasRequirement ?? false;
  late FeatureLimitationType _limitationType =
      widget.initial?.limitation.type ?? FeatureLimitationType.none;
  late FeatureDefence _defence =
      widget.initial?.defence ?? FeatureDefence.ac;
  late FeatureRangeMode _rangeMode =
      widget.initial?.range.mode ?? FeatureRangeMode.melee;
  late FeatureTargetQuantity _targetQuantity =
      widget.initial?.targets.quantity ?? FeatureTargetQuantity.one;
  late FeatureTargetCategory _targetCategory =
      widget.initial?.targets.category ?? FeatureTargetCategory.target;
  late FeatureTargetAlliance _targetAlliance =
      widget.initial?.targets.alliance ?? FeatureTargetAlliance.any;
  late List<int> _creatureTypeIds = [
    ...?widget.initial?.targets.creatureTypeIds,
  ];
  late FeatureDeferralType _deferralType =
      widget.initial?.deferral.type ?? FeatureDeferralType.none;
  late List<FeatureEffect> _effects = [
    ...?widget.initial?.effects.map((e) => e),
  ];
  late bool _textOverride = widget.initial?.textOverride ?? false;
  late FeatureBudgetSlot? _budgetSlot = widget.initial?.budgetSlot;

  Map<int, String> _creatureTypeNames = const {};
  Map<int, String> _damageTypeNames = const {};
  bool _loadingCreatureTypes = true;

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

  @override
  void initState() {
    super.initState();
    _loadCatalogLookups();
  }

  Future<void> _loadCatalogLookups() async {
    final auth = widget.auth;
    if (auth == null) {
      if (mounted) setState(() => _loadingCreatureTypes = false);
      return;
    }
    try {
      final token = await auth.requireAccessToken();
      if (token == null) {
        if (mounted) setState(() => _loadingCreatureTypes = false);
        return;
      }
      final api = CatalogApi();
      final results = await Future.wait([
        api.list(token, CatalogKind.creatureTypes),
        api.list(token, CatalogKind.damageTypes),
      ]);
      if (!mounted) return;
      setState(() {
        _creatureTypeNames = {for (final i in results[0]) i.id: i.name};
        _damageTypeNames = {for (final i in results[1]) i.id: i.name};
        _loadingCreatureTypes = false;
      });
    } on AuthApiException {
      if (mounted) setState(() => _loadingCreatureTypes = false);
    } catch (_) {
      if (mounted) setState(() => _loadingCreatureTypes = false);
    }
  }

  MonsterFeature _buildFeature({bool forValidation = false}) {
    return MonsterFeature(
      id: widget.initial?.id ?? '',
      name: _nameController.text.trim(),
      category: _category,
      rarity: _rarity,
      delivery: _delivery,
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
        mode: _rangeMode,
        feet: int.tryParse(_rangeFeetController.text.trim()),
      ),
      targets: FeatureTargets(
        quantity: _targetQuantity,
        category: _targetCategory,
        alliance: _targetCategory == FeatureTargetCategory.creature
            ? _targetAlliance
            : FeatureTargetAlliance.any,
        creatureTypeIds: _targetCategory == FeatureTargetCategory.creature
            ? _creatureTypeIds
            : const [],
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
    _rangeFeetController.dispose();
    _deferralTurnsController.dispose();
    super.dispose();
  }

  void _onActivationChanged(FeatureActivation? value) {
    if (value == null) return;
    setState(() {
      _activation = value;
      if (value == FeatureActivation.none) {
        _category = FeatureCategory.trait;
        _defence = FeatureDefence.ac;
        _effects = [];
        _rangeMode = FeatureRangeMode.melee;
        _rangeFeetController.clear();
        _targetQuantity = FeatureTargetQuantity.none;
      } else if (_category == FeatureCategory.trait) {
        _category = FeatureCategory.utility;
        _defence = FeatureDefence.ac;
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
      _defence = FeatureDefence.ac;
      _effects = [];
      _textController.text = trait.text;
      _textOverride = true;
      _budgetSlot = trait.budgetSlot;
    });
  }

  Future<void> _editEffect({FeatureEffect? initial, int? index}) async {
    final result = await showDialog<FeatureEffect>(
      context: context,
      builder: (ctx) => _EffectEditDialog(
        initial: initial,
        damageTypeNames: _damageTypeNames,
        targetQuantity: _targetQuantity,
      ),
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

  Widget _previewBox(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final display = FeatureDisplay.fromFeature(
      _buildFeature(),
      atk: widget.scalerAtk,
      dc: widget.scalerDc,
      creatureTypeNamesById: _creatureTypeNames,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Text.rich(
          display.toSpan(style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validation = _validation;
    final availableEp = validation.available;
    final spentEp = validation.spent;
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final preview = _previewBox(context);

    final formFields = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
            _section('Identity'),
            TextFormField(
              controller: _nameController,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Name',
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<FeatureActivation>(
                    initialValue: _activation,
                    decoration: ResourceFormStyles.inputDecoration(
                      context,
                      label: 'Activation',
                    ),
                    items: [
                      for (final a in FeatureActivation.values)
                        DropdownMenuItem(value: a, child: Text(a.label)),
                    ],
                    onChanged: _onActivationChanged,
                  ),
                ),
                const SizedBox(width: ResourceFormStyles.fieldSpacing),
                Expanded(
                  child: DropdownButtonFormField<FeatureRarity>(
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
                ),
              ],
            ),
            if (_isAttackOrUtility) ...[
              const SizedBox(height: ResourceFormStyles.sectionSpacing),
              _section('Attack'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<FeatureRangeMode>(
                      initialValue: _rangeMode,
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'Melee / Range',
                      ),
                      items: [
                        for (final m in FeatureRangeMode.values)
                          DropdownMenuItem(value: m, child: Text(m.label)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _rangeMode = v);
                      },
                    ),
                  ),
                  const SizedBox(width: ResourceFormStyles.fieldSpacing),
                  Expanded(
                    child: DropdownButtonFormField<FeatureDelivery>(
                      initialValue: _delivery,
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'Weapon / Magic',
                      ),
                      items: [
                        for (final d in FeatureDelivery.values)
                          DropdownMenuItem(value: d, child: Text(d.label)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _delivery = v);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ResourceFormStyles.fieldSpacing),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<FeatureDefence>(
                      initialValue: _defence,
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'Save / attack vs',
                      ),
                      items: [
                        for (final d in FeatureDefence.values)
                          DropdownMenuItem(value: d, child: Text(d.label)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _defence = v);
                      },
                    ),
                  ),
                  const SizedBox(width: ResourceFormStyles.fieldSpacing),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey(_rangeMode),
                      controller: _rangeFeetController,
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: _rangeMode.distanceLabel,
                        hintText: 'ft.',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ResourceFormStyles.sectionSpacing),
              _section('Targets'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: DropdownButtonFormField<FeatureTargetQuantity>(
                      initialValue: _targetQuantity,
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'Quantity',
                      ),
                      items: [
                        for (final q in FeatureTargetQuantity.values)
                          DropdownMenuItem(value: q, child: Text(q.label)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _targetQuantity = v);
                      },
                    ),
                  ),
                  const SizedBox(width: ResourceFormStyles.fieldSpacing),
                  Expanded(
                    child: DropdownButtonFormField<FeatureTargetCategory>(
                      initialValue: _targetCategory,
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'Target category',
                      ),
                      items: [
                        for (final c in FeatureTargetCategory.values)
                          DropdownMenuItem(value: c, child: Text(c.label)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          _targetCategory = v;
                          if (v != FeatureTargetCategory.creature) {
                            _targetAlliance = FeatureTargetAlliance.any;
                            _creatureTypeIds = [];
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_targetCategory == FeatureTargetCategory.creature) ...[
                const SizedBox(height: ResourceFormStyles.fieldSpacing),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<FeatureTargetAlliance>(
                        initialValue: _targetAlliance,
                        decoration: ResourceFormStyles.inputDecoration(
                          context,
                          label: 'Alliance',
                        ),
                        items: [
                          for (final a in FeatureTargetAlliance.values)
                            DropdownMenuItem(value: a, child: Text(a.label)),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _targetAlliance = v);
                        },
                      ),
                    ),
                    const SizedBox(width: ResourceFormStyles.fieldSpacing),
                    Expanded(
                      child: _loadingCreatureTypes
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            )
                          : catalogMultiPickTile(
                              context: context,
                              label: 'Creature types',
                              labels: catalogSelectionLabels(
                                selected: _creatureTypeIds.toSet(),
                                namesById: _creatureTypeNames,
                              ),
                              onTap: () => pickCatalogIds(
                                context: context,
                                title: 'Creature types',
                                options: catalogPicklistOptions(
                                  _creatureTypeNames,
                                ),
                                selected: _creatureTypeIds.toSet(),
                                onDone: (next) => setState(
                                  () => _creatureTypeIds = next.toList(),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Has requirement'),
              value: _hasRequirement,
              onChanged: (v) => setState(() => _hasRequirement = v),
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
                    DropdownMenuItem(value: t, child: Text(t.label)),
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
                    DropdownMenuItem(value: t, child: Text(t.label)),
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
              Text(
                'Add 1–3 effects. Available EP: $availableEp · Spent: $spentEp.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: validation.ok
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.error,
                    ),
              ),
              const SizedBox(height: ResourceFormStyles.fieldSpacing),
              for (var i = 0; i < _effects.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(_effects[i].type.label),
                    subtitle: Text(
                      'Cost: ${computeEffectCost(_effects[i])} EP · '
                      '${_effects[i].duration.label}',
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
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _budgetSlot = v),
            ),
      ],
    );

    final scrollableForm = SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: wide
          ? formFields
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                formFields,
                const SizedBox(height: ResourceFormStyles.sectionSpacing),
                ExpansionTile(
                  title: const Text('Preview'),
                  initiallyExpanded: true,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: preview,
                    ),
                  ],
                ),
              ],
            ),
    );

    final body = wide
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: scrollableForm),
              const VerticalDivider(width: 1),
              Expanded(
                flex: 4,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: preview,
                ),
              ),
            ],
          )
        : scrollableForm;

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
          children: [
            Expanded(child: body),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: FilledButton(
                onPressed: validation.ok ? _submit : null,
                child: Text(widget.initial == null ? 'Create' : 'Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EffectEditDialog extends StatefulWidget {
  const _EffectEditDialog({
    this.initial,
    this.damageTypeNames = const {},
    this.targetQuantity = FeatureTargetQuantity.one,
  });

  final FeatureEffect? initial;
  final Map<int, String> damageTypeNames;
  final FeatureTargetQuantity targetQuantity;

  @override
  State<_EffectEditDialog> createState() => _EffectEditDialogState();
}

class _EffectEditDialogState extends State<_EffectEditDialog> {
  late FeatureEffectType _type =
      widget.initial?.type ?? FeatureEffectType.damage;
  late FeatureEffectDuration _duration =
      widget.initial?.duration ?? FeatureEffectDuration.instant;
  late int _damageEp =
      ((widget.initial?.payload['damageEp'] as num?)?.toInt() ?? 1).clamp(1, 5);
  late int? _damageTypeId = _initialDamageTypeId();
  late bool _damageOnMiss = widget.initial?.payload['damageOnMiss'] == true &&
      widget.targetQuantity == FeatureTargetQuantity.all;
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

  int? _initialDamageTypeId() {
    final raw = (widget.initial?.payload['damageTypes'] as List?) ?? const [];
    if (raw.isEmpty) return null;
    final wanted = '${raw.first}'.trim().toLowerCase();
    for (final entry in widget.damageTypeNames.entries) {
      if (entry.value.toLowerCase() == wanted) return entry.key;
    }
    return null;
  }

  @override
  void dispose() {
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
          'damageEp': _damageEp,
          'delivery': damageDeliveryMode(widget.targetQuantity).name,
          'damageOnMiss': widget.targetQuantity == FeatureTargetQuantity.all &&
              _damageOnMiss,
          'damageTypes': [
            if (_damageTypeId != null) ?widget.damageTypeNames[_damageTypeId!],
          ],
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
    final gap = ResourceFormStyles.fieldSpacing;
    InputDecoration deco(String label, {String? hintText}) =>
        ResourceFormStyles.inputDecoration(
          context,
          label: label,
          hintText: hintText,
        );

    return AlertDialog(
      title: Text(widget.initial == null ? 'Add effect' : 'Edit effect'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<FeatureEffectType>(
                initialValue: _type,
                decoration: deco('Type'),
                items: [
                  for (final t in FeatureEffectType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _type = v);
                },
              ),
              SizedBox(height: gap),
              DropdownButtonFormField<FeatureEffectDuration>(
                initialValue: _duration,
                decoration: deco('Duration'),
                items: [
                  for (final d in FeatureEffectDuration.values)
                    DropdownMenuItem(value: d, child: Text(d.pickLabel)),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() => _duration = v);
                },
              ),
              SizedBox(height: gap),
              ...switch (_type) {
                FeatureEffectType.damage => [
                    DropdownButtonFormField<int>(
                      key: ValueKey(
                        '${widget.targetQuantity.name}-$_damageOnMiss',
                      ),
                      initialValue: _damageEp,
                      decoration: deco('Damage Amount'),
                      items: [
                        for (var ep = 1; ep <= 5; ep++)
                          DropdownMenuItem(
                            value: ep,
                            child: Text(
                              damageAmountLabel(
                                ep,
                                quantity: widget.targetQuantity,
                                damageOnMiss: _damageOnMiss,
                              ),
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _damageEp = v);
                      },
                    ),
                    SizedBox(height: gap),
                    DropdownButtonFormField<int?>(
                      initialValue: _damageTypeId,
                      decoration: deco('Damage type'),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('None'),
                        ),
                        for (final entry
                            in (widget.damageTypeNames.entries.toList()
                              ..sort(
                                (a, b) => a.value.toLowerCase().compareTo(
                                      b.value.toLowerCase(),
                                    ),
                              )))
                          DropdownMenuItem<int?>(
                            value: entry.key,
                            child: Text(entry.value),
                          ),
                      ],
                      onChanged: (v) => setState(() => _damageTypeId = v),
                    ),
                    if (widget.targetQuantity == FeatureTargetQuantity.all)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Damage on Miss (1EP)'),
                        value: _damageOnMiss,
                        onChanged: (v) => setState(() => _damageOnMiss = v),
                      ),
                  ],
                FeatureEffectType.condition => [
                    TextFormField(
                      controller: _conditionController,
                      decoration: deco('Condition'),
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: gap),
                    DropdownButtonFormField<FeatureRarity>(
                      initialValue: _conditionRarity,
                      decoration: deco('Rarity'),
                      items: [
                        for (final r in FeatureRarity.values)
                          DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _conditionRarity = v);
                      },
                    ),
                    SizedBox(height: gap),
                    TextFormField(
                      controller: _extraConditionsController,
                      decoration: deco('Extra conditions'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
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
                    TextFormField(
                      controller: _terrainModifierController,
                      decoration: deco('Modifier'),
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: gap),
                    DropdownButtonFormField<FeatureRarity>(
                      initialValue: _terrainRarity,
                      decoration: deco('Rarity'),
                      items: [
                        for (final r in FeatureRarity.values)
                          DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _terrainRarity = v);
                      },
                    ),
                    SizedBox(height: gap),
                    TextFormField(
                      controller: _extraModifiersController,
                      decoration: deco('Extra modifiers'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                FeatureEffectType.resource => [
                    TextFormField(
                      controller: _resourceController,
                      decoration: deco('Resource'),
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: gap),
                    DropdownButtonFormField<FeatureRarity>(
                      initialValue: _resourceRarity,
                      decoration: deco('Rarity'),
                      items: [
                        for (final r in FeatureRarity.values)
                          DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _resourceRarity = v);
                      },
                    ),
                    SizedBox(height: gap),
                    TextFormField(
                      controller: _extraResourcesController,
                      decoration: deco('Extra resources'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
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
                    TextFormField(
                      controller: _movementEpController,
                      decoration: deco('Movement EP'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: gap),
                    TextFormField(
                      controller: _movementKindController,
                      decoration: deco(
                        'Movement kind',
                        hintText: 'push, pull, slide…',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                FeatureEffectType.empower => [
                    TextFormField(
                      controller: _boonController,
                      decoration: deco('Boon'),
                      onChanged: (_) => setState(() {}),
                    ),
                    SizedBox(height: gap),
                    DropdownButtonFormField<FeatureRarity>(
                      initialValue: _boonRarity,
                      decoration: deco('Rarity'),
                      items: [
                        for (final r in FeatureRarity.values)
                          DropdownMenuItem(value: r, child: Text(r.label)),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _boonRarity = v);
                      },
                    ),
                    SizedBox(height: gap),
                    TextFormField(
                      controller: _extraBoonsController,
                      decoration: deco('Extra boons'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
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
              SizedBox(height: gap),
              Text(
                'Computed cost: ${preview.cost} EP',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
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
