import 'package:flutter/material.dart';

import 'package:rpg_manager/features/auth/data/auth_api.dart';
import 'package:rpg_manager/features/auth/state/auth_controller.dart';
import 'package:rpg_manager/features/catalog/data/catalog_api.dart';
import 'package:rpg_manager/features/catalog/data/catalog_kind.dart';
import 'package:rpg_manager/features/catalog/data/catalog_models.dart';
import 'package:rpg_manager/features/world/creature_types/data/creature_type_model.dart';
import 'package:rpg_manager/features/world/creature_types/ui/creature_type_detail_page.dart';
import 'package:rpg_manager/features/world/creature_types/ui/creature_type_form_sheet.dart';
import 'package:rpg_manager/features/world/creatures/data/creature_model.dart';
import 'package:rpg_manager/features/world/creatures/ui/creature_detail_page.dart';
import 'package:rpg_manager/features/world/creatures/ui/creature_form_sheet.dart';
import 'package:rpg_manager/features/world/creatures/ui/creature_list_item_card.dart';
import 'package:rpg_manager/features/world/world_icons.dart';

class CreaturesBody extends StatefulWidget {
  const CreaturesBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<CreaturesBody> createState() => _CreaturesBodyState();
}

class _CreaturesBodyState extends State<CreaturesBody> {
  final _api = CatalogApi();

