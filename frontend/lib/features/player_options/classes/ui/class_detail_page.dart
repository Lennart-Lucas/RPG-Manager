import 'package:flutter/material.dart';

import '../../../../core/offline/offline_marker.dart';
import '../../../../core/ui/record_list_card.dart';
import '../../../../core/ui/simple_card_rich_text.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_auto_link.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../catalog/ui/open_catalog_detail.dart';
import '../../player_options_icons.dart';
import '../data/class_model.dart';
import '../data/subclass_model.dart';
import 'class_form_sheet.dart';
import 'subclass_detail_page.dart';
import 'subclass_form_sheet.dart';

class ClassDetailPage extends StatefulWidget {
  const ClassDetailPage({
    super.key,
    required this.auth,
    required this.item,
  });

  final AuthController auth;
  final CatalogItem item;

  @override
  State<ClassDetailPage> createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  final _api = CatalogApi();
  late CatalogItem _item = widget.item;
  List<String> _skillNames = const [];
  List<CatalogItem> _subclasses = const [];

  Future<String?> _token() => widget.auth.requireAccessToken();

  ClassRecord get _record => ClassRecord.fromCatalogPayload(
        name: _item.name,
        payload: _item.payload,
      );

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final token = await _token();
      if (token == null) return;
      final results = await Future.wait([
        _api.list(token, CatalogKind.skills),
        _api.list(token, CatalogKind.subclasses),
      ]);
      if (!mounted) return;
      setState(() {
        _skillNames = [for (final s in results[0]) s.name]..sort();
        _subclasses = [
          for (final item in results[1])
            if (SubclassRecord.fromCatalogPayload(
                  name: item.name,
                  payload: item.payload,
                ).parentClassId ==
                _item.id)
              item,
        ]..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
      });
      await _migrateLegacySubclassesIfNeeded(token);
    } catch (_) {}
  }

  Future<void> _migrateLegacySubclassesIfNeeded(String token) async {
    final record = _record;
    if (record.legacySubclasses.isEmpty) return;
    for (final legacy in record.legacySubclasses) {
      if (legacy.name.trim().isEmpty) continue;
      final created = await _api.create(
        accessToken: token,
        kind: CatalogKind.subclasses,
        name: legacy.name.trim(),
        payload: SubclassRecord(
          name: legacy.name.trim(),
          parentClassId: _item.id,
          featuresByLevel: legacy.featuresByLevel,
        ).toJson(),
      );
      _subclasses = [..._subclasses, created];
    }
    final cleaned = record.copyWith(legacySubclasses: const []);
    final updated = await _api.update(
      accessToken: token,
      kind: CatalogKind.classes,
      itemId: _item.id,
      name: cleaned.name,
      payload: cleaned.toJson(),
    );
    if (!mounted) return;
    setState(() {
      _item = updated;
      _subclasses = [..._subclasses]
        ..sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    });
  }

  Future<void> _addSubclass() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final record = await showSubclassFormSheet(
        context,
        parentClasses: [_item],
        preferredParentClassId: _item.id,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (record == null || !mounted) return;
      final created = await _api.create(
        accessToken: token,
        kind: CatalogKind.subclasses,
        name: record.name,
        payload: record.copyWith(parentClassId: _item.id).toJson(),
      );
      if (!mounted) return;
      setState(() {
        _subclasses = [..._subclasses, created]
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create subclass')),
      );
    }
  }

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      if (_skillNames.isEmpty) await _loadLookups();
      if (!mounted) return;
      final updatedRecord = await showClassFormSheet(
        context,
        initial: _record,
        skillNames: _skillNames,
        searchLinks: (q) => searchCatalogLinkTargets(_api, token, q),
        loadAutoLinkTargets: () =>
            loadConditionDamageAutoLinkTargets(_api, token),
      );
      if (updatedRecord == null || !mounted) return;
      final updated = await _api.update(
        accessToken: token,
        kind: CatalogKind.classes,
        itemId: _item.id,
        name: updatedRecord.name,
        payload: updatedRecord.toJson(),
      );
      if (!mounted) return;
      setState(() => _item = updated);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update class')),
      );
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete class?'),
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
        kind: CatalogKind.classes,
        itemId: _item.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete class')),
      );
    }
  }

  Widget _chipWrap(List<String> values) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values) Chip(label: Text(v)),
      ],
    );
  }

  Widget _featureSection(
    BuildContext context,
    Map<int, List<ClassFeature>> featuresByLevel,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final levels = featuresByLevel.keys.toList()..sort();
    if (levels.isEmpty) {
      return Text(
        'No features yet.',
        style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final level in levels) ...[
          const SizedBox(height: 12),
          Text('Level $level', style: textTheme.titleSmall),
          for (final feature in featuresByLevel[level]!)
            Card(
              margin: const EdgeInsets.only(top: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.name,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (feature.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SimpleCardRichText(
                        content: feature.description,
                        onWikiLinkTap: (kind, name) => openCatalogWikiLink(
                          context: context,
                          auth: widget.auth,
                          kindApiValue: kind,
                          name: name,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final record = _record;
    final casting = record.spellcasting;

    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name.trim().isEmpty ? 'Class' : _item.name),
        actions: [
          const OfflineAppBarMarker(),
          if (widget.auth.canMutateCatalog) ...[
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
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: 0.08,
                  child: Icon(
                    classesPageIcon,
                    size: 440,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(_item.name, style: textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                record.isCaster
                    ? 'Class · ${record.hitDie} · Spellcaster'
                    : 'Class · ${record.hitDie}',
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (record.description.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Description', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                SimpleCardRichText(
                  content: record.description,
                  onWikiLinkTap: (kind, name) => openCatalogWikiLink(
                    context: context,
                    auth: widget.auth,
                    kindApiValue: kind,
                    name: name,
                  ),
                ),
              ],
              if (record.primaryAbilities.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Primary abilities', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                _chipWrap(record.primaryAbilities),
              ],
              if (record.savingThrowProficiencies.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Saving throws', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                _chipWrap(record.savingThrowProficiencies),
              ],
              if (record.armorProficiencies.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Armor', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                _chipWrap(record.armorProficiencies),
              ],
              if (record.weaponProficiencies.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Weapons', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                _chipWrap(record.weaponProficiencies),
              ],
              if (record.toolProficiencies.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Tools', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                _chipWrap(record.toolProficiencies),
              ],
              if (record.skillChoices.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Skills (choose ${record.skillChoiceCount})',
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _chipWrap(record.skillChoices),
              ],
              if (casting != null) ...[
                const SizedBox(height: 24),
                Text('Spellcasting', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                Text(
                  '${casting.ability} · ${casting.type.label} · '
                  '${casting.preparesSpells ? 'Prepared' : 'Known'}',
                ),
                if (casting.slotsByLevel.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final level
                      in (casting.slotsByLevel.keys.toList()..sort()))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'L$level: '
                        '${casting.slotsByLevel[level]!.cantripsKnown} cantrips, '
                        '${casting.slotsByLevel[level]!.spellsKnownOrPrepared} known/prep'
                        '${casting.slotsByLevel[level]!.slotsByCircle.isEmpty ? '' : ', slots ${casting.slotsByLevel[level]!.slotsByCircle.join('/')}'}',
                        style: textTheme.bodySmall,
                      ),
                    ),
                ],
              ],
              const SizedBox(height: 24),
              Text('Features', style: textTheme.titleMedium),
              _featureSection(context, record.featuresByLevel),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Subclasses',
                      style: textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    'Chosen at ${record.subclassChosenAtLevel}',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (widget.auth.canMutateCatalog)
                    TextButton.icon(
                      onPressed: _addSubclass,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add'),
                    ),
                ],
              ),
              if (_subclasses.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'No subclasses linked to this class yet.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                for (final subclassItem in _subclasses)
                  Builder(
                    builder: (context) {
                      final subclass = SubclassRecord.fromCatalogPayload(
                        name: subclassItem.name,
                        payload: subclassItem.payload,
                      );
                      final description = subclass.description.trim();
                      return RecordListCard(
                        leading: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(
                              alpha: 0.88,
                            ),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(
                            subclassesPageIcon,
                            size: 22,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        title: subclassItem.name,
                        subtitle: '',
                        trailing: Icon(
                          Icons.chevron_right,
                          color: scheme.onSurfaceVariant,
                        ),
                        onTap: () async {
                          final deleted =
                              await Navigator.of(context).push<bool>(
                            MaterialPageRoute(
                              builder: (context) => SubclassDetailPage(
                                auth: widget.auth,
                                item: subclassItem,
                                parentClasses: [_item],
                              ),
                            ),
                          );
                          if (deleted == true || mounted) {
                            await _loadLookups();
                          }
                        },
                        children: [
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            SimpleCardRichText(
                              content: description,
                              onWikiLinkTap: (kind, name) =>
                                  openCatalogWikiLink(
                                context: context,
                                auth: widget.auth,
                                kindApiValue: kind,
                                name: name,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
            ],
          ),
        ],
      ),
    );
  }
}
