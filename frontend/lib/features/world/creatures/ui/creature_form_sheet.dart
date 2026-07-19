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
import 'package:rpg_manager/features/world/creature_types/data/creature_type_model.dart';
import 'package:rpg_manager/features/world/creatures/data/ability_assignment.dart';
import 'package:rpg_manager/features/world/creatures/data/creature_combat_snapshot.dart';
import 'package:rpg_manager/features/world/creatures/data/creature_inheritance.dart';
import 'package:rpg_manager/features/world/creatures/data/creature_model.dart';
import 'package:rpg_manager/features/world/creatures/data/scaler_math.dart';
import 'package:rpg_manager/features/world/creatures/ui/attribute_assignment_panel.dart';
import 'package:rpg_manager/features/world/creatures/ui/creature_statblock_view.dart';
import 'package:rpg_manager/features/world/creatures/ui/statblock_combat_preview.dart';
import 'package:rpg_manager/features/world/data/labeled_amount.dart';
import 'package:rpg_manager/features/world/ui/world_form_helpers.dart';

Future<Creature?> showCreatureFormSheet(
  BuildContext context, {
  Creature? initial,
  AuthController? auth,
}) {
  final editing = initial != null;
  final title = editing ? 'Edit creature' : 'New creature';
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 1000) {
    return showDialog<Creature>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400, maxHeight: 900),
          child: _WideCreatureFormScaffold(
            title: title,
            child: _CreatureForm(initial: initial, auth: auth),
          ),
        ),
      ),
    );
  }
  return showAdaptiveResourceForm<Creature>(
    context,
    title: title,
    child: _CreatureForm(initial: initial, auth: auth),
  );
}