  bool _loading = true;
  String? _error;
  List<CatalogItem> _creatureItems = const [];
  List<CatalogItem> _typeItems = const [];
  bool _fabOpen = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  Creature? _creatureFromCatalog(CatalogItem item) {
    final payload = item.payload;
    if (payload == null) {
      return Creature(
        id: Creature.slugify(item.name),
        name: item.name,
      );
    }
    try {
      return Creature.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  CreatureType _typeFromItem(CatalogItem item) {
    return CreatureType.fromCatalogPayload(
      id: item.id,
      name: item.name,
      payload: item.payload,
    ).copyWith(name: item.name);
  }

  List<({CatalogItem item, Creature creature})> get _creatureEntries {
    final out = <({CatalogItem item, Creature creature})>[];
    for (final item in _creatureItems) {
      final creature = _creatureFromCatalog(item);
      if (creature == null) continue;
      out.add((item: item, creature: creature.copyWith(name: item.name)));
    }
    out.sort(
      (a, b) => a.creature.name
          .toLowerCase()
          .compareTo(b.creature.name.toLowerCase()),
    );
    return out;
  }

  List<({CatalogItem item, CreatureType type})> get _typeEntries {
    return [
      for (final item in _typeItems)
        (item: item, type: _typeFromItem(item)),
    ];
  }

  Map<int, CreatureType> get _typesById => {
        for (final e in _typeEntries) e.type.id: e.type,
      };

  Map<int, String> get _typeNamesById => {
        for (final e in _typeEntries) e.type.id: e.type.name,
      };

  int? _rootTypeIdForCreature(Creature creature) {
    final typesById = _typesById;
    final startId = creature.creatureSubtypeId ?? creature.creatureTypeId;
    if (startId == null) return creature.creatureTypeId;
    var current = typesById[startId];
    if (current == null) return creature.creatureTypeId ?? startId;
    while (current!.parentCreatureTypeId != null) {
      final parent = typesById[current.parentCreatureTypeId!];
      if (parent == null) break;
      current = parent;
    }
    return current.id;
  }

  List<
      ({
        ({CatalogItem item, CreatureType type})? typeEntry,
        List<({CatalogItem item, Creature creature})> creatures,
      })> get _sections {
    final roots = creatureTypeRoots(_typeEntries.map((e) => e.type).toList())
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final typeEntryById = {
      for (final e in _typeEntries) e.type.id: e,
    };
    final grouped = <int?, List<({CatalogItem item, Creature creature})>>{};
    for (final entry in _creatureEntries) {
      final rootId = _rootTypeIdForCreature(entry.creature);
      grouped.putIfAbsent(rootId, () => []).add(entry);
    }

    final sections = <
        ({
          ({CatalogItem item, CreatureType type})? typeEntry,
          List<({CatalogItem item, Creature creature})> creatures,
        })>[];

    for (final root in roots) {
      sections.add((
        typeEntry: typeEntryById[root.id],
        creatures: grouped[root.id] ?? const [],
      ));
    }

    final untyped = grouped[null] ?? const [];
    final orphanIds = grouped.keys.whereType<int>().where(
          (id) => !roots.any((r) => r.id == id),
        );
    for (final id in orphanIds) {
      sections.add((
        typeEntry: typeEntryById[id],
        creatures: grouped[id] ?? const [],
      ));
    }
    if (untyped.isNotEmpty || roots.isEmpty) {
      sections.add((typeEntry: null, creatures: untyped));
    }

    return sections;
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _token();
      if (token == null) {
        throw AuthApiException('Not authenticated');
      }
      final results = await Future.wait([
        _api.list(token, CatalogKind.creatures),
        _api.list(token, CatalogKind.creatureTypes),
      ]);
      if (!mounted) return;
      setState(() {
        _creatureItems = results[0];
        _typeItems = results[1];
        _loading = false;
      });
    } on AuthApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load creatures';
        _loading = false;
      });
    }
  }

  Future<void> _createCreature() async {
    setState(() => _fabOpen = false);
    try {
      if (!mounted) return;
      final creature = await showCreatureFormSheet(context, auth: widget.auth);
      if (creature == null || !mounted) return;
      final token = await _token();
      if (token == null) return;
      await _api.create(
        accessToken: token,
        kind: CatalogKind.creatures,
        name: creature.name,
        payload: creature.toJson(),
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create creature')),
      );
    }
  }

  Future<void> _createType() async {
    setState(() => _fabOpen = false);
    try {
      if (!mounted) return;
      final allTypes = _typeEntries.map((e) => e.type).toList();
      final type = await showCreatureTypeFormSheet(
        context,
        allTypes: allTypes,
        auth: widget.auth,
      );
      if (type == null || !mounted) return;
      final token = await _token();
      if (token == null) return;
      await _api.create(
        accessToken: token,
        kind: CatalogKind.creatureTypes,
        name: type.name,
        payload: type.toJson(),
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create creature type')),
      );
    }
  }

  Future<void> _editCreature(CatalogItem item) async {
    try {
      final existing = _creatureFromCatalog(item);
      if (existing == null || !mounted) return;
      final creature = await showCreatureFormSheet(
        context,
        initial: existing,
        auth: widget.auth,
      );
      if (creature == null || !mounted) return;
      final token = await _token();
      if (token == null) return;
      await _api.update(
        accessToken: token,
        kind: CatalogKind.creatures,
        itemId: item.id,
        name: creature.name,
        payload: creature.toJson(),
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update creature')),
      );
    }
  }

  Future<void> _editType(CatalogItem item) async {
    try {
      if (!mounted) return;
      final existing = _typeFromItem(item);
      final allTypes = _typeEntries.map((e) => e.type).toList();
      final type = await showCreatureTypeFormSheet(
        context,
        initial: existing,
        allTypes: allTypes,
        auth: widget.auth,
      );
      if (type == null || !mounted) return;
      final token = await _token();
      if (token == null) return;
      await _api.update(
        accessToken: token,
        kind: CatalogKind.creatureTypes,
        itemId: item.id,
        name: type.name,
        payload: type.toJson(),
      );
      await _reload();
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update creature type')),
      );
    }
  }

  Future<void> _openCreatureDetail(
    ({CatalogItem item, Creature creature}) entry,
  ) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreatureDetailPage(
          auth: widget.auth,
          item: entry.item,
          creature: entry.creature,
        ),
      ),
    );
    if (deleted == true && mounted) {
      await _reload();
    }
  }

  Future<void> _openTypeDetail(
    ({CatalogItem item, CreatureType type}) entry,
  ) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreatureTypeDetailPage(
          auth: widget.auth,
          item: entry.item,
          type: entry.type,
          typesById: _typesById,
        ),
      ),
    );
    if (deleted == true && mounted) {
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sections = _loading || _error != null ? const [] : _sections;
    final isEmpty = sections.isEmpty ||
        (sections.every((s) => s.creatures.isEmpty) && _typeItems.isEmpty);

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: Icon(
                  creaturesPageIcon,
                  size: 440,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else if (_error != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _reload,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (isEmpty)
          RefreshIndicator(
            onRefresh: _reload,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No creatures yet',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add a creature type or statblock.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _reload,
            child: LayoutBuilder(
              builder: (context, constraints) {
                const horizontalPadding = 16.0;
                const itemSpacing = 10.0;
                const minItemWidth = 280.0;
                const maxItemWidth = 1060.0;
                final availableWidth =
                    constraints.maxWidth - (horizontalPadding * 2);
                final columns = ((availableWidth + itemSpacing) /
                        (minItemWidth + itemSpacing))
                    .floor()
                    .clamp(1, 99);
                final itemWidth = columns == 1
                    ? availableWidth
                    : ((availableWidth - (itemSpacing * (columns - 1))) /
                            columns)
                        .clamp(minItemWidth, maxItemWidth);

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    horizontalPadding,
                    16,
                    horizontalPadding,
                    100,
                  ),
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[
                      if (i > 0) const SizedBox(height: 20),
                      _TypeSectionHeader(
                        title: sections[i].typeEntry?.type.name ?? 'Untyped',
                        count: sections[i].creatures.length,
                        onTap: sections[i].typeEntry == null
                            ? null
                            : () => _openTypeDetail(sections[i].typeEntry!),
                        onLongPress: sections[i].typeEntry == null
                            ? null
                            : () => _editType(sections[i].typeEntry!.item),
                      ),
                      const SizedBox(height: 10),
                      if (sections[i].creatures.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 4),
                          child: Text(
                            'No statblocks yet',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: itemSpacing,
                          runSpacing: itemSpacing,
                          children: [
                            for (final entry in sections[i].creatures)
                              SizedBox(
                                width: itemWidth,
                                child: CreatureListItemCard(
                                  creature: entry.creature,
                                  typeLabel: entry.creature.resolvedTypeLabel(
                                    typeNamesById: _typeNamesById,
                                  ),
                                  onTap: () => _openCreatureDetail(entry),
                                  onLongPress: () => _editCreature(entry.item),
                                  minWidth: minItemWidth,
                                  maxWidth: maxItemWidth,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        Positioned(
          right: 20,
          bottom: 20,
          child: _CreaturesFab(
            open: _fabOpen,
            onToggle: () => setState(() => _fabOpen = !_fabOpen),
            onStatblock: _createCreature,
            onCreatureType: _createType,
          ),
        ),
      ],
    );
  }
}

class _TypeSectionHeader extends StatelessWidget {
  const _TypeSectionHeader({
    required this.title,
    required this.count,
    this.onTap,
    this.onLongPress,
  });

  final String title;
  final int count;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(creatureTypesPageIcon, color: scheme.primary, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$count',
                style: textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CreaturesFab extends StatelessWidget {
  const _CreaturesFab({
    required this.open,
    required this.onToggle,
    required this.onStatblock,
    required this.onCreatureType,
  });

  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onStatblock;
  final VoidCallback onCreatureType;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AnimatedOpacity(
          opacity: open ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: IgnorePointer(
            ignoring: !open,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _FabAction(
                  label: 'Statblock',
                  icon: creaturesPageIcon,
                  onPressed: onStatblock,
                ),
                const SizedBox(height: 10),
                _FabAction(
                  label: 'Creature type',
                  icon: creatureTypesPageIcon,
                  onPressed: onCreatureType,
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        FloatingActionButton(
          onPressed: onToggle,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          child: AnimatedRotation(
            turns: open ? 0.125 : 0,
            duration: const Duration(milliseconds: 180),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _FabAction extends StatelessWidget {
  const _FabAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text(label),
          ),
        ),
        const SizedBox(width: 10),
        FloatingActionButton.small(
          heroTag: 'creatures-fab-$label',
          onPressed: onPressed,
          child: Icon(icon),
        ),
      ],
    );
  }
}
