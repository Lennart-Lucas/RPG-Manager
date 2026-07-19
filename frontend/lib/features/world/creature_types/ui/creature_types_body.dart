import 'package:flutter/material.dart';

import 'package:rpg_manager/features/auth/data/auth_api.dart';
import 'package:rpg_manager/features/auth/state/auth_controller.dart';
import 'package:rpg_manager/features/catalog/data/catalog_api.dart';
import 'package:rpg_manager/features/catalog/data/catalog_kind.dart';
import 'package:rpg_manager/features/catalog/data/catalog_models.dart';
import 'package:rpg_manager/features/world/creature_types/data/creature_type_model.dart';
import 'package:rpg_manager/features/world/creature_types/ui/creature_type_detail_page.dart';
import 'package:rpg_manager/features/world/creature_types/ui/creature_type_form_sheet.dart';
import 'package:rpg_manager/features/world/world_icons.dart';

class CreatureTypesBody extends StatefulWidget {
  const CreatureTypesBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<CreatureTypesBody> createState() => _CreatureTypesBodyState();
}

class _CreatureTypesBodyState extends State<CreatureTypesBody> {
  final _api = CatalogApi();

  bool _loading = true;
  String? _error;
  List<CatalogItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  CreatureType _typeFromItem(CatalogItem item) {
    return CreatureType.fromCatalogPayload(
      id: item.id,
      name: item.name,
      payload: item.payload,
    );
  }

  List<({CatalogItem item, CreatureType type})> get _entries {
    final out = <({CatalogItem item, CreatureType type})>[];
    for (final item in _items) {
      out.add((item: item, type: _typeFromItem(item).copyWith(name: item.name)));
    }
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
      final items = await _api.list(token, CatalogKind.creatureTypes);
      if (!mounted) return;
      setState(() {
        _items = items;
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
        _error = 'Could not load creature types';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    try {
      if (!mounted) return;
      final allTypes = _entries.map((e) => e.type).toList();
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

  Future<void> _edit(CatalogItem item) async {
    try {
      if (!mounted) return;
      final existing = _typeFromItem(item);
      final allTypes = _entries.map((e) => e.type).toList();
      final type = await showCreatureTypeFormSheet(
        context,
        initial: existing.copyWith(name: item.name),
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

  Future<void> _openDetail(({CatalogItem item, CreatureType type}) entry) async {
    final typesById = {
      for (final e in _entries) e.type.id: e.type.copyWith(name: e.item.name),
    };
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => CreatureTypeDetailPage(
          auth: widget.auth,
          item: entry.item,
          type: entry.type,
          typesById: typesById,
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
    final entries = _loading || _error != null
        ? const <({CatalogItem item, CreatureType type})>[]
        : _entries;
    final types = entries.map((e) => e.type).toList();
    final roots = creatureTypeRoots(types);
    final childrenByParent = creatureTypesByParentId(types);
    final rows = creatureTypeOutlineRows(roots, childrenByParent);
    final entryById = {for (final e in entries) e.type.id: e};

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: Icon(
                  creatureTypesPageIcon,
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
                  FilledButton(onPressed: _reload, child: const Text('Retry')),
                ],
              ),
            ),
          )
        else if (entries.isEmpty)
          RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 180),
                Center(child: Text('No creature types yet')),
              ],
            ),
          )
        else
          RefreshIndicator(
            onRefresh: _reload,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                final entry = entryById[row.record.id];
                if (entry == null) return const SizedBox.shrink();
                return ListTile(
                  contentPadding: EdgeInsets.only(left: row.depth * 20.0),
                  leading: Icon(creatureTypesPageIcon, color: scheme.primary),
                  title: Text(entry.type.name),
                  subtitle: row.record.parentCreatureTypeId != null
                      ? Text(
                          'Subtype',
                          style: Theme.of(context).textTheme.bodySmall,
                        )
                      : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openDetail(entry),
                  onLongPress: () => _edit(entry.item),
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
