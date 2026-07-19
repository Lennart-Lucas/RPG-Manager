import 'package:flutter/material.dart';

import 'package:rpg_manager/core/ui/simple_card_rich_text.dart';
import 'package:rpg_manager/features/auth/data/auth_api.dart';
import 'package:rpg_manager/features/auth/state/auth_controller.dart';
import 'package:rpg_manager/features/catalog/data/catalog_api.dart';
import 'package:rpg_manager/features/catalog/data/catalog_kind.dart';
import 'package:rpg_manager/features/catalog/data/catalog_models.dart';
import 'package:rpg_manager/features/world/creatures/data/creature_model.dart';
import 'package:rpg_manager/features/world/creatures/ui/creature_form_sheet.dart';
import 'package:rpg_manager/features/world/creatures/ui/creature_statblock_view.dart';
import 'package:rpg_manager/features/world/world_icons.dart';

class CreatureDetailPage extends StatefulWidget {
  const CreatureDetailPage({
    super.key,
    required this.auth,
    required this.item,
    required this.creature,
  });

  final AuthController auth;
  final CatalogItem item;
  final Creature creature;

  @override
  State<CreatureDetailPage> createState() => _CreatureDetailPageState();
}

class _CreatureDetailPageState extends State<CreatureDetailPage> {
  final _api = CatalogApi();

  late CatalogItem _item = widget.item;
  late Creature _creature = widget.creature;
  Map<int, String> _typeNamesById = const {};

  @override
  void initState() {
    super.initState();
    _loadTypeNames();
  }

  Future<void> _loadTypeNames() async {
    try {
      final token = await _token();
      if (token == null) return;
      final types = await _api.list(token, CatalogKind.creatureTypes);
      if (!mounted) return;
      setState(() {
        _typeNamesById = {for (final t in types) t.id: t.name};
      });
    } catch (_) {}
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  Creature? _creatureFromCatalog(CatalogItem item) {
    final payload = item.payload;
    if (payload == null) return null;
    try {
      return Creature.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  Future<void> _edit() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final updated = await showCreatureFormSheet(
        context,
        initial: _creature,
        auth: widget.auth,
      );
      if (updated == null || !mounted) return;
      final saved = await _api.update(
        accessToken: token,
        kind: CatalogKind.creatures,
        itemId: _item.id,
        name: updated.name,
        payload: updated.toJson(),
      );
      final parsed = _creatureFromCatalog(saved) ?? updated;
      if (!mounted) return;
      setState(() {
        _item = saved;
        _creature = parsed.copyWith(name: saved.name);
      });
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

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete creature?'),
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
        kind: CatalogKind.creatures,
        itemId: _item.id,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on AuthApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete creature')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasTrigger = _creature.trigger?.trim().isNotEmpty ?? false;
    final hasCountermeasures = _creature.countermeasures.isNotEmpty;
    final hasItems = _creature.items.isNotEmpty;
    final hasExtras = hasTrigger || hasCountermeasures || hasItems;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _creature.name.trim().isEmpty ? 'Creature' : _creature.name,
        ),
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
      body: Stack(
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
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CreatureStatblockView(
                      creature: _creature,
                      typeLabel: _creature.resolvedTypeLabel(
                        typeNamesById: _typeNamesById,
                      ),
                    ),
                    if (hasExtras) ...[
                      const SizedBox(height: 12),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hasTrigger) ...[
                                Text(
                                  'Trigger',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                SimpleCardRichText(
                                  content: _creature.trigger!,
                                ),
                                if (hasCountermeasures || hasItems)
                                  const SizedBox(height: 16),
                              ],
                              if (hasCountermeasures) ...[
                                Text(
                                  'Countermeasures',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                for (final cm in _creature.countermeasures)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text('• $cm'),
                                  ),
                                if (hasItems) const SizedBox(height: 16),
                              ],
                              if (hasItems) ...[
                                Text(
                                  'Items',
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(_creature.items.join(', ')),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
