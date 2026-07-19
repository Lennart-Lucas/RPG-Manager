import 'package:flutter/material.dart';

import 'package:rpg_manager/features/auth/data/auth_api.dart';
import 'package:rpg_manager/features/auth/state/auth_controller.dart';
import 'package:rpg_manager/features/catalog/data/catalog_api.dart';
import 'package:rpg_manager/features/catalog/data/catalog_kind.dart';
import 'package:rpg_manager/features/catalog/data/catalog_models.dart';
import 'package:rpg_manager/features/dm_tools/resources/ui/resource_form_helpers.dart';
import 'package:rpg_manager/features/mechanics/features/data/feature_model.dart';
import 'package:rpg_manager/features/mechanics/features/ui/feature_form_sheet.dart';
import 'package:rpg_manager/features/player_options/skills/data/skill_model.dart';
import 'package:rpg_manager/features/world/creature_types/data/creature_type_model.dart';
import 'package:rpg_manager/features/world/creatures/data/ability_assignment.dart';
import 'package:rpg_manager/features/world/creatures/data/creature_inheritance.dart';
import 'package:rpg_manager/features/world/creatures/data/creature_model.dart';
import 'package:rpg_manager/features/world/creatures/data/scaler_math.dart';
import 'package:rpg_manager/features/world/creatures/ui/attribute_assignment_panel.dart';
import 'package:rpg_manager/features/world/creatures/ui/creature_statblock_view.dart';
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
  final form = _CreatureForm(initial: initial, auth: auth);

  if (width >= 1000) {
    return showDialog<Creature>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400, maxHeight: 900),
          child: _CreatureFormScaffold(
            title: title,
            compact: false,
            child: form,
          ),
        ),
      ),
    );
  }

  if (width < 720) {
    return showModalBottomSheet<Creature>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.92,
        child: _CreatureFormScaffold(
          title: title,
          compact: true,
          child: form,
        ),
      ),
    );
  }

  return showDialog<Creature>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: _CreatureFormScaffold(
          title: title,
          compact: false,
          child: form,
        ),
      ),
    ),
  );
}

