import 'package:flutter/material.dart';

import '../../../../core/ui/markdown_form_field.dart';
import '../../../auth/data/auth_api.dart';
import '../../../auth/state/auth_controller.dart';
import '../../../catalog/data/catalog_api.dart';
import '../../../catalog/data/catalog_kind.dart';
import '../../../catalog/data/catalog_models.dart';
import '../../mechanics_icons.dart';
import '../data/spell_tag_model.dart';
import 'spell_tag_form_sheet.dart';

class SpellTagsBody extends StatefulWidget {
  const SpellTagsBody({super.key, required this.auth});

  final AuthController auth;

  @override
  State<SpellTagsBody> createState() => _SpellTagsBodyState();
}

class _SpellTagsBodyState extends State<SpellTagsBody> {
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

  SpellTag _tagFromItem(CatalogItem item) {
    return SpellTag.fromCatalogPayload(
      name: item.name,
      payload: item.payload,
    );
  }

  Future<List<CatalogLinkTarget>> _searchLinks(
    String token,
    String query,
  ) async {
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
      final items = await _api.list(token, CatalogKind.spellTags);
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
        _error = 'Could not load spell tags';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final tag = await showSpellTagFormSheet(
        context,
        searchLinks: (query) => _searchLinks(token, query),
        loadAutoLinkTargets: () => _loadAutoLinkTargets(token),
      );
      if (tag == null || !mounted) return;
      await _api.create(
        accessToken: token,
        kind: CatalogKind.spellTags,
        name: tag.name,
        payload: tag.toJson(),
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
        const SnackBar(content: Text('Could not create spell tag')),
      );
    }
  }

  Future<void> _edit(CatalogItem item) async {
    try {
      final token = await _token();
      if (token == null || !mounted) return;
      final existing = _tagFromItem(item);
      final tag = await showSpellTagFormSheet(
        context,
        initial: existing,
        searchLinks: (query) => _searchLinks(token, query),
        loadAutoLinkTargets: () => _loadAutoLinkTargets(token),
      );
      if (tag == null || !mounted) return;
      await _api.update(
        accessToken: token,
        kind: CatalogKind.spellTags,
        itemId: item.id,
        name: tag.name,
        payload: tag.toJson(),
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
        const SnackBar(content: Text('Could not update spell tag')),
      );
    }
  }

  Future<void> _delete(CatalogItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete spell tag?'),
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
        kind: CatalogKind.spellTags,
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
        const SnackBar(content: Text('Could not delete spell tag')),
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
                  spellTagsPageIcon,
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
                              'No spell tags yet',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap + to add your first spell tag.',
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
                return Material(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(spellTagsPageIcon, color: scheme.primary),
                    title: Text(item.name),
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