class _WideCreatureFormScaffold extends StatelessWidget {
  const _WideCreatureFormScaffold({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
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

const _creatureSizes = [
  'Tiny',
  'Small',
  'Medium',
  'Large',
  'Huge',
  'Gargantuan',
];

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
  late final _passivePerceptionController = TextEditingController(
    text: '${widget.initial?.passivePerception ?? 10}',
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
  late int? _creatureTypeId = widget.initial?.creatureTypeId;
  late int? _creatureSubtypeId = widget.initial?.creatureSubtypeId;
  late List<LabeledAmount> _movementLabeled = const [];
  late List<LabeledAmount> _sensesLabeled = [
    ...?widget.initial?.sensesLabeled,
  ];
  late List<int> _skillIds = [...?widget.initial?.skillIds];
  late List<int> _languageIds = [...?widget.initial?.languageIds];
  late List<int> _vulnerabilityIds = [...?widget.initial?.damageVulnerabilityIds];
  late List<int> _resistanceIds = [...?widget.initial?.damageResistanceIds];
  late List<int> _immunityIds = [...?widget.initial?.damageImmunityIds];
  late List<int> _conditionIds = [...?widget.initial?.conditionImmunityIds];
  late List<String> _customSkills = [...?widget.initial?.customSkills];
  late List<String> _customLanguages = [...?widget.initial?.customLanguages];
  late List<String> _customVulnerabilities =
      [...?widget.initial?.customDamageVulnerabilities];
  late List<String> _customResistances =
      [...?widget.initial?.customDamageResistances];
  late List<String> _customImmunities =
      [...?widget.initial?.customDamageImmunities];
  late List<CreatureType> _creatureTypes = const [];
  late Map<int, String> _skillNames = const {};
  late Map<int, String> _languageNames = const {};
  late Map<int, String> _damageTypeNames = const {};
  late Map<int, String> _conditionNames = const {};
  late Map<AbilityKey, String> _assignments = {};
  late Set<AbilityKey> _trainedAbilityKeys = {};
  late ScalerRank _rank = widget.initial?.rank ?? ScalerRank.grunt;
  late ScalerRole? _role = widget.initial?.role;
  late String? _roleSubtype = widget.initial?.roleSubtype;
  late num _threat =
      widget.initial?.threat ?? effectiveThreat(ScalerRank.grunt);
  late List<CreatureFeatureEntry> _features = [
    ...(widget.initial?.features ?? const []),
  ];
  late CreatureOverrides _overrides =
      widget.initial?.overrides ?? const CreatureOverrides();

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
    _assignments = abilityAssignmentsFromScores(
      scores: widget.initial?.abilityScores ??
          defaultAbilityAssignment(_formula),
      formula: _formula,
    );
    _trainedAbilityKeys = trainedAbilityKeysFromSaves(
      widget.initial?.trainedSavingThrows ?? const [],
    );
    _initStatControllers();
    _loadCatalogData();
  }

  Future<void> _loadCatalogData() async {
    final auth = widget.auth;
    if (auth == null) return;
    try {
      final token = await auth.requireAccessToken();
      if (token == null || !mounted) return;
      final api = CatalogApi();
      final results = await Future.wait([
        api.list(token, CatalogKind.creatureTypes),
        api.list(token, CatalogKind.skills),
        api.list(token, CatalogKind.languages),
        api.list(token, CatalogKind.damageTypes),
        api.list(token, CatalogKind.conditions),
      ]);
      if (!mounted) return;
      setState(() {
        _creatureTypes = [
          for (final item in results[0])
            CreatureType.fromCatalogPayload(
              id: item.id,
              name: item.name,
              payload: item.payload,
            ),
        ];
        _skillNames = {for (final i in results[1]) i.id: i.name};
        _languageNames = {for (final i in results[2]) i.id: i.name};
        _damageTypeNames = {for (final i in results[3]) i.id: i.name};
        _conditionNames = {for (final i in results[4]) i.id: i.name};
      });
    } catch (_) {}
  }

  Map<int, CreatureType> get _typesById => {
        for (final type in _creatureTypes) type.id: type,
      };

  List<CreatureType> get _rootCreatureTypes =>
      creatureTypeRoots(_creatureTypes);

  List<CreatureType> _subtypeOptions(int? typeId) {
    if (typeId == null) return const [];
    return _creatureTypes
        .where((t) => t.parentCreatureTypeId == typeId)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void _applyTypeInheritance({bool replace = false}) {
    final draft = _buildDraftCreature();
    final merged = mergeCreatureTypeInheritance(
      creature: draft,
      typesById: _typesById,
      creatureTypeId: _creatureTypeId,
      creatureSubtypeId: _creatureSubtypeId,
    );
    setState(() {
      _size = merged.size;
      _skillIds = merged.skillIds;
      _customSkills = merged.customSkills;
      _languageIds = merged.languageIds;
      _customLanguages = merged.customLanguages;
      _vulnerabilityIds = merged.damageVulnerabilityIds;
      _customVulnerabilities = merged.customDamageVulnerabilities;
      _resistanceIds = merged.damageResistanceIds;
      _customResistances = merged.customDamageResistances;
      _immunityIds = merged.damageImmunityIds;
      _customImmunities = merged.customDamageImmunities;
      _conditionIds = merged.conditionImmunityIds;
      _sensesLabeled = merged.sensesLabeled;
      _features = merged.features;
      _walkController.text = '${merged.speeds.walk}';
      if (merged.speeds.fly != null) {
        _flyController.text = '${merged.speeds.fly}';
      }
      if (merged.speeds.swim != null) {
        _swimController.text = '${merged.speeds.swim}';
      }
      if (merged.speeds.climb != null) {
        _climbController.text = '${merged.speeds.climb}';
      }
      if (merged.speeds.burrow != null) {
        _burrowController.text = '${merged.speeds.burrow}';
      }
    });
  }

  Creature _buildDraftCreature() {
    return Creature(
      id: widget.initial?.id ?? Creature.slugify(_nameController.text.trim()),
      name: _nameController.text.trim(),
      size: _size,
      creatureType: _resolvedTypeLabel(),
      creatureTypeId: _creatureTypeId,
      creatureSubtypeId: _creatureSubtypeId,
      level: _level,
      rank: _rank,
      threat: _rank == ScalerRank.paragon ? _threat : effectiveThreat(_rank),
      role: _role,
      roleSubtype: _roleSubtype,
      abilityScores: abilityScoresFromAssignments(
        assignments: _assignments,
        slotModifiers: slotModifiersForFormula(_formula),
      ),
      trainedSavingThrows: trainedSavesFromAbilityKeys(_trainedAbilityKeys),
      reach: _parseOptionalInt(_reachController.text),
      range: _parseOptionalInt(_rangeController.text),
      speeds: CreatureSpeeds(
        walk: int.tryParse(_walkController.text.trim()) ?? 30,
        fly: _parseOptionalInt(_flyController.text),
        swim: _parseOptionalInt(_swimController.text),
        climb: _parseOptionalInt(_climbController.text),
        burrow: _parseOptionalInt(_burrowController.text),
      ),
      sensesLabeled: _sensesLabeled,
      passivePerception:
          int.tryParse(_passivePerceptionController.text.trim()) ?? 10,
      skillIds: _skillIds,
      customSkills: _customSkills,
      languageIds: _languageIds,
      customLanguages: _customLanguages,
      damageVulnerabilityIds: _vulnerabilityIds,
      customDamageVulnerabilities: _customVulnerabilities,
      damageResistanceIds: _resistanceIds,
      customDamageResistances: _customResistances,
      damageImmunityIds: _immunityIds,
      customDamageImmunities: _customImmunities,
      conditionImmunityIds: _conditionIds,
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
    ).copyWithResolvedDisplayLists(
      skillNames: _skillNames,
      languageNames: _languageNames,
      damageTypeNames: _damageTypeNames,
      conditionNames: _conditionNames,
    );
  }

  String _resolvedTypeLabel() {
    final typeName =
        _creatureTypeId != null ? _typesById[_creatureTypeId!]?.name : null;
    final subtypeName = _creatureSubtypeId != null
        ? _typesById[_creatureSubtypeId!]?.name
        : null;
    if (subtypeName != null && subtypeName.isNotEmpty) {
      if (typeName != null && typeName.isNotEmpty) {
        return '$typeName ($subtypeName)';
      }
      return subtypeName;
    }
    return typeName ?? widget.initial?.creatureType ?? '';
  }

  void _syncMovementToSpeeds(List<LabeledAmount> movement) {
    final speeds = syncSpeedsFromMovement(
      speeds: CreatureSpeeds(
        walk: int.tryParse(_walkController.text.trim()) ?? 30,
        fly: _parseOptionalInt(_flyController.text),
        swim: _parseOptionalInt(_swimController.text),
        climb: _parseOptionalInt(_climbController.text),
        burrow: _parseOptionalInt(_burrowController.text),
      ),
      movement: movement,
    );
    _walkController.text = '${speeds.walk}';
    _flyController.text = speeds.fly?.toString() ?? '';
    _swimController.text = speeds.swim?.toString() ?? '';
    _climbController.text = speeds.climb?.toString() ?? '';
    _burrowController.text = speeds.burrow?.toString() ?? '';
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
    _levelController.dispose();
    _threatController.dispose();
    _reachController.dispose();
    _rangeController.dispose();
    _walkController.dispose();
    _flyController.dispose();
    _swimController.dispose();
    _climbController.dispose();
    _burrowController.dispose();
    _passivePerceptionController.dispose();
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
        final match = _skillNames.entries.firstWhere(
          (e) => e.value.toLowerCase() == granted.toLowerCase(),
          orElse: () => const MapEntry(-1, ''),
        );
        if (match.key != -1 && !_skillIds.contains(match.key)) {
          _skillIds = [..._skillIds, match.key];
        } else if (!_customSkills.any(
          (s) => s.toLowerCase() == granted.toLowerCase(),
        )) {
          _customSkills = [..._customSkills, granted];
        }
      }
      _assignments = abilityAssignmentsFromScores(
        scores: abilityScoresFromAssignments(
          assignments: _assignments,
          slotModifiers: slotModifiersForFormula(f),
        ),
        formula: f,
      );
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
    final slots = _assignments.values;
    final high = slots.where((s) => s.startsWith('high')).length;
    final mid = slots.where((s) => s.startsWith('medium')).length;
    final low = slots.where((s) => s.startsWith('low')).length;
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
    final f = _formula;
    var trained = trainedSavesFromAbilityKeys(_trainedAbilityKeys);
    if (trained.length > f.trainedSaveCount) {
      trained = trained.take(f.trainedSaveCount).toList();
    }
    final creature = _buildDraftCreature().copyWith(
      trainedSavingThrows: trained,
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
    final draft = _buildDraftCreature();
    final previewSnapshot = computeCreatureCombatSnapshot(draft);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final form = SingleChildScrollView(
      padding: EdgeInsets.all(wide ? 20 : 0),
      child: _buildFormFields(f),
    );
    final preview = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatblockCombatPreview(snapshot: previewSnapshot),
          const SizedBox(height: 12),
          CreatureStatblockView(creature: draft),
        ],
      ),
    );

    if (wide) {
      return Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: form),
            const VerticalDivider(width: 1),
            Expanded(flex: 4, child: preview),
          ],
        ),
      );
    }

    // Parent `showAdaptiveResourceForm` already provides a scroll view.
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFormFields(f),
          ExpansionTile(
            title: const Text('Preview'),
            children: [
              StatblockCombatPreview(snapshot: previewSnapshot),
              const SizedBox(height: 12),
              CreatureStatblockView(creature: draft),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields(ScalerComputedStats f) {
    final abilityWarning = _abilityAssignmentWarning();
    final userFeatureCount =
        _features.where((feat) => !feat.isAuto).length;
    final ancestral = _budgetSlotCount(FeatureBudgetSlot.ancestral);
    final roleCount = _budgetSlotCount(FeatureBudgetSlot.role);
    final misc = _budgetSlotCount(FeatureBudgetSlot.misc);
    final effectiveWalk = (int.tryParse(_walkController.text.trim()) ?? 30) +
        f.speedWalkDelta;
    final slotModifiers = slotModifiersForFormula(f);

    return Column(
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
                child: DropdownButtonFormField<int?>(
                  initialValue: _creatureTypeId,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Creature type',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None'),
                    ),
                    for (final type in _rootCreatureTypes)
                      DropdownMenuItem(
                        value: type.id,
                        child: Text(type.name),
                      ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _creatureTypeId = value;
                      if (_creatureSubtypeId != null &&
                          _subtypeOptions(value)
                              .every((t) => t.id != _creatureSubtypeId)) {
                        _creatureSubtypeId = null;
                      }
                    });
                    _applyTypeInheritance();
                  },
                ),
              ),
            ],
          ),
          if (_creatureTypeId != null) ...[
            const SizedBox(height: ResourceFormStyles.fieldSpacing),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int?>(
                    initialValue: _creatureSubtypeId,
                    decoration: ResourceFormStyles.inputDecoration(
                      context,
                      label: 'Subtype',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('None'),
                      ),
                      for (final subtype
                          in _subtypeOptions(_creatureTypeId))
                        DropdownMenuItem(
                          value: subtype.id,
                          child: Text(subtype.name),
                        ),
                    ],
                    onChanged: (value) {
                      setState(() => _creatureSubtypeId = value);
                      _applyTypeInheritance();
                    },
                  ),
                ),
                const SizedBox(width: ResourceFormStyles.fieldSpacing),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _applyTypeInheritance,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Re-apply type defaults'),
                    ),
                  ),
                ),
              ],
            ),
          ],
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
              AttributeAssignmentPanel(
                assignments: _assignments,
                slotModifiers: slotModifiers,
                trainedAttributes: _trainedAbilityKeys,
                trainedSavingThrows: f.trainedSaveCount,
                onSwapRequested: (first, second) {
                  setState(() {
                    swapAbilityAssignments(_assignments, first, second);
                  });
                },
                onToggleTrained: (attribute) {
                  setState(() {
                    if (_trainedAbilityKeys.contains(attribute)) {
                      _trainedAbilityKeys.remove(attribute);
                    } else {
                      _trainedAbilityKeys.add(attribute);
                    }
                  });
                },
              ),
            ],
          ),
          _section('Trained saves'),
          Text(
            'Long-press an ability box to toggle trained saves '
            '(${_trainedAbilityKeys.length}/${f.trainedSaveCount})',
            style: Theme.of(context).textTheme.bodySmall,
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
          LabeledAmountEditor(
            title: 'Movement',
            presets: movementPresets,
            items: _movementLabeled,
            onChanged: (next) {
              setState(() {
                _movementLabeled = next;
                _syncMovementToSpeeds(next);
              });
            },
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          LabeledAmountEditor(
            title: 'Senses',
            presets: sensePresets,
            items: _sensesLabeled,
            onChanged: (next) => setState(() => _sensesLabeled = next),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          catalogMultiPickTile(
            context: context,
            label: 'Skills',
            summary: summarizeCatalogSelection(
              selected: _skillIds.toSet(),
              namesById: _skillNames,
            ),
            onTap: () => pickCatalogIds(
              context: context,
              title: 'Skills',
              options: catalogPicklistOptions(_skillNames),
              selected: _skillIds.toSet(),
              onDone: (next) => setState(() => _skillIds = next.toList()),
            ),
          ),
          CustomStringListField(
            label: 'Custom skills',
            values: _customSkills,
            onChanged: (next) => setState(() => _customSkills = next),
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
          catalogMultiPickTile(
            context: context,
            label: 'Vulnerabilities',
            summary: summarizeCatalogSelection(
              selected: _vulnerabilityIds.toSet(),
              namesById: _damageTypeNames,
            ),
            onTap: () => pickCatalogIds(
              context: context,
              title: 'Vulnerabilities',
              options: catalogPicklistOptions(_damageTypeNames),
              selected: _vulnerabilityIds.toSet(),
              onDone: (next) =>
                  setState(() => _vulnerabilityIds = next.toList()),
            ),
          ),
          CustomStringListField(
            label: 'Custom vulnerabilities',
            values: _customVulnerabilities,
            onChanged: (next) => setState(() => _customVulnerabilities = next),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          catalogMultiPickTile(
            context: context,
            label: 'Resistances',
            summary: summarizeCatalogSelection(
              selected: _resistanceIds.toSet(),
              namesById: _damageTypeNames,
            ),
            onTap: () => pickCatalogIds(
              context: context,
              title: 'Resistances',
              options: catalogPicklistOptions(_damageTypeNames),
              selected: _resistanceIds.toSet(),
              onDone: (next) => setState(() => _resistanceIds = next.toList()),
            ),
          ),
          CustomStringListField(
            label: 'Custom resistances',
            values: _customResistances,
            onChanged: (next) => setState(() => _customResistances = next),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          catalogMultiPickTile(
            context: context,
            label: 'Immunities',
            summary: summarizeCatalogSelection(
              selected: _immunityIds.toSet(),
              namesById: _damageTypeNames,
            ),
            onTap: () => pickCatalogIds(
              context: context,
              title: 'Immunities',
              options: catalogPicklistOptions(_damageTypeNames),
              selected: _immunityIds.toSet(),
              onDone: (next) => setState(() => _immunityIds = next.toList()),
            ),
          ),
          CustomStringListField(
            label: 'Custom immunities',
            values: _customImmunities,
            onChanged: (next) => setState(() => _customImmunities = next),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          catalogMultiPickTile(
            context: context,
            label: 'Languages',
            summary: summarizeCatalogSelection(
              selected: _languageIds.toSet(),
              namesById: _languageNames,
            ),
            onTap: () => pickCatalogIds(
              context: context,
              title: 'Languages',
              options: catalogPicklistOptions(_languageNames),
              selected: _languageIds.toSet(),
              onDone: (next) => setState(() => _languageIds = next.toList()),
            ),
          ),
          CustomStringListField(
            label: 'Custom languages',
            values: _customLanguages,
            onChanged: (next) => setState(() => _customLanguages = next),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          catalogMultiPickTile(
            context: context,
            label: 'Condition immunities',
            summary: summarizeCatalogSelection(
              selected: _conditionIds.toSet(),
              namesById: _conditionNames,
            ),
            onTap: () => pickCatalogIds(
              context: context,
              title: 'Condition immunities',
              options: catalogPicklistOptions(_conditionNames),
              selected: _conditionIds.toSet(),
              onDone: (next) => setState(() => _conditionIds = next.toList()),
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
            'Slots — ancestral: $ancestral · role: $roleCount · misc: $misc',
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
    );
  }
}