/// Title + expanded body (no outer scroll) so the form can pin a footer.
class _CreatureFormScaffold extends StatelessWidget {
  const _CreatureFormScaffold({
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
  /// 0 = identity/combat/extras, 1 = features.
  int _page = 0;

  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late int _level = (widget.initial?.level ?? 1).clamp(0, 30);
  late final _threatController = TextEditingController(
    text: '${widget.initial?.threat ?? 4}',
  );

  late String _size = widget.initial?.size ?? 'Medium';
  late int? _creatureTypeId = widget.initial?.creatureTypeId;
  late int? _creatureSubtypeId = widget.initial?.creatureSubtypeId;
  late List<LabeledAmount> _movementLabeled = widget.initial != null
      ? movementFromSpeeds(widget.initial!.speeds)
      : const [LabeledAmount(label: 'Normal', amount: 30)];
  late List<LabeledAmount> _sensesLabeled = [
    ...?widget.initial?.sensesLabeled,
  ];
  late List<int> _skillIds = [...?widget.initial?.skillIds];
  late List<int> _skillExpertiseIds = [...?widget.initial?.skillExpertiseIds];
  late List<int> _languageIds = [...?widget.initial?.languageIds];
  late List<int> _vulnerabilityIds = [...?widget.initial?.damageVulnerabilityIds];
  late List<int> _resistanceIds = [...?widget.initial?.damageResistanceIds];
  late List<int> _immunityIds = [...?widget.initial?.damageImmunityIds];
  late List<int> _conditionIds = [...?widget.initial?.conditionImmunityIds];
  late List<String> _customSkills = [...?widget.initial?.customSkills];
  late List<String> _customSkillExpertise = [
    ...?widget.initial?.customSkillExpertise,
  ];
  late List<String> _customLanguages = [...?widget.initial?.customLanguages];
  late List<String> _customVulnerabilities =
      [...?widget.initial?.customDamageVulnerabilities];
  late List<String> _customResistances =
      [...?widget.initial?.customDamageResistances];
  late List<String> _customImmunities =
      [...?widget.initial?.customDamageImmunities];
  late List<CreatureType> _creatureTypes = const [];
  late Map<int, String> _skillNames = const {};
  late Map<int, String> _skillAttributes = const {};
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
  late final CreatureOverrides _overrides =
      widget.initial?.overrides ?? const CreatureOverrides();

  ScalerComputedStats get _formula => computeScalerStats(
        level: _level,
        rank: _rank,
        role: _role,
        paragonThreat: _rank == ScalerRank.paragon ? _threat : null,
      );

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
        _skillAttributes = {
          for (final i in results[1])
            i.id: SkillRecord.fromCatalogPayload(
              name: i.name,
              payload: i.payload,
            ).attribute,
        };
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
      _skillExpertiseIds = [
        for (final id in merged.skillExpertiseIds)
          if (merged.skillIds.contains(id)) id,
      ];
      _customSkillExpertise = [
        for (final name in merged.customSkillExpertise)
          if (merged.customSkills.any(
            (s) => s.toLowerCase() == name.toLowerCase(),
          ))
            name,
      ];
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
      final typeId = _creatureSubtypeId ?? _creatureTypeId;
      if (typeId != null) {
        final primary = _typesById[typeId];
        if (primary != null) {
          var movement = _movementLabeled;
          for (final type in creatureTypeAncestry(
            type: primary,
            byId: _typesById,
          )) {
            movement = mergeLabeledAmounts(movement, type.movement);
          }
          _movementLabeled = movement;
        }
      } else {
        _movementLabeled = movementFromSpeeds(merged.speeds);
      }
    });
  }

  CreatureSpeeds get _speedsFromMovement => syncSpeedsFromMovement(
        speeds: const CreatureSpeeds(),
        movement: _movementLabeled,
      );

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
      speeds: _speedsFromMovement,
      sensesLabeled: _sensesLabeled,
      skillIds: _skillIds,
      customSkills: _customSkills,
      skillExpertiseIds: _skillExpertiseIds,
      customSkillExpertise: _customSkillExpertise,
      languageIds: _languageIds,
      customLanguages: _customLanguages,
      damageVulnerabilityIds: _vulnerabilityIds,
      customDamageVulnerabilities: _customVulnerabilities,
      damageResistanceIds: _resistanceIds,
      customDamageResistances: _customResistances,
      damageImmunityIds: _immunityIds,
      customDamageImmunities: _customImmunities,
      conditionImmunityIds: _conditionIds,
      items: widget.initial?.items ?? const [],
      trigger: widget.initial?.trigger,
      countermeasures: widget.initial?.countermeasures ?? const [],
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

  @override
  void dispose() {
    _nameController.dispose();
    _threatController.dispose();
    super.dispose();
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

  void _onLevelChanged(int? value) {
    if (value == null) return;
    setState(() => _level = value);
    _recomputeCombat();
  }

  void _onThreatChanged() {
    final parsed = num.tryParse(_threatController.text.trim());
    if (parsed != null) {
      setState(() => _threat = parsed);
      _recomputeCombat();
    }
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

  void _goToFeatures() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    setState(() => _page = 1);
  }

  void _goToMain() {
    setState(() => _page = 0);
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
    final f = _formula;
    final draft = _buildDraftCreature();
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final previewSheet = CreatureStatblockView(
      creature: draft,
      typeLabel: draft.creatureType.isEmpty ? null : draft.creatureType,
      skillNames: _skillNames,
      skillAttributes: _skillAttributes,
      conditionNames: _conditionNames,
    );
    final pageBody = _page == 0 ? _buildMainPage(f) : _buildFeaturesPage(f);
    final scrollPadding = EdgeInsets.fromLTRB(
      wide ? 20 : 20,
      wide ? 20 : 20,
      wide ? 20 : 20,
      20,
    );

    final scrollableForm = SingleChildScrollView(
      padding: scrollPadding,
      child: wide
          ? pageBody
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                pageBody,
                if (_page == 0)
                  ExpansionTile(
                    title: const Text('Preview'),
                    children: [previewSheet],
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
                  child: previewSheet,
                ),
              ),
            ],
          )
        : scrollableForm;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: body),
          const Divider(height: 1),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: _page == 0
          ? FilledButton(
              onPressed: _goToFeatures,
              child: const Text('Next'),
            )
          : Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _goToMain,
                    child: const Text('Back'),
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
            ),
    );
  }

  Widget _buildMainPage(ScalerComputedStats f) {
    final abilityWarning = _abilityAssignmentWarning();
    final walk = walkSpeedFromMovement(_movementLabeled) ?? 30;
    final effectiveWalk = walk + f.speedWalkDelta;
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
                child: DropdownButtonFormField<int>(
                  initialValue: _level,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Level',
                  ),
                  items: [
                    for (var level = 0; level <= 30; level++)
                      DropdownMenuItem(
                        value: level,
                        child: Text('$level'),
                      ),
                  ],
                  onChanged: _onLevelChanged,
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
          _section('Ability assignment'),
          Text(
            'Long-press an ability box to toggle trained saves '
            '(${_trainedAbilityKeys.length}/${f.trainedSaveCount})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (abilityWarning != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                abilityWarning,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.tertiary,
                  fontSize: 13,
                ),
              ),
            )
          else
            const SizedBox(height: 8),
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
          _section('Extras'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LabeledAmountEditor(
                  title: 'Movement',
                  presets: movementPresets,
                  items: _movementLabeled,
                  onChanged: (next) => setState(() => _movementLabeled = next),
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: LabeledAmountEditor(
                  title: 'Senses',
                  presets: sensePresets,
                  items: _sensesLabeled,
                  onChanged: (next) => setState(() => _sensesLabeled = next),
                ),
              ),
            ],
          ),
          if (f.speedWalkDelta != 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Effective walk: $effectiveWalk ft. '
                '(${f.speedWalkDelta >= 0 ? '+' : ''}${f.speedWalkDelta} from role)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: catalogMultiPickTile(
                  context: context,
                  label: 'Skills',
                  labels: catalogSelectionLabels(
                    selected: _skillIds.toSet(),
                    namesById: _skillNames,
                    customStrings: _customSkills,
                    expertiseIds: _skillExpertiseIds.toSet(),
                    expertiseCustoms: _customSkillExpertise,
                  ),
                  onTap: () => pickCatalogIdsWithCustoms(
                    context: context,
                    title: 'Skills',
                    options: catalogPicklistOptions(_skillNames),
                    selected: _skillIds.toSet(),
                    customStrings: _customSkills,
                    enableExpertise: true,
                    expertiseIds: _skillExpertiseIds.toSet(),
                    expertiseCustoms: _customSkillExpertise,
                    onDone: (next) => setState(() {
                      _skillIds = next.ids;
                      _customSkills = next.customs;
                      _skillExpertiseIds = next.expertiseIds;
                      _customSkillExpertise = next.expertiseCustoms;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: catalogMultiPickTile(
                  context: context,
                  label: 'Languages',
                  labels: catalogSelectionLabels(
                    selected: _languageIds.toSet(),
                    namesById: _languageNames,
                    customStrings: _customLanguages,
                  ),
                  onTap: () => pickCatalogIdsWithCustoms(
                    context: context,
                    title: 'Languages',
                    options: catalogPicklistOptions(_languageNames),
                    selected: _languageIds.toSet(),
                    customStrings: _customLanguages,
                    onDone: (next) => setState(() {
                      _languageIds = next.ids;
                      _customLanguages = next.customs;
                    }),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: catalogMultiPickTile(
                  context: context,
                  label: 'Damage Vulnerabilities',
                  labels: catalogSelectionLabels(
                    selected: _vulnerabilityIds.toSet(),
                    namesById: _damageTypeNames,
                    customStrings: _customVulnerabilities,
                  ),
                  onTap: () => pickCatalogIdsWithCustoms(
                    context: context,
                    title: 'Damage Vulnerabilities',
                    options: catalogPicklistOptions(_damageTypeNames),
                    selected: _vulnerabilityIds.toSet(),
                    customStrings: _customVulnerabilities,
                    onDone: (next) => setState(() {
                      _vulnerabilityIds = next.ids;
                      _customVulnerabilities = next.customs;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: catalogMultiPickTile(
                  context: context,
                  label: 'Damage Resistances',
                  labels: catalogSelectionLabels(
                    selected: _resistanceIds.toSet(),
                    namesById: _damageTypeNames,
                    customStrings: _customResistances,
                  ),
                  onTap: () => pickCatalogIdsWithCustoms(
                    context: context,
                    title: 'Damage Resistances',
                    options: catalogPicklistOptions(_damageTypeNames),
                    selected: _resistanceIds.toSet(),
                    customStrings: _customResistances,
                    onDone: (next) => setState(() {
                      _resistanceIds = next.ids;
                      _customResistances = next.customs;
                    }),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: catalogMultiPickTile(
                  context: context,
                  label: 'Damage Immunities',
                  labels: catalogSelectionLabels(
                    selected: _immunityIds.toSet(),
                    namesById: _damageTypeNames,
                    customStrings: _customImmunities,
                  ),
                  onTap: () => pickCatalogIdsWithCustoms(
                    context: context,
                    title: 'Damage Immunities',
                    options: catalogPicklistOptions(_damageTypeNames),
                    selected: _immunityIds.toSet(),
                    customStrings: _customImmunities,
                    onDone: (next) => setState(() {
                      _immunityIds = next.ids;
                      _customImmunities = next.customs;
                    }),
                  ),
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: catalogMultiPickTile(
                  context: context,
                  label: 'Condition Immunities',
                  labels: catalogSelectionLabels(
                    selected: _conditionIds.toSet(),
                    namesById: _conditionNames,
                  ),
                  onTap: () => pickCatalogIds(
                    context: context,
                    title: 'Condition Immunities',
                    options: catalogPicklistOptions(_conditionNames),
                    selected: _conditionIds.toSet(),
                    onDone: (next) =>
                        setState(() => _conditionIds = next.toList()),
                  ),
                ),
              ),
            ],
          ),
        ],
    );
  }

  Widget _buildFeaturesPage(ScalerComputedStats f) {
    final userFeatureCount = _features.where((feat) => !feat.isAuto).length;
    final ancestral = _budgetSlotCount(FeatureBudgetSlot.ancestral);
    final roleCount = _budgetSlotCount(FeatureBudgetSlot.role);
    final misc = _budgetSlotCount(FeatureBudgetSlot.misc);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                      if (_features[i].source == CreatureFeatureSource.catalog)
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
      ],
    );
  }
}
