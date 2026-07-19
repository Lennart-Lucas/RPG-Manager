import 'package:flutter/material.dart';

import 'package:rpg_manager/core/ui/markdown_form_field.dart';
import 'package:rpg_manager/features/auth/data/auth_api.dart';
import 'package:rpg_manager/features/auth/state/auth_controller.dart';
import 'package:rpg_manager/features/catalog/data/catalog_api.dart';
import 'package:rpg_manager/features/catalog/data/catalog_kind.dart';
import 'package:rpg_manager/features/dm_tools/resources/ui/resource_form_helpers.dart';
import 'package:rpg_manager/features/world/creature_types/data/creature_type_model.dart';
import 'package:rpg_manager/features/world/data/labeled_amount.dart';
import 'package:rpg_manager/features/world/ui/world_form_helpers.dart';

Future<CreatureType?> showCreatureTypeFormSheet(
  BuildContext context, {
  CreatureType? initial,
  required List<CreatureType> allTypes,
  AuthController? auth,
}) {
  final editing = initial != null;
  return showAdaptiveResourceForm<CreatureType>(
    context,
    title: editing ? 'Edit creature type' : 'New creature type',
    child: _CreatureTypeForm(
      initial: initial,
      allTypes: allTypes,
      auth: auth,
    ),
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

class _CreatureTypeForm extends StatefulWidget {
  const _CreatureTypeForm({
    this.initial,
    required this.allTypes,
    this.auth,
  });

  final CreatureType? initial;
  final List<CreatureType> allTypes;
  final AuthController? auth;

  @override
  State<_CreatureTypeForm> createState() => _CreatureTypeFormState();
}

class _CreatureTypeFormState extends State<_CreatureTypeForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.initial?.name ?? '');
  late final _quoteController =
      TextEditingController(text: widget.initial?.quote ?? '');
  late final _authorController =
      TextEditingController(text: widget.initial?.author ?? '');

  late String? _size = widget.initial?.size;
  late int? _parentId = widget.initial?.parentCreatureTypeId;
  late List<LabeledAmount> _movement = [...?widget.initial?.movement];
  late List<LabeledAmount> _senses = [...?widget.initial?.senses];
  late List<int> _languageIds = [...?widget.initial?.languageIds];
  late List<int> _skillIds = [...?widget.initial?.skillIds];
  late List<int> _vulnerabilityIds = [...?widget.initial?.damageVulnerabilityIds];
  late List<int> _resistanceIds = [...?widget.initial?.damageResistanceIds];
  late List<int> _immunityIds = [...?widget.initial?.damageImmunityIds];
  late List<int> _conditionIds = [...?widget.initial?.conditionImmunityIds];
  late List<String> _customLanguages = [...?widget.initial?.customLanguages];
  late List<String> _customVulnerabilities =
      [...?widget.initial?.customDamageVulnerabilities];
  late List<String> _customResistances =
      [...?widget.initial?.customDamageResistances];
  late List<String> _customImmunities =
      [...?widget.initial?.customDamageImmunities];
  late List<CreatureTypeTrait> _traits = [...?widget.initial?.traits];
  late List<CreatureTypeSection> _sections = [...?widget.initial?.sections];

  Map<int, String> _languageNames = const {};
  Map<int, String> _skillNames = const {};
  Map<int, String> _damageTypeNames = const {};
  Map<int, String> _conditionNames = const {};
  bool _loadingLookups = true;

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final auth = widget.auth;
    if (auth == null) {
      if (mounted) setState(() => _loadingLookups = false);
      return;
    }
    try {
      final token = await auth.requireAccessToken();
      if (token == null) {
        if (mounted) setState(() => _loadingLookups = false);
        return;
      }
      final api = CatalogApi();
      final results = await Future.wait([
        api.list(token, CatalogKind.skills),
        api.list(token, CatalogKind.languages),
        api.list(token, CatalogKind.damageTypes),
        api.list(token, CatalogKind.conditions),
      ]);
      if (!mounted) return;
      setState(() {
        _skillNames = {for (final i in results[0]) i.id: i.name};
        _languageNames = {for (final i in results[1]) i.id: i.name};
        _damageTypeNames = {for (final i in results[2]) i.id: i.name};
        _conditionNames = {for (final i in results[3]) i.id: i.name};
        _loadingLookups = false;
      });
    } on AuthApiException {
      if (mounted) setState(() => _loadingLookups = false);
    } catch (_) {
      if (mounted) setState(() => _loadingLookups = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quoteController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Set<int> get _excludedParents => excludedCreatureTypeParentIds(
        editingId: widget.initial?.id,
        allTypes: widget.allTypes,
      );

  List<CreatureType> get _parentOptions {
    return widget.allTypes
        .where((t) => !_excludedParents.contains(t.id))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    final name = _nameController.text.trim();
    Navigator.pop(
      context,
      CreatureType(
        id: widget.initial?.id ?? 0,
        name: name,
        size: _size,
        parentCreatureTypeId: _parentId,
        quote: _quoteController.text.trim(),
        author: _authorController.text.trim(),
        sections: _sections,
        movement: _movement,
        senses: _senses,
        languageIds: _languageIds,
        skillIds: _skillIds,
        damageVulnerabilityIds: _vulnerabilityIds,
        damageResistanceIds: _resistanceIds,
        damageImmunityIds: _immunityIds,
        conditionImmunityIds: _conditionIds,
        customLanguages: _customLanguages,
        customDamageVulnerabilities: _customVulnerabilities,
        customDamageResistances: _customResistances,
        customDamageImmunities: _customImmunities,
        traits: _traits,
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
          TextFormField(
            controller: _nameController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Name',
            ),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _size,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Size',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('None'),
                    ),
                    for (final size in _creatureSizes)
                      DropdownMenuItem(value: size, child: Text(size)),
                  ],
                  onChanged: (value) => setState(() => _size = value),
                ),
              ),
              const SizedBox(width: ResourceFormStyles.fieldSpacing),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  initialValue: _parentId,
                  decoration: ResourceFormStyles.inputDecoration(
                    context,
                    label: 'Parent type',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None (root)'),
                    ),
                    for (final type in _parentOptions)
                      DropdownMenuItem(
                        value: type.id,
                        child: Text(type.name),
                      ),
                  ],
                  onChanged: (value) => setState(() => _parentId = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _quoteController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Quote',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          TextFormField(
            controller: _authorController,
            decoration: ResourceFormStyles.inputDecoration(
              context,
              label: 'Author',
            ),
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          Text(
            'Sections',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          for (var i = 0; i < _sections.length; i++)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _sections[i].title,
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'Title',
                      ),
                      onChanged: (value) {
                        final next = [..._sections];
                        next[i] = CreatureTypeSection(
                          title: value,
                          contents: next[i].contents,
                        );
                        setState(() => _sections = next);
                      },
                    ),
                    const SizedBox(height: 8),
                    MarkdownFormField(
                      initialValue: _sections[i].contents,
                      label: 'Contents',
                      minLines: 3,
                      maxLines: 8,
                      onChanged: (value) {
                        final next = [..._sections];
                        next[i] = CreatureTypeSection(
                          title: next[i].title,
                          contents: value,
                        );
                        setState(() => _sections = next);
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () {
                          setState(
                            () => _sections = [..._sections]..removeAt(i),
                          );
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(
                  () => _sections = [
                    ..._sections,
                    const CreatureTypeSection(title: '', contents: ''),
                  ],
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Add section'),
            ),
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          LabeledAmountEditor(
            title: 'Movement',
            presets: movementPresets,
            items: _movement,
            onChanged: (next) => setState(() => _movement = next),
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          LabeledAmountEditor(
            title: 'Senses',
            presets: sensePresets,
            items: _senses,
            onChanged: (next) => setState(() => _senses = next),
          ),
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          if (_loadingLookups)
            const LinearProgressIndicator()
          else ...[
            catalogMultiPickTile(
              context: context,
              label: 'Skills',
              labels: catalogSelectionLabels(
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
            catalogMultiPickTile(
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
          ],
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          catalogMultiPickTile(
            context: context,
            label: 'Damage vulnerabilities',
            labels: catalogSelectionLabels(
              selected: _vulnerabilityIds.toSet(),
              namesById: _damageTypeNames,
              customStrings: _customVulnerabilities,
            ),
            onTap: () => pickCatalogIdsWithCustoms(
              context: context,
              title: 'Damage vulnerabilities',
              options: catalogPicklistOptions(_damageTypeNames),
              selected: _vulnerabilityIds.toSet(),
              customStrings: _customVulnerabilities,
              onDone: (next) => setState(() {
                _vulnerabilityIds = next.ids;
                _customVulnerabilities = next.customs;
              }),
            ),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          catalogMultiPickTile(
            context: context,
            label: 'Damage resistances',
            labels: catalogSelectionLabels(
              selected: _resistanceIds.toSet(),
              namesById: _damageTypeNames,
              customStrings: _customResistances,
            ),
            onTap: () => pickCatalogIdsWithCustoms(
              context: context,
              title: 'Damage resistances',
              options: catalogPicklistOptions(_damageTypeNames),
              selected: _resistanceIds.toSet(),
              customStrings: _customResistances,
              onDone: (next) => setState(() {
                _resistanceIds = next.ids;
                _customResistances = next.customs;
              }),
            ),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          catalogMultiPickTile(
            context: context,
            label: 'Damage immunities',
            labels: catalogSelectionLabels(
              selected: _immunityIds.toSet(),
              namesById: _damageTypeNames,
              customStrings: _customImmunities,
            ),
            onTap: () => pickCatalogIdsWithCustoms(
              context: context,
              title: 'Damage immunities',
              options: catalogPicklistOptions(_damageTypeNames),
              selected: _immunityIds.toSet(),
              customStrings: _customImmunities,
              onDone: (next) => setState(() {
                _immunityIds = next.ids;
                _customImmunities = next.customs;
              }),
            ),
          ),
          const SizedBox(height: ResourceFormStyles.fieldSpacing),
          catalogMultiPickTile(
            context: context,
            label: 'Condition immunities',
            labels: catalogSelectionLabels(
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
          const SizedBox(height: ResourceFormStyles.sectionSpacing),
          Text(
            'Traits',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          for (var i = 0; i < _traits.length; i++)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextFormField(
                      initialValue: _traits[i].name,
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'Name',
                      ),
                      onChanged: (value) {
                        final next = [..._traits];
                        next[i] = CreatureTypeTrait(
                          name: value,
                          description: next[i].description,
                          featureCatalogItemId: next[i].featureCatalogItemId,
                        );
                        setState(() => _traits = next);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _traits[i].description,
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'Description',
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        final next = [..._traits];
                        next[i] = CreatureTypeTrait(
                          name: next[i].name,
                          description: value,
                          featureCatalogItemId: next[i].featureCatalogItemId,
                        );
                        setState(() => _traits = next);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue:
                          _traits[i].featureCatalogItemId?.toString() ?? '',
                      decoration: ResourceFormStyles.inputDecoration(
                        context,
                        label: 'Feature catalog ID (optional)',
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final parsed = int.tryParse(value.trim());
                        final next = [..._traits];
                        next[i] = CreatureTypeTrait(
                          name: next[i].name,
                          description: next[i].description,
                          featureCatalogItemId: parsed,
                        );
                        setState(() => _traits = next);
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () {
                          setState(() => _traits = [..._traits]..removeAt(i));
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          TextButton.icon(
            onPressed: () {
              setState(
                () => _traits = [
                  ..._traits,
                  const CreatureTypeTrait(name: '', description: ''),
                ],
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Add trait'),
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
