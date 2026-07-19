import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rpg_manager/core/ui/markdown_form_field.dart';
import 'package:rpg_manager/features/auth/data/auth_api.dart';
import 'package:rpg_manager/features/auth/state/auth_controller.dart';
import 'package:rpg_manager/features/catalog/data/catalog_api.dart';
import 'package:rpg_manager/features/catalog/data/catalog_kind.dart';
import 'package:rpg_manager/features/catalog/data/catalog_models.dart';
import 'package:rpg_manager/features/dm_tools/resources/ui/resource_form_helpers.dart';
import 'package:rpg_manager/features/mechanics/features/data/feature_model.dart';
import 'package:rpg_manager/features/mechanics/features/ui/feature_form_sheet.dart';
import 'package:rpg_manager/features/world/creatures/data/creature_model.dart';
import 'package:rpg_manager/features/world/creatures/data/scaler_math.dart';

Future<Creature?> showCreatureFormSheet(
  BuildContext context, {
  Creature? initial,
  AuthController? auth,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<Creature>(
    context,
    title: editing ? 'Edit creature' : 'New creature',
    child: _CreatureForm(initial: initial, auth: auth),
  );
}

const _creatureSizes = [
  'Tiny',
  'Small',
  'Medium',
  'Large',
  'Huge',
  'Gargantuan',
];

const _saveKeys = ['str', 'dex', 'con', 'int', 'wis', 'cha'];
const _saveLabels = ['STR', 'DEX', 'CON', 'INT', 'WIS', 'CHA'];

enum _AbilityTier { high, mid, low, minus5 }

extension on _AbilityTier {
  String get label => switch (this) {
        _AbilityTier.high => 'High',
        _AbilityTier.mid => 'Mid',
        _AbilityTier.low => 'Low',
        _AbilityTier.minus5 => '−5',
      };

  int score(ScalerComputedStats formula) => switch (this) {
        _AbilityTier.high => formula.abilityHigh,
        _AbilityTier.mid => formula.abilityMid,
        _AbilityTier.low => formula.abilityLow,
        _AbilityTier.minus5 => -5,
      };
}

class _CreatureForm extends StatefulWidget {
  const _CreatureForm({this.initial, this.auth});

  final Creature? initial;
  final AuthController? auth;

  @override
  State<_CreatureForm> createState() => _CreatureFormState();
}

class _CreatureFormState extends State<_CreatureForm> {
  final _formKey = GlobalKey<FormState>();

  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _creatureTypeController =
      TextEditingController(text: widget.initial?.creatureType ?? '');
  late final _levelController = TextEditingController(
    text: '${widget.initial?.level ?? 1}',
  );
  late final _threatController = TextEditingController(
    text: '${widget.initial?.threat ?? 4}',
  );
  late final _reachController = TextEditingController(
    text: widget.initial?.reach?.toString() ?? '',
  );
  late final _rangeController = TextEditingController(
    text: widget.initial?.range?.toString() ?? '',
  );
  late final _walkController = TextEditingController(
    text: '${widget.initial?.speeds.walk ?? 30}',
  );
  late final _flyController = TextEditingController(
    text: widget.initial?.speeds.fly?.toString() ?? '',
  );
  late final _swimController = TextEditingController(
    text: widget.initial?.speeds.swim?.toString() ?? '',
  );
  late final _climbController = TextEditingController(
    text: widget.initial?.speeds.climb?.toString() ?? '',
  );
  late final _burrowController = TextEditingController(
    text: widget.initial?.speeds.burrow?.toString() ?? '',
  );
  late final _sensesController = TextEditingController(
    text: _listToText(widget.initial?.senses ?? const []),
  );
  late final _skillsController = TextEditingController(
    text: _listToText(widget.initial?.skills ?? const []),
  );
  late final _passivePerceptionController = TextEditingController(
    text: '${widget.initial?.passivePerception ?? 10}',
  );
  late final _vulnerabilitiesController = TextEditingController(
    text: _listToText(widget.initial?.vulnerabilities ?? const []),
  );
  late final _resistancesController = TextEditingController(
    text: _listToText(widget.initial?.resistances ?? const []),
  );
  late final _immunitiesController = TextEditingController(
    text: _listToText(widget.initial?.immunities ?? const []),
  );
  late final _languagesController = TextEditingController(
    text: _listToText(widget.initial?.languages ?? const []),
  );
  late final _itemsController = TextEditingController(
    text: _listToText(widget.initial?.items ?? const []),
  );
  late final _triggerController =
      TextEditingController(text: widget.initial?.trigger ?? '');
  late final _countermeasuresController = TextEditingController(
    text: (widget.initial?.countermeasures ?? const []).join('\n'),
  );

  late String _size = widget.initial?.size ?? 'Medium';
  late ScalerRank _rank = widget.initial?.rank ?? ScalerRank.grunt;
  late num _threat =
      widget.initial?.threat ?? effectiveThreat(ScalerRank.grunt);
  late ScalerRole? _role = widget.initial?.role;
  late String? _roleSubtype = widget.initial?.roleSubtype;
  late final List<String> _trainedSaves = [
    ...?(widget.initial?.trainedSavingThrows.map((s) => s.toLowerCase())),
  ];
  late List<CreatureFeatureEntry> _features = [
    ...(widget.initial?.features ?? const []),
  ];
  late CreatureOverrides _overrides = widget.initial?.overrides ?? const CreatureOverrides();
  late Map<AbilityKey, _AbilityTier> _abilityTiers;

  late final _acController = TextEditingController();
  late final _hpController = TextEditingController();
  late final _atkController = TextEditingController();
  late final _dcController = TextEditingController();
  late final _dmgController = TextEditingController();
  late final _initController = TextEditingController();
  late final _crController = TextEditingController();
  late final _xpController = TextEditingController();

  bool _syncingStats = false;

  ScalerComputedStats get _formula => computeScalerStats(
        level: _level,
        rank: _rank,
        role: _role,
        paragonThreat: _rank == ScalerRank.paragon ? _threat : null,
      );

  int get _level {
    final parsed = int.tryParse(_levelController.text.trim());
    return (parsed ?? 1).clamp(0, 30);
  }

  @override
  void initState() {
    super.initState();
    if (widget.initial == null) {
      _features = mergeAutoFeatures(
        existing: const [],
        rank: _rank,
        level: _level,
        threat: _threat,
        role: _role,
      );
    }
    _abilityTiers = _tiersFromInitial();
    _initStatControllers();
  }

  void _initStatControllers() {
    final f = _formula;
    _acController.text = '${_overrides.ac ?? f.ac}';
    _hpController.text = '${_overrides.hp ?? f.hp}';
    _atkController.text = '${_overrides.atk ?? f.atk}';
    _dcController.text = '${_overrides.dc ?? f.dc}';
    _dmgController.text = '${_overrides.dmg ?? f.dmg}';
    _initController.text = '${_overrides.initiativeBonus ?? f.initiativeBonus}';
    _crController.text = _overrides.cr ?? f.cr;
    _xpController.text = '${_overrides.xp ?? f.xp}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _creatureTypeController.dispose();
    _levelController.dispose();
    _threatController.dispose();
    _reachController.dispose();
    _rangeController.dispose();
    _walkController.dispose();
    _flyController.dispose();
    _swimController.dispose();
    _climbController.dispose();
    _burrowController.dispose();
    _sensesController.dispose();
    _skillsController.dispose();
    _passivePerceptionController.dispose();
    _vulnerabilitiesController.dispose();
    _resistancesController.dispose();
    _immunitiesController.dispose();
    _languagesController.dispose();
    _itemsController.dispose();
    _triggerController.dispose();
    _countermeasuresController.dispose();
    _acController.dispose();
    _hpController.dispose();
    _atkController.dispose();
    _dcController.dispose();
    _dmgController.dispose();
    _initController.dispose();
    _crController.dispose();
    _xpController.dispose();
    super.dispose();
  }

  static String _listToText(List<String> items) => items.join(', ');

  static List<String> _parseList(String text) {
    return text
        .split(RegExp(r'[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Map<AbilityKey, _AbilityTier> _tiersFromInitial() {
    final formula = _formula;
    final scores = widget.initial?.abilityScores ??
        defaultAbilityAssignment(formula);
    final defaults = defaultAbilityAssignment(formula);
    final source = widget.initial?.abilityScores ?? defaults;

    _AbilityTier tierFor(AbilityKey key, int value) {
      if (value == formula.abilityHigh) return _AbilityTier.high;
      if (value == formula.abilityMid) return _AbilityTier.mid;
      if (value == formula.abilityLow) return _AbilityTier.low;
      if (value == -5) return _AbilityTier.minus5;
      final def = source[key];
      if (def == defaults[key]) {
        if (key == AbilityKey.str || key == AbilityKey.dex) {
          return _AbilityTier.high;
        }
        if (key == AbilityKey.con || key == AbilityKey.int_) {
          return _AbilityTier.mid;
        }
        return _AbilityTier.low;
      }
      return _AbilityTier.mid;
    }

    return {
      for (final key in AbilityKey.values)
        key: tierFor(key, scores[key]),
    };
  }

  CreatureAbilityScores _abilityScoresFromTiers() {
    final formula = _formula;
    var scores = const CreatureAbilityScores();
    for (final key in AbilityKey.values) {
      scores = scores.withAbility(key, _abilityTiers[key]!.score(formula));
    }
    return scores;
  }

  void _syncStatControllers() {
    final f = _formula;
    _syncingStats = true;
    if (_overrides.ac == null) _acController.text = '${f.ac}';
    if (_overrides.hp == null) _hpController.text = '${f.hp}';
    if (_overrides.atk == null) _atkController.text = '${f.atk}';
    if (_overrides.dc == null) _dcController.text = '${f.dc}';
    if (_overrides.dmg == null) _dmgController.text = '${f.dmg}';
    if (_overrides.initiativeBonus == null) {
      _initController.text = '${f.initiativeBonus}';
    }
    if (_overrides.cr == null) _crController.text = f.cr;
    if (_overrides.xp == null) _xpController.text = '${f.xp}';
    _syncingStats = false;
  }

  void _recomputeCombat({bool mergeFeatures = true}) {
    final f = _formula;
    setState(() {
      if (mergeFeatures) {
        _features = mergeAutoFeatures(
          existing: _features,
          rank: _rank,
          level: _level,
          threat: _threat,
          role: _role,
        );
      }
      final granted = f.grantedSkill;
      if (granted != null) {
        final skills = _parseList(_skillsController.text);
        if (!skills.any((s) => s.toLowerCase() == granted.toLowerCase())) {
          skills.add(granted);
          _skillsController.text = _listToText(skills);
        }
      }
      _syncStatControllers();
    });
  }

  void _onRankChanged(ScalerRank? value) {
    if (value == null) return;
    setState(() {
      _rank = value;
      if (value != ScalerRank.paragon) {
        _threat = effectiveThreat(value);
        _threatController.text = '$_threat';
      } else if (_threatController.text.trim().isEmpty) {
        _threat = 4;
        _threatController.text = '4';
      }
    });
    _recomputeCombat();
  }

  void _onRoleChanged(ScalerRole? value) {
    setState(() {
      _role = value;
      if (value == null) {
        _roleSubtype = null;
      } else if (_roleSubtype != null &&
          !value.subtypes.contains(_roleSubtype)) {
        _roleSubtype = null;
      }
    });
    _recomputeCombat();
  }

  void _onLevelChanged() {
    _recomputeCombat();
  }

  void _onThreatChanged() {
    final parsed = num.tryParse(_threatController.text.trim());
    if (parsed != null) {
      setState(() => _threat = parsed);
      _recomputeCombat();
    }
  }

  void _updateIntOverride({
    required int formulaValue,
    required String text,
    required int? current,
    required void Function(int?) setter,
    required TextEditingController controller,
  }) {
    if (_syncingStats) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        setter(null);
        controller.text = '$formulaValue';
      });
      return;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed == null) return;
    setState(() {
      setter(parsed == formulaValue ? null : parsed);
    });
  }

  void _updateCrOverride(String text) {
    if (_syncingStats) return;
    final trimmed = text.trim();
    final formulaCr = _formula.cr;
    setState(() {
      _overrides = _overrides.copyWith(
        cr: trimmed.isEmpty || trimmed == formulaCr ? null : trimmed,
        clearCr: trimmed.isEmpty || trimmed == formulaCr,
      );
    });
  }

  String? _abilityAssignmentWarning() {
    var high = 0;
    var mid = 0;
    var low = 0;
    for (final tier in _abilityTiers.values) {
      switch (tier) {
        case _AbilityTier.high:
          high++;
        case _AbilityTier.mid:
          mid++;
        case _AbilityTier.low:
          low++;
        case _AbilityTier.minus5:
          break;
      }
    }
    if (high == 2 && mid == 2 && low == 2) return null;
    return 'Recommended: two High, two Mid, and two Low assignments.';
  }

  Future<void> _editFeature(int index) async {
    final entry = _features[index];
    if (entry.isAuto || entry.source == CreatureFeatureSource.catalog) return;
    final feature = entry.feature;
    if (feature == null) return;
    final result = await showFeatureFormSheet(
      context,
      initial: feature,
      creatureRank: _rank,
      creatureThreat: _threat,
      scalerDmg: _formula.dmg,
      creatureLevel: _level,
    );
    if (result == null || !mounted) return;
    setState(
      () => _features[index] = CreatureFeatureEntry.local(result),
    );
  }

  Future<void> _addLocalFeature() async {
    final result = await showFeatureFormSheet(
      context,
      creatureRank: _rank,
      creatureThreat: _threat,
      scalerDmg: _formula.dmg,
      creatureLevel: _level,
    );
    if (result == null || !mounted) return;
    setState(
      () => _features = [..._features, CreatureFeatureEntry.local(result)],
    );
  }

  Future<void> _addCatalogFeature() async {
    final auth = widget.auth;
    if (auth == null) return;
    final token = await auth.requireAccessToken();
    if (token == null || !mounted) return;
    final api = CatalogApi();
    List<CatalogItem> items;
    try {
      items = await api.list(token, CatalogKind.features);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load features catalog')),
      );
      return;
    }

    if (!mounted) return;

    final queryController = TextEditingController();
    final selected = await showDialog<CatalogItem>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final q = queryController.text.trim().toLowerCase();
            final filtered = q.isEmpty
                ? items
                : items
                    .where((item) => item.name.toLowerCase().contains(q))
                    .toList();
            return AlertDialog(
              title: const Text('Add from catalog'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: queryController,
                      decoration: const InputDecoration(labelText: 'Search'),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return ListTile(
                            title: Text(item.name),
                            onTap: () => Navigator.pop(ctx, item),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
    queryController.dispose();
    if (selected == null || !mounted) return;

    final feature = MonsterFeature.fromCatalogPayload(
      name: selected.name,
      payload: selected.payload,
    );
    setState(() {
      _features = [
        ..._features,
        CreatureFeatureEntry.catalog(
          catalogItemId: selected.id,
          snapshotName: selected.name,
          snapshotText: feature.text,
        ),
      ];
    });
  }

  Future<void> _detachCatalogFeature(int index) async {
    final entry = _features[index];
    if (entry.source != CreatureFeatureSource.catalog) return;
    final auth = widget.auth;
    if (auth == null) return;
    final token = await auth.requireAccessToken();
    if (token == null || !mounted) return;
    try {
      final item = await CatalogApi().get(
        token,
        CatalogKind.features,
        entry.catalogItemId!,
      );
      final feature = MonsterFeature.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      );
      if (!mounted) return;
      setState(
        () => _features[index] = CreatureFeatureEntry.local(feature),
      );
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not detach catalog feature')),
      );
    }
  }

  Future<void> _viewAutoFeature(int index) async {
    final entry = _features[index];
    final feature = entry.feature;
    if (feature == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(feature.name),
        content: SingleChildScrollView(child: Text(feature.text)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _featureBadge(CreatureFeatureEntry entry) {
    if (entry.isAuto) return 'Auto';
    if (entry.source == CreatureFeatureSource.catalog) return 'Catalog';
    return 'Local';
  }

  String _featureSubtitle(CreatureFeatureEntry entry) {
    if (entry.isAuto) {
      final f = entry.feature!;
      return 'Auto · ${f.category.label} · ${f.rarity.label}';
    }
    if (entry.source == CreatureFeatureSource.catalog) {
      return 'Catalog · ${entry.snapshotName ?? ''}';
    }
    final f = entry.feature!;
    return '${f.category.label} · ${f.rarity.label} · ${f.effectPoints} EP';
  }

  int _budgetSlotCount(FeatureBudgetSlot slot) {
    return _features.where((e) {
      if (e.isAuto) return false;
      if (e.source == CreatureFeatureSource.catalog) return false;
      return e.feature?.budgetSlot == slot;
    }).length;
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final name = _nameController.text.trim();
    final f = _formula;
    var saves = [..._trainedSaves];
    if (saves.length > f.trainedSaveCount) {
      saves = saves.take(f.trainedSaveCount).toList();
    }

    final creature = Creature(
      id: widget.initial?.id ?? Creature.slugify(name),
      name: name,
      size: _size,
      creatureType: _creatureTypeController.text.trim(),
      level: _level,
      rank: _rank,
      threat: _rank == ScalerRank.paragon ? _threat : effectiveThreat(_rank),
      role: _role,
      roleSubtype: _roleSubtype,
      abilityScores: _abilityScoresFromTiers(),
      trainedSavingThrows: saves,
      reach: _parseOptionalInt(_reachController.text),
      range: _parseOptionalInt(_rangeController.text),
      speeds: CreatureSpeeds(
        walk: int.tryParse(_walkController.text.trim()) ?? 30,
        fly: _parseOptionalInt(_flyController.text),
        swim: _parseOptionalInt(_swimController.text),
        climb: _parseOptionalInt(_climbController.text),
        burrow: _parseOptionalInt(_burrowController.text),
      ),
      senses: _parseList(_sensesController.text),
      passivePerception:
          int.tryParse(_passivePerceptionController.text.trim()) ?? 10,
      skills: _parseList(_skillsController.text),
      vulnerabilities: _parseList(_vulnerabilitiesController.text),
      resistances: _parseList(_resistancesController.text),
      immunities: _parseList(_immunitiesController.text),
      languages: _parseList(_languagesController.text),
      items: _parseList(_itemsController.text),
      trigger: _triggerController.text.trim().isEmpty
          ? null
          : _triggerController.text.trim(),
      countermeasures: _countermeasuresController.text
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      features: _features,
      overrides: _overrides,
    );

    Navigator.pop(context, creature);
  }

  int? _parseOptionalInt(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
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

  Widget _statField({
    required String label,
    required TextEditingController controller,
    required int formulaValue,
    required int? overrideValue,
    required void Function(int?) onOverrideChanged,
  }) {
    return Expanded(
      child: TextFormField(
        controller: controller,
        decoration: ResourceFormStyles.inputDecoration(
          context,
          label: label,
          helperText: overrideValue != null ? 'Formula: $formulaValue' : null,
        ),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (text) => _updateIntOverride(
          formulaValue: formulaValue,
          text: text,
          current: overrideValue,
          setter: onOverrideChanged,
          controller: controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = _formula;
    final abilityWarning = _abilityAssignmentWarning();
    final userFeatureCount =
        _features.where((feat) => !feat.isAuto).length;
    final ancestral = _budgetSlotCount(FeatureBudgetSlot.ancestral);
    final role = _budgetSlotCount(FeatureBudgetSlot.role);
    final misc = _budgetSlotCount(FeatureBudgetSlot.misc);
    final effectiveWalk = (int.tryParse(_walkController.text.trim()) ?? 30) +
        f.speedWalkDelta;

    return Form(
      key: _formKey,
      child: Column(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _size,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Size',
                  ),
                  items: [
                    for (final s in _creatureSizes)
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _size = value);
                  },
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: TextFormField(
                  controller: _creatureTypeController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Type',
                    hintText: 'e.g. humanoid',
                  ),
                ),
              ),
            ],
          ),
          _section('Combat'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _levelController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Level',
                    helperText: '0–30',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _onLevelChanged(),
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: DropdownButtonFormField<ScalerRank>(
                  initialValue: _rank,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Rank',
                  ),
                  items: [
                    for (final rank in ScalerRank.values)
                      DropdownMenuItem(
                        value: rank,
                        child: Text(rank.label),
                      ),
                  ],
                  onChanged: _onRankChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _threatController,
                  enabled: _rank == ScalerRank.paragon,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Threat',
                    helperText: _rank == ScalerRank.paragon
                        ? 'Paragon threat level'
                        : 'Only for Paragon rank',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (_) => _onThreatChanged(),
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: DropdownButtonFormField<ScalerRole?>(
                  initialValue: _role,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Role',
                  ),
                  items: [
                    const DropdownMenuItem<ScalerRole?>(
                      value: null,
                      child: Text('None'),
                    ),
                    for (final role in ScalerRole.values)
                      DropdownMenuItem(
                        value: role,
                        child: Text(role.label),
                      ),
                  ],
                  onChanged: _onRoleChanged,
                ),
              ),
            ],
          ),
          if (_role != null) ...[
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            DropdownButtonFormField<String?>(
              initialValue: _roleSubtype,
              decoration: ResourceFormStyles.inputDecoration(
                context,
                label: 'Role subtype',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('None'),
                ),
                for (final subtype in _role!.subtypes)
                  DropdownMenuItem(
                    value: subtype,
                    child: Text(subtype),
                  ),
              ],
              onChanged: (value) => setState(() => _roleSubtype = value),
            ),
          ],
          _section('Live stats'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit values to override formula (${f.proficiencyBonus} PB)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statField(
                        label: 'AC',
                        controller: _acController,
                        formulaValue: f.ac,
                        overrideValue: _overrides.ac,
                        onOverrideChanged: (v) => setState(
                          () => _overrides = _overrides.copyWith(
                            ac: v,
                            clearAc: v == null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statField(
                        label: 'HP',
                        controller: _hpController,
                        formulaValue: f.hp,
                        overrideValue: _overrides.hp,
                        onOverrideChanged: (v) => setState(
                          () => _overrides = _overrides.copyWith(
                            hp: v,
                            clearHp: v == null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _statField(
                        label: 'ATK',
                        controller: _atkController,
                        formulaValue: f.atk,
                        overrideValue: _overrides.atk,
                        onOverrideChanged: (v) => setState(
                          () => _overrides = _overrides.copyWith(
                            atk: v,
                            clearAtk: v == null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statField(
                        label: 'DC',
                        controller: _dcController,
                        formulaValue: f.dc,
                        overrideValue: _overrides.dc,
                        onOverrideChanged: (v) => setState(
                          () => _overrides = _overrides.copyWith(
                            dc: v,
                            clearDc: v == null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statField(
                        label: 'DMG',
                        controller: _dmgController,
                        formulaValue: f.dmg,
                        overrideValue: _overrides.dmg,
                        onOverrideChanged: (v) => setState(
                          () => _overrides = _overrides.copyWith(
                            dmg: v,
                            clearDmg: v == null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _statField(
                        label: 'Init',
                        controller: _initController,
                        formulaValue: f.initiativeBonus,
                        overrideValue: _overrides.initiativeBonus,
                        onOverrideChanged: (v) => setState(
                          () => _overrides = _overrides.copyWith(
                            initiativeBonus: v,
                            clearInitiativeBonus: v == null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _crController,
                          decoration: ResourceFormStyles.inputDecoration(
                            context,
                            label: 'CR',
                            helperText: _overrides.cr != null
                                ? 'Formula: ${f.cr}'
                                : null,
                          ),
                          onChanged: _updateCrOverride,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statField(
                        label: 'XP',
                        controller: _xpController,
                        formulaValue: f.xp,
                        overrideValue: _overrides.xp,
                        onOverrideChanged: (v) => setState(
                          () => _overrides = _overrides.copyWith(
                            xp: v,
                            clearXp: v == null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _section('Ability assignment'),
          if (abilityWarning != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                abilityWarning,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontSize: 13,
                ),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final key in AbilityKey.values)
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<_AbilityTier>(
                    initialValue: _abilityTiers[key],
                    decoration: ResourceFormStyles.inputDecoration(
                      context,
                      label: key.label,
                    ),
                    items: [
                      for (final tier in _AbilityTier.values)
                        DropdownMenuItem(
                          value: tier,
                          child: Text(tier.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _abilityTiers[key] = value);
                    },
                  ),
                ),
            ],
          ),
          _section('Trained saves'),
          Text(
            'Select ${f.trainedSaveCount} save(s)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: [
              for (var i = 0; i < _saveKeys.length; i++)
                FilterChip(
                  label: Text(_saveLabels[i]),
                  selected: _trainedSaves.contains(_saveKeys[i]),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        if (!_trainedSaves.contains(_saveKeys[i])) {
                          _trainedSaves.add(_saveKeys[i]);
                        }
                      } else {
                        _trainedSaves.remove(_saveKeys[i]);
                      }
                    });
                  },
                ),
            ],
          ),
          _section('Attack'),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _reachController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Reach (ft.)',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: TextFormField(
                  controller: _rangeController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Range (ft.)',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          _section('Speeds'),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _walkController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Walk (ft.)',
                    helperText: f.speedWalkDelta == 0
                        ? 'Effective: $effectiveWalk ft.'
                        : 'Effective: $effectiveWalk ft. (${f.speedWalkDelta >= 0 ? '+' : ''}${f.speedWalkDelta} from role)',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: TextFormField(
                  controller: _flyController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Fly (ft.)',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _swimController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Swim (ft.)',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: TextFormField(
                  controller: _climbController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Climb (ft.)',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: TextFormField(
                  controller: _burrowController,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Burrow (ft.)',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ],
          ),
          _section('Extras'),
          TextFormField(
            controller: _sensesController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Senses',
              hintText: 'darkvision 60 ft., …',
            ),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _skillsController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Skills',
              hintText: 'Stealth +5, Perception +3',
            ),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _passivePerceptionController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Passive Perception',
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _vulnerabilitiesController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Vulnerabilities',
            ),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _resistancesController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Resistances',
            ),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _immunitiesController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Immunities',
            ),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _languagesController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Languages',
            ),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _itemsController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Items',
              hintText: 'Comma-separated or one per line',
            ),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          MarkdownFormField(
            controller: _triggerController,
            label: 'Trigger',
            minLines: 2,
            maxLines: 6,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _countermeasuresController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Countermeasures',
              hintText: 'One per line',
            ),
            minLines: 2,
            maxLines: 6,
          ),
          _section('Features'),
          Text(
            'Budget: $userFeatureCount custom features '
            '(recommended ${f.featureBudgetMin}–${f.featureBudgetMax})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Slots — ancestral: $ancestral · role: $role · misc: $misc',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _features.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Chip(
                label: Text(
                  _featureBadge(_features[i]),
                  style: const TextStyle(fontSize: 11),
                ),
                visualDensity: VisualDensity.compact,
              ),
              title: Text(_features[i].displayName),
              subtitle: Text(_featureSubtitle(_features[i])),
              trailing: _features[i].isAuto
                  ? IconButton(
                      icon: const Icon(Icons.visibility_outlined),
                      onPressed: () => _viewAutoFeature(i),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_features[i].source ==
                            CreatureFeatureSource.catalog)
                          IconButton(
                            tooltip: 'Detach from catalog',
                            icon: const Icon(Icons.link_off_outlined),
                            onPressed: () => _detachCatalogFeature(i),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editFeature(i),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () {
                            setState(() => _features.removeAt(i));
                          },
                        ),
                      ],
                    ),
              onTap: _features[i].isAuto
                  ? () => _viewAutoFeature(i)
                  : _features[i].source == CreatureFeatureSource.catalog
                      ? null
                      : () => _editFeature(i),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: _addLocalFeature,
                icon: const Icon(Icons.add),
                label: const Text('Add local'),
              ),
              if (widget.auth != null)
                TextButton.icon(
                  onPressed: _addCatalogFeature,
                  icon: const Icon(Icons.library_books_outlined),
                  label: const Text('From catalog'),
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
