import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../../dm_tools/resources/data/resource_models.dart';
import '../../../dm_tools/resources/data/resources_api.dart';
import '../../classes/data/class_model.dart';
import '../../player_options_icons.dart';
import '../data/spell_model.dart';
import 'spell_form_sheet.dart';

class SpellsBody extends StatefulWidget {
  const SpellsBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<SpellsBody> createState() => _SpellsBodyState();
}

class _SpellsBodyState extends State<SpellsBody> {
  final _api = CatalogApi();
  final _resourcesApi = ResourcesApi();

  bool _loading = true;
  String? _error;
  List<CatalogItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<String?> _token() => widget.auth.requireAccessToken();

  Spell? _spellFromItem(CatalogItem item) {
    final payload = item.payload;
    if (payload == null) {
      return Spell(
        id: Spell.slugify(item.name),
        name: item.name,
        level: 0,
        school: SpellSchool.evocation,
        castingTime: const CastingTime.action(),
        range: const SpellRange.self(),
        components: const SpellComponents(
          verbal: false,
          somatic: false,
          material: false,
        ),
        duration: const SpellDuration.instantaneous(),
        classIds: const [],
        description: '',
      );
    }
    try {
      return Spell.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  Future<
      ({
        List<CatalogItem> casters,
        List<CatalogItem> spellTags,
        List<ResourceFile> files,
      })> _loadFormLookups(String token) async {
    final results = await Future.wait([
      _api.list(token, CatalogKind.classes),
      _api.list(token, CatalogKind.spellTags),
    ]);
    final classItems = results[0];
    final spellTags = results[1];
    final casters = classItems.where((item) {
      return ClassRecord.fromCatalogPayload(
        name: item.name,
        payload: item.payload,
      ).isCaster;
    }).toList();

    var files = const <ResourceFile>[];
    try {
      files = await _resourcesApi.listFiles(token);
    } on AuthApiException {
      // Non-DM users cannot list resources; leave empty.
    } catch (_) {
      // Ignore lookup failures; form still works without files.
    }
    return (casters: casters, spellTags: spellTags, files: files);
  }

  Future<List<CatalogLinkTarget>> _searchLinks(
    String token,
    String query,
  ) async {
    // If the user typed kind/name, search on the name portion and filter kind.
    var nameQuery = query;
    String? kindPrefix;
    final slash = query.lastIndexOf('/');
    if (slash >= 0) {
      kindPrefix = query.substring(0, slash).trim().toLowerCase();
      nameQuery = query.substring(slash + 1);
    }
    try {
      final results = await _api.search(token, query: nameQuery);
      if (kindPrefix == null || kindPrefix.isEmpty) return results;
      return results
          .where((item) => item.kind.toLowerCase().startsWith(kindPrefix!))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<CatalogLinkTarget>> _loadAutoLinkTargets(String token) async {
    try {
      final results = await Future.wait([
        _api.list(token, CatalogKind.conditions),
        _api.list(token, CatalogKind.damageTypes),
      ]);
      return [
        for (final item in results[0])
          CatalogLinkTarget(
            id: item.id,
            kind: item.kind.apiValue,
            name: item.name,
          ),
        for (final item in results[1])
          CatalogLinkTarget(
            id: item.id,
            kind: item.kind.apiValue,
            name: item.name,
          ),
      ];
    } catch (_) {
      return const [];
    }
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
      final items = await _api.list(token, CatalogKind.spells);
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
        _error = 'Could not load spells';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    try {
      final token = await _token();
      if (token == null) return;
      final lookups = await _loadFormLookups(token);
      if (!mounted) return;
      final spell = await showSpellFormSheet(
        context,
        casterClasses: lookups.casters,
        spellTags: lookups.spellTags,
        resourceFiles: lookups.files,
        searchLinks: (query) => _searchLinks(token, query),
        loadAutoLinkTargets: () => _loadAutoLinkTargets(token),
        aiIntegrationEnabled: widget.auth.user?.aiIntegration ?? false,
      );
      if (spell == null || !mounted) return;
      await _api.create(
        accessToken: token,
        kind: CatalogKind.spells,
        name: spell.name,
        payload: spell.toJson(),
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
        const SnackBar(content: Text('Could not create spell')),
      );
    }
  }

  Future<void> _edit(CatalogItem item) async {
    try {
      final token = await _token();
      if (token == null) return;
      final lookups = await _loadFormLookups(token);
      if (!mounted) return;
      final existing = _spellFromItem(item);
      final spell = await showSpellFormSheet(
        context,
        initial: existing,
        casterClasses: lookups.casters,
        spellTags: lookups.spellTags,
        resourceFiles: lookups.files,
        searchLinks: (query) => _searchLinks(token, query),
        loadAutoLinkTargets: () => _loadAutoLinkTargets(token),
        aiIntegrationEnabled: widget.auth.user?.aiIntegration ?? false,
      );
      if (spell == null || !mounted) return;
      await _api.update(
        accessToken: token,
        kind: CatalogKind.spells,
        itemId: item.id,
        name: spell.name,
        payload: spell.toJson(),
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
        const SnackBar(content: Text('Could not update spell')),
      );
    }
  }

  Future<void> _delete(CatalogItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete spell?'),
        content: Text('Delete “${item.name}”? This cannot be undone.'),
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
        kind: CatalogKind.spells,
        itemId: item.id,
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
        const SnackBar(content: Text('Could not delete spell')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Opacity(
                opacity: 0.08,
                child: Icon(
                  spellsPageIcon,
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
        else if (_items.isEmpty)
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
                              'No spells yet',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add your first spell.',
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
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _items[index];
                final spell = _spellFromItem(item);
                return Material(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(spellsPageIcon, color: scheme.primary),
                    title: Text(item.name),
                    subtitle: spell == null
                        ? null
                        : Text(spell.levelSchoolLabel),
                    trailing: IconButton(
                      tooltip: 'Delete',
                      onPressed: () => _delete(item),
                      icon: Icon(
                        Icons.delete_outline,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    onTap: () => _edit(item),
                  ),
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
