import 'package:flutter/material.dart';

import 'package:rpg_manager/features/auth/data/auth_api.dart';
import 'package:rpg_manager/features/auth/state/auth_controller.dart';
import 'package:rpg_manager/features/catalog/data/catalog_api.dart';
import 'package:rpg_manager/features/catalog/data/catalog_kind.dart';
import 'package:rpg_manager/features/catalog/data/catalog_models.dart';
import 'package:rpg_manager/features/world/creature_types/data/creature_type_model.dart';
import 'package:rpg_manager/features/world/creature_types/ui/creature_type_form_sheet.dart';
import 'package:rpg_manager/features/world/data/labeled_amount.dart';

class CreatureTypeDetailPage extends StatefulWidget {
  const CreatureTypeDetailPage({
    super.key,
    required this.auth,
    required this.item,
    required this.type,
    required this.typesById,
  });

  final AuthController auth;
  final CatalogItem item;
  final CreatureType type;
  final Map<int, CreatureType> typesById;

  @override
  State<CreatureTypeDetailPage> createState() => _CreatureTypeDetailPageState();
}

class _CreatureTypeDetailPageState extends State<CreatureTypeDetailPage> {
  final _api = CatalogApi();

  late CatalogItem _item = widget.item;
  late CreatureType _type = widget.type;

  Map<int, String> _skillNames = const {};
  Map<int, String> _languageNames = const {};
  Map<int, String> _damageTypeNames = const {};
  Map<int, String> _conditionNames = const {};

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  Future<void> _loadLookups() async {
    try {
      final token = await _token();
      if (token == null) return;
      final results = await Future.wait([
        _api.list(token, CatalogKind.skills),
        _api.list(token, CatalogKind.languages),
        _api.list(token, CatalogKind.damageTypes),
        _api.list(token, CatalogKind.conditions),
      ]);
      if (!mounted) return;
      setState(() {
        _skillNames = {for (final i in results[0]) i.id: i.name};
        _languageNames = {for (final i in results[1]) i.id: i.name};
        _damageTypeNames = {for (final i in results[2]) i.id: i.name};
        _conditionNames = {for (final i in results[3]) i.id: i.name};
      });
    } catch (_) {}
  }

  CreatureType _typeFromItem(CatalogItem item) {
    return CreatureType.fromCatalogPayload(
      id: item.id,
      name: item.name,
      payload: item.payload,
    );
  }

  List<String> _labels(List<int> ids, Map<int, String> names) {
    return [for (final id in ids) names[id] ?? '$id'];
  }

  Future<void> _edit() async {
    final allTypes = widget.typesById.values.toList();
    final updated = await showCreatureTypeFormSheet(
      context,
      initial: _type,
      allTypes: allTypes,
      auth: widget.auth,
    );
    if (updated == null || !mounted) return;
    try {
      final token = await _token();
      if (token == null) return;
      final saved = await _api.update(
        accessToken: token,
        kind: CatalogKind.creatureTypes,
        itemId: _item.id,
        name: updated.name,
        payload: updated.toJson(),
      );
      if (!mounted) return;
      setState(() {
        _item = saved;
        _type = _typeFromItem(saved).copyWith(name: saved.name);
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete creature type?'),
        content: Text('Delete “${_item.name}”? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final token = await _token();
      if (token == null) return;
      await _api.delete(
        accessToken: token,
        kind: CatalogKind.creatureTypes,
        itemId: _item.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parent = _type.parentCreatureTypeId != null
        ? widget.typesById[_type.parentCreatureTypeId!]
        : null;
    final ancestry = creatureTypeAncestry(
      type: _type,
      byId: widget.typesById,
    );
    final inheritedFrom = ancestry.length > 1
        ? ancestry.skip(1).map((t) => t.name).join(' → ')
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_type.name),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _edit,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_type.quote.isNotEmpty) ...[
                  Text(
                    _type.quote,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                  if (_type.author.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '— ${_type.author}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                  const SizedBox(height: 16),
                ],
                for (final section in _type.sections)
                  if (section.title.trim().isNotEmpty ||
                      section.contents.trim().isNotEmpty)
                    _DetailSection(
                      title: section.title.trim().isEmpty
                          ? 'Section'
                          : section.title.trim(),
                      lines: [
                        if (section.contents.trim().isNotEmpty)
                          section.contents.trim(),
                      ],
                    ),
                _DetailSection(
                  title: 'Summary',
                  lines: [
                    if (_type.size != null) 'Size: ${_type.size}',
                    if (parent != null) 'Parent: ${parent.name}',
                    if (inheritedFrom != null) 'Inherits from: $inheritedFrom',
                  ],
                ),
                if (_type.movement.isNotEmpty)
                  _DetailSection(
                    title: 'Movement',
                    lines: [labeledAmountsDisplay(_type.movement)],
                  ),
                if (_type.senses.isNotEmpty)
                  _DetailSection(
                    title: 'Senses',
                    lines: [labeledAmountsDisplay(_type.senses)],
                  ),
                if (_type.skillIds.isNotEmpty)
                  _DetailSection(
                    title: 'Skills',
                    lines: [_labels(_type.skillIds, _skillNames).join(', ')],
                  ),
                if (_type.languageIds.isNotEmpty ||
                    _type.customLanguages.isNotEmpty)
                  _DetailSection(
                    title: 'Languages',
                    lines: [
                      [
                        ..._labels(_type.languageIds, _languageNames),
                        ..._type.customLanguages,
                      ].join(', '),
                    ],
                  ),
                if (_type.damageVulnerabilityIds.isNotEmpty ||
                    _type.customDamageVulnerabilities.isNotEmpty)
                  _DetailSection(
                    title: 'Vulnerabilities',
                    lines: [
                      [
                        ..._labels(
                          _type.damageVulnerabilityIds,
                          _damageTypeNames,
                        ),
                        ..._type.customDamageVulnerabilities,
                      ].join(', '),
                    ],
                  ),
                if (_type.damageResistanceIds.isNotEmpty ||
                    _type.customDamageResistances.isNotEmpty)
                  _DetailSection(
                    title: 'Resistances',
                    lines: [
                      [
                        ..._labels(_type.damageResistanceIds, _damageTypeNames),
                        ..._type.customDamageResistances,
                      ].join(', '),
                    ],
                  ),
                if (_type.damageImmunityIds.isNotEmpty ||
                    _type.customDamageImmunities.isNotEmpty)
                  _DetailSection(
                    title: 'Immunities',
                    lines: [
                      [
                        ..._labels(_type.damageImmunityIds, _damageTypeNames),
                        ..._type.customDamageImmunities,
                      ].join(', '),
                    ],
                  ),
                if (_type.conditionImmunityIds.isNotEmpty)
                  _DetailSection(
                    title: 'Condition immunities',
                    lines: [
                      _labels(_type.conditionImmunityIds, _conditionNames)
                          .join(', '),
                    ],
                  ),
                if (_type.traits.isNotEmpty)
                  _DetailSection(
                    title: 'Traits',
                    lines: [
                      for (final trait in _type.traits)
                        if (trait.name.isNotEmpty)
                          '${trait.name}: ${trait.description}',
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(line),
            ),
        ],
      ),
    );
  }
}
