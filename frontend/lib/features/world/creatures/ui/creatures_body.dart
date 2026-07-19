import 'package:flutter/material.dart';

import 'package:rpg_manager/features/auth/data/auth_api.dart';
import 'package:rpg_manager/features/auth/state/auth_controller.dart';
import 'package:rpg_manager/features/catalog/data/catalog_api.dart';
import 'package:rpg_manager/features/catalog/data/catalog_kind.dart';
import 'package:rpg_manager/features/catalog/data/catalog_models.dart';
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
  List<CatalogItem> _items = const [];
  Map<int, String> _typeNamesById = const {};

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

  List<({CatalogItem item, Creature creature})> get _entries {
    final out = <({CatalogItem item, Creature creature})>[];
    for (final item in _items) {
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
      final items = await _api.list(token, CatalogKind.creatures);
      final typeItems = await _api.list(token, CatalogKind.creatureTypes);
      if (!mounted) return;
      setState(() {
        _items = items;
        _typeNamesById = {for (final t in typeItems) t.id: t.name};
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

  Future<void> _create() async {
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

  Future<void> _edit(CatalogItem item) async {
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

  Future<void> _openDetail(({CatalogItem item, Creature creature}) entry) async {
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = _loading || _error != null ? const [] : _entries;

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
        else if (entries.isEmpty)
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
                              'Tap + to add your first creature.',
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
                    Wrap(
                      spacing: itemSpacing,
                      runSpacing: itemSpacing,
                      children: [
                        for (final entry in entries)
                          SizedBox(
                            width: itemWidth,
                            child: CreatureListItemCard(
                              creature: entry.creature,
                              typeLabel: entry.creature.resolvedTypeLabel(
                                typeNamesById: _typeNamesById,
                              ),
                              onTap: () => _openDetail(entry),
                              onLongPress: () => _edit(entry.item),
                              minWidth: minItemWidth,
                              maxWidth: maxItemWidth,
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            onPressed: _create,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}
